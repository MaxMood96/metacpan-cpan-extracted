/* po_logidx.h - the block directory, and the label allowlist.
 *
 * Two jobs, and the second one is the one that keeps the store alive.
 *
 * THE DIRECTORY. One entry per block, carrying the stream, the time span, the
 * offsets and the bloom. A time filter skips a block by reading 48 bytes,
 * WITHOUT INFLATING IT - which is the entire point of having a directory at
 * all, and the reason t_min/t_max live here and not inside the compressed
 * bytes.
 *
 * THE ALLOWLIST. A stream is a label set, and a label set with a request id in
 * it is one stream per request. That is the cardinality explosion wearing a
 * different costume, and it arrives the same way it always does: somebody
 * adds `user_id` or a full URL as a resource attribute.
 *
 * So ONLY configured attributes become stream labels. Everything else stays
 * in the record, searchable by residual filter but not indexed. Without this,
 * one customer takes the store down and the store is RIGHT to refuse.
 */
#ifndef PO_LOGIDX_H
#define PO_LOGIDX_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_log.h"

#define PO_LABEL_MAX     32
#define PO_LABEL_KEYMAX  128

/* The default allowlist. Deliberately short: these are the dimensions people
 * actually filter logs by, and every addition multiplies the stream count.
 * An operator can extend it; the point is that the default is safe rather
 * than convenient. */
static const char *const PO_DEFAULT_LABELS[] = {
    "service.name",
    "severity",
    "host.name",
    "deployment.environment",
    NULL
};

typedef struct {
    char     key[PO_LABEL_MAX][PO_LABEL_KEYMAX];
    uint32_t klen[PO_LABEL_MAX];
    int      n;
} po_labelset;

static void po_labelset_default(po_labelset *s) {
    int i;
    memset(s, 0, sizeof(*s));
    for (i = 0; PO_DEFAULT_LABELS[i] && i < PO_LABEL_MAX; i++) {
        size_t l = strlen(PO_DEFAULT_LABELS[i]);
        memcpy(s->key[i], PO_DEFAULT_LABELS[i], l);
        s->klen[i] = (uint32_t)l;
        s->n++;
    }
}

static int po_labelset_add(po_labelset *s, const char *k, size_t len) {
    if (s->n >= PO_LABEL_MAX || len >= PO_LABEL_KEYMAX) return 0;
    memcpy(s->key[s->n], k, len);
    s->klen[s->n] = (uint32_t)len;
    s->n++;
    return 1;
}

/* Is this attribute a stream label, or does it stay in the record?
 *
 * The answer decides whether an attribute multiplies the stream count. A
 * `user_id` answering yes here is how a log store dies. */
static int po_is_label(const po_labelset *s, const char *k, size_t len) {
    int i;
    for (i = 0; i < s->n; i++)
        if (s->klen[i] == (uint32_t)len && memcmp(s->key[i], k, len) == 0)
            return 1;
    return 0;
}

/* ---- the directory -------------------------------------------------------- */

typedef struct {
    po_block_hdr h;
    po_u64       off;        /* of the compressed bytes within the region */
    po_u64       bloom_off;  /* of the bloom bits                          */
} po_dir_ent;

typedef struct {
    po_dir_ent *e;
    uint32_t    n, cap;
} po_blockdir;

static int po_blockdir_init(po_blockdir *d) {
    memset(d, 0, sizeof(*d));
    d->cap = 16;
    d->e = (po_dir_ent *)calloc(d->cap, sizeof(po_dir_ent));
    return d->e != NULL;
}

static void po_blockdir_free(po_blockdir *d) {
    free(d->e); d->e = NULL; d->n = d->cap = 0;
}

static int po_blockdir_add(po_blockdir *d, const po_dir_ent *ent) {
    if (d->n == d->cap) {
        uint32_t want = d->cap * 2;
        po_dir_ent *ne = (po_dir_ent *)realloc(d->e, want * sizeof(po_dir_ent));
        if (!ne) return 0;
        d->e = ne; d->cap = want;
    }
    d->e[d->n++] = *ent;
    return 1;
}

/* THE PRUNE. Given a time range, a stream filter and a search term, which
 * blocks must actually be opened?
 *
 * Three tests in increasing cost order, and the order is the design:
 *   1. the stream        - an integer compare
 *   2. the time span     - two integer compares, no inflation
 *   3. the bloom         - a few hashes over the query's trigrams
 *
 * Only a block surviving all three is decompressed, and then it is matched
 * exactly. `opened` reports how many survived, so a test can assert that the
 * pruning actually pruned rather than trusting that it did. */
typedef struct {
    uint32_t considered;
    uint32_t skipped_stream;
    uint32_t skipped_time;
    uint32_t skipped_bloom;
    uint32_t candidates;
} po_prune_stats;

static int po_block_candidate(const po_dir_ent *e,
                              int have_stream, po_u64 stream,
                              po_u64 from, po_u64 to,
                              const unsigned char *bloom_bits,
                              const char *q, size_t qlen,
                              po_prune_stats *st) {
    if (st) st->considered++;

    if (have_stream && e->h.stream != stream) {
        if (st) st->skipped_stream++;
        return 0;
    }
    if (e->h.t_min > to || e->h.t_max < from) {
        if (st) st->skipped_time++;
        return 0;
    }
    if (qlen && bloom_bits && po_bloom_query_usable(qlen)) {
        if (!po_bloom_may_contain(bloom_bits, e->h.bloom_bits - 1, q, qlen)) {
            if (st) st->skipped_bloom++;
            return 0;
        }
    }
    if (st) st->candidates++;
    return 1;
}

#endif /* PO_LOGIDX_H */
