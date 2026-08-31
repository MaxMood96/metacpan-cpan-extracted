/* po_chunk.h - the settled part of a window, kept so it is computed once.
 *
 * THE PAST DOES NOT CHANGE, AND IT WAS BEING RECOMPUTED ON EVERY REFRESH.
 *
 * A dashboard over twenty-four hours re-scans twenty-four hours every time it
 * loads, of which all but the last few minutes is settled data that will
 * answer the same way for ever. Measured on a demo store, one panel of
 * `spans | where service = "cards" | bucket(30m) count` took 3.1 seconds, and
 * a two-panel dashboard paid it twice per refresh.
 *
 * WHAT MAKES SPLITTING SOUND is that a bucket is computed from the records
 * inside it and nothing else, and bucket indices are ABSOLUTE - `t /
 * bucket_ns`, never an offset from the query's start (po_qexec.h builds the
 * group key that way). So the buckets two adjacent windows produce are
 * exactly the buckets one window over both would have produced, and
 * concatenating them is not an approximation. t/0930 asserts it against a
 * real store rather than trusting this paragraph.
 *
 * THE CALLER'S ROW BUDGET TRAVELS WITH EACH CHUNK, and getting that wrong is
 * how splitting a window turns a complete answer into a partial one. A panel
 * asks for no ceiling because a graph that stops mid-window draws some other
 * window and labels it with this one; when the split dropped those options
 * and ran every chunk at the store's default, each busy hour truncated at
 * 500,000 and the panel reported the sum of two dozen capped scans. So
 * everything the caller passed beyond the window itself is forwarded verbatim
 * to every chunk, and only the window is this file's to decide.
 *
 * A CHUNK THAT TRUNCATED IS NOT STORED. It is still the answer for this call
 * - it is exactly what an uncached query would have said - but caching it
 * freezes a number that is known to be short for the entry's whole life.
 */
#ifndef PO_CHUNK_H
#define PO_CHUNK_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_query.h"

/* About an hour of work is worth reusing; much more and the settled part
 * shrinks, much less and the entries multiply for no gain. Rounded DOWN to a
 * whole number of buckets - a chunk that split a bucket would store each half
 * as a count of part of it, and the chart would dip at every chunk edge. */
#define PO_CHUNK_TARGET_NS 3600000000000ULL

/* Telemetry arrives late: an exporter batches, a network stalls. A bucket
 * that has only just closed can still gain records, so caching it freezes a
 * number that was about to change. Two minutes is past the batch intervals
 * the SDKs default to; too small shows a wrong value, too large only costs a
 * little more work, so it errs long. */
#define PO_CHUNK_LAG_NS 120000000000ULL

static po_u64 po_chunk_width(po_u64 bucket_ns) {
    po_u64 n;
    if (!bucket_ns) return 0;
    n = PO_CHUNK_TARGET_NS / bucket_ns;
    if (!n) n = 1;
    return bucket_ns * n;
}

static po_u64 po_chunk_floor(po_u64 t, po_u64 w) {
    return w ? (t / w) * w : t;
}

/* THE BUCKET WIDTH, OR ZERO WHEN THE QUERY MUST BE RUN WHOLE.
 *
 * A stage that ranks rows against each other cannot be split: the top five of
 * each half is not the top five of the whole, and a sort has no meaning
 * inside a chunk. The cross-signal stages re-key the stream against a set
 * collected across the entire pipeline, so a chunk of one is not a chunk of
 * the answer. Each of these turns chunking off rather than producing a
 * plausible wrong result - the same rule the planner applies to everything
 * else it cannot honour. */
static po_u64 po_chunk_bucket_ns(const po_query *q) {
    const po_stage *s;
    po_u64 b = 0;
    if (!q) return 0;
    for (s = q->stages; s; s = s->next) {
        switch (s->kind) {
            case PO_ST_LIMIT: case PO_ST_TOPN: case PO_ST_SLOWEST:
            case PO_ST_SORT:
            case PO_ST_EXEMPLARS: case PO_ST_TRACES:
            case PO_ST_LOGS: case PO_ST_SPANS:
                return 0;
            case PO_ST_BUCKET: case PO_ST_RATE:
                if (s->dur) b = s->dur;
                break;
            default: break;
        }
    }
    return b;
}

/* ---- the merged answer ----------------------------------------------------
 *
 * Chunks come back as separate results and have to become one. Held as plain
 * arrays rather than built into Perl structures per chunk, because the merge
 * de-duplicates and the intermediate hashes would all be thrown away.
 */
typedef struct { po_u64 at; double value; po_u64 count; } po_cpt;

typedef struct {
    char   *key;
    size_t  klen;
    po_cpt *pt;
    size_t  n, cap;
} po_cser;

typedef struct {
    po_cser *s;
    size_t   n, cap;
    po_u64   bucket_ns;
    po_u64   scanned;
    po_u64   scanned_bytes;
    int      truncated;
    int      exact;
    int      degraded;
} po_cres;

static void po_cres_init(po_cres *r) {
    memset(r, 0, sizeof(*r));
    r->exact = 1;
}

static void po_cres_free(po_cres *r) {
    size_t i;
    for (i = 0; i < r->n; i++) { free(r->s[i].key); free(r->s[i].pt); }
    free(r->s);
    memset(r, 0, sizeof(*r));
}

static po_cser *po_cres_series(po_cres *r, const char *key, size_t klen) {
    size_t i;
    for (i = 0; i < r->n; i++)
        if (r->s[i].klen == klen
            && (klen == 0 || memcmp(r->s[i].key, key, klen) == 0))
            return &r->s[i];
    if (r->n == r->cap) {
        size_t want = r->cap ? r->cap * 2 : 8;
        po_cser *ns = (po_cser *)realloc(r->s, want * sizeof(po_cser));
        if (!ns) return NULL;
        memset(ns + r->cap, 0, (want - r->cap) * sizeof(po_cser));
        r->s = ns; r->cap = want;
    }
    r->s[r->n].key = (char *)malloc(klen + 1);
    if (!r->s[r->n].key) return NULL;
    if (klen) memcpy(r->s[r->n].key, key, klen);
    r->s[r->n].key[klen] = '\0';
    r->s[r->n].klen = klen;
    return &r->s[r->n++];
}

/* ONE POINT PER (SERIES, INSTANT), the later one winning. Chunks do not
 * overlap, so this only bites at a shared edge - but a duplicated instant
 * would draw a spike where two chunks meet, and a spike that is an artefact
 * of the cache is worse than no cache. */
static int po_cser_put(po_cser *s, po_u64 at, double v, po_u64 count) {
    size_t i;
    for (i = 0; i < s->n; i++) {
        if (s->pt[i].at == at) {
            s->pt[i].value = v;
            s->pt[i].count = count;
            return 1;
        }
    }
    if (s->n == s->cap) {
        size_t want = s->cap ? s->cap * 2 : 32;
        po_cpt *np = (po_cpt *)realloc(s->pt, want * sizeof(po_cpt));
        if (!np) return 0;
        s->pt = np; s->cap = want;
    }
    s->pt[s->n].at = at;
    s->pt[s->n].value = v;
    s->pt[s->n].count = count;
    s->n++;
    return 1;
}

static int po_cpt_cmp(const void *a, const void *b) {
    po_u64 x = ((const po_cpt *)a)->at, y = ((const po_cpt *)b)->at;
    return x < y ? -1 : (x > y ? 1 : 0);
}

static void po_cres_sort(po_cres *r) {
    size_t i;
    for (i = 0; i < r->n; i++)
        if (r->s[i].n > 1)
            qsort(r->s[i].pt, r->s[i].n, sizeof(po_cpt), po_cpt_cmp);
}

/* ---- the stored form ------------------------------------------------------
 *
 * A BESPOKE BLOB, NOT JSON, and the reason is precision rather than speed.
 * An instant is unsigned 64-bit and goes past 2^53, so a JSON number cannot
 * hold one: it would come back rounded to a bucket edge that is near the
 * right one and is not it, and every chunk boundary would drift. Fixed-width
 * little-endian fields have no such question, and the decoder can reject a
 * blob it does not understand instead of half-reading it.
 *
 *   "POC2" | bucket_ns u64 | scanned u64 | scanned_bytes u64 | flags u8
 *          | nseries u32
 *   per series: klen u32, key bytes, npoints u32
 *               per point: at u64, value f64, count u64
 *
 * THE MAGIC IS PART OF THE UPGRADE. `POC1` entries were written by a version
 * whose chunks ran at the store's default row ceiling rather than the
 * caller's, so a busy chunk truncated and froze a partial count for its whole
 * TTL. Those bytes are not worth reading, and the key namespace moved with
 * this magic so they are never reached at all.
 */
#define PO_CHUNK_MAGIC "POC2"
#define PO_CHUNK_F_TRUNCATED 0x01
#define PO_CHUNK_F_INEXACT   0x02
#define PO_CHUNK_F_DEGRADED  0x04

static void po_c_put64(unsigned char *p, po_u64 v) {
    int i;
    for (i = 0; i < 8; i++) p[i] = (unsigned char)((v >> (i * 8)) & 0xFF);
}
static po_u64 po_c_get64(const unsigned char *p) {
    po_u64 v = 0; int i;
    for (i = 0; i < 8; i++) v |= ((po_u64)p[i]) << (i * 8);
    return v;
}
static void po_c_put32(unsigned char *p, uint32_t v) {
    int i;
    for (i = 0; i < 4; i++) p[i] = (unsigned char)((v >> (i * 8)) & 0xFF);
}
static uint32_t po_c_get32(const unsigned char *p) {
    uint32_t v = 0; int i;
    for (i = 0; i < 4; i++) v |= ((uint32_t)p[i]) << (i * 8);
    return v;
}

static size_t po_chunk_size(const po_cres *r) {
    size_t n = 4 + 8 + 8 + 8 + 1 + 4, i;
    for (i = 0; i < r->n; i++)
        n += 4 + r->s[i].klen + 4 + r->s[i].n * 24;
    return n;
}

static size_t po_chunk_encode(const po_cres *r, unsigned char *out) {
    size_t o = 0, i, j;
    memcpy(out, PO_CHUNK_MAGIC, 4); o += 4;
    po_c_put64(out + o, r->bucket_ns); o += 8;
    po_c_put64(out + o, r->scanned);   o += 8;
    po_c_put64(out + o, r->scanned_bytes); o += 8;
    out[o++] = (unsigned char)((r->truncated ? PO_CHUNK_F_TRUNCATED : 0)
                             | (r->exact ? 0 : PO_CHUNK_F_INEXACT)
                             | (r->degraded ? PO_CHUNK_F_DEGRADED : 0));
    po_c_put32(out + o, (uint32_t)r->n); o += 4;
    for (i = 0; i < r->n; i++) {
        po_c_put32(out + o, (uint32_t)r->s[i].klen); o += 4;
        if (r->s[i].klen) { memcpy(out + o, r->s[i].key, r->s[i].klen);
                            o += r->s[i].klen; }
        po_c_put32(out + o, (uint32_t)r->s[i].n); o += 4;
        for (j = 0; j < r->s[i].n; j++) {
            double v = r->s[i].pt[j].value;
            po_u64 bits;
            po_c_put64(out + o, r->s[i].pt[j].at); o += 8;
            memcpy(&bits, &v, 8);
            po_c_put64(out + o, bits); o += 8;
            po_c_put64(out + o, r->s[i].pt[j].count); o += 8;
        }
    }
    return o;
}

/* WOULD THIS BE READ AT ALL. The question a warmer asks, which is not the
 * question a reader asks: it wants to know whether an entry is worth leaving
 * alone, not what is in it, and building a result per chunk to find out would
 * be most of the cost of not having needed to. A blob that passes here and
 * fails the full decode later is deleted by the read path. */
static int po_chunk_valid(const unsigned char *b, size_t len) {
    if (!b || len < 4 + 8 + 8 + 8 + 1 + 4) return 0;
    return memcmp(b, PO_CHUNK_MAGIC, 4) == 0;
}

/* Merges a stored blob INTO an accumulating result. Every length is checked
 * against what is left rather than trusted: the bytes come back from a cache
 * on disk, which is somewhere a truncated write or a stale format can leave
 * something that is not what was written. A blob that does not add up is
 * refused whole, and the caller recomputes the chunk. */
static int po_chunk_decode(po_cres *r, const unsigned char *b, size_t len) {
    size_t o = 0, i, j;
    uint32_t ns;
    unsigned char flags;

    if (len < 4 + 8 + 8 + 8 + 1 + 4) return 0;
    if (memcmp(b, PO_CHUNK_MAGIC, 4) != 0) return 0;
    o = 4;
    if (!r->bucket_ns) r->bucket_ns = po_c_get64(b + o);
    o += 8;
    r->scanned += po_c_get64(b + o); o += 8;
    r->scanned_bytes += po_c_get64(b + o); o += 8;
    flags = b[o++];
    if (flags & PO_CHUNK_F_TRUNCATED) r->truncated = 1;
    if (flags & PO_CHUNK_F_INEXACT)   r->exact = 0;
    if (flags & PO_CHUNK_F_DEGRADED)  r->degraded = 1;
    ns = po_c_get32(b + o); o += 4;

    for (i = 0; i < ns; i++) {
        uint32_t klen, np;
        po_cser *s;
        if (o + 4 > len) return 0;
        klen = po_c_get32(b + o); o += 4;
        if (klen > len || o + klen + 4 > len) return 0;
        s = po_cres_series(r, (const char *)(b + o), klen);
        if (!s) return 0;
        o += klen;
        np = po_c_get32(b + o); o += 4;
        if (np > (len - o) / 24) return 0;
        for (j = 0; j < np; j++) {
            po_u64 at = po_c_get64(b + o);
            po_u64 bits = po_c_get64(b + o + 8);
            po_u64 cnt = po_c_get64(b + o + 16);
            double v;
            memcpy(&v, &bits, 8);
            o += 24;
            if (!po_cser_put(s, at, v, cnt)) return 0;
        }
    }
    return 1;
}

#endif /* PO_CHUNK_H */
