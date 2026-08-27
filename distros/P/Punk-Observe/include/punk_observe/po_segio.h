/* po_segio.h - the three signals, into and out of a segment.
 *
 * THE JOIN THAT PHASES 5, 6 AND 7 DEFERRED.
 *
 * Each of those phases built its structure in memory and stopped there,
 * because a segment could not yet carry it. This is where they land on disk:
 * metric chunks, log blocks and span arrays become regions, and a reader gets
 * them back without copying - the arrays are read straight out of the
 * mapping.
 *
 * Every region is length-prefixed and bounds-checked on the way back in. A
 * region is untrusted input the moment it has been on a disk: a bit flip, a
 * partial write a CRC somehow survived, or a file from a newer version all
 * arrive here, and the answer to each is a refusal rather than a pointer into
 * somebody else's memory.
 */
#ifndef PO_SEGIO_H
#define PO_SEGIO_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_seg.h"
#include "punk_observe/po_metric.h"
#include "punk_observe/po_log.h"
#include "punk_observe/po_span.h"
#include "punk_observe/po_traceidx.h"
#include "punk_observe/po_tattr.h"

/* A tiny append-only buffer, so each serialiser reads the same way. */
typedef struct { char *b; size_t n, cap; int err; } po_buf;

static int po_buf_init(po_buf *b) {
    memset(b, 0, sizeof(*b));
    b->cap = 256;
    b->b = (char *)malloc(b->cap);
    return b->b != NULL;
}
static void po_buf_free(po_buf *b) { free(b->b); b->b = NULL; }

static void po_buf_put(po_buf *b, const void *p, size_t n) {
    if (b->err) return;
    if (b->n + n > b->cap) {
        size_t want = b->cap * 2;
        char *nb;
        while (want < b->n + n) want *= 2;
        nb = (char *)realloc(b->b, want);
        if (!nb) { b->err = 1; return; }
        b->b = nb; b->cap = want;
    }
    if (n) memcpy(b->b + b->n, p, n);
    b->n += n;
}
static void po_buf_u32(po_buf *b, uint32_t v) { v = po_le32(v); po_buf_put(b, &v, 4); }
static void po_buf_u64(po_buf *b, po_u64 v)   { v = po_le64(v); po_buf_put(b, &v, 8); }

/* A bounds-checked reader over a region. */
typedef struct { const char *b; size_t n, i; int err; } po_rd;

static void po_rd_init(po_rd *r, const char *p, size_t n) {
    r->b = p; r->n = n; r->i = 0; r->err = 0;
}
static uint32_t po_rd_u32(po_rd *r) {
    uint32_t v;
    if (r->err || r->n - r->i < 4) { r->err = 1; return 0; }
    memcpy(&v, r->b + r->i, 4); r->i += 4;
    return po_le32(v);
}
static po_u64 po_rd_u64(po_rd *r) {
    po_u64 v;
    if (r->err || r->n - r->i < 8) { r->err = 1; return 0; }
    memcpy(&v, r->b + r->i, 8); r->i += 8;
    return po_le64(v);
}
/* Borrows into the region: zero copy, and valid while the mapping is. */
static const char *po_rd_bytes(po_rd *r, size_t n) {
    const char *p;
    if (r->err || r->n - r->i < n) { r->err = 1; return NULL; }
    p = r->b + r->i; r->i += n;
    return p;
}

/* ---- metrics --------------------------------------------------------------
 *
 *   [count] ( [series][t_first][t_last][count][bits][flags][stream bytes] )*
 */
static char *po_metric_serialise(const po_chunk_hdr *h, const char *const *bits,
                                 const po_u64 *series, uint32_t n, size_t *out) {
    po_buf b;
    uint32_t i;
    if (!po_buf_init(&b)) return NULL;
    po_buf_u32(&b, n);
    for (i = 0; i < n; i++) {
        size_t bytes = (h[i].bits + 7) / 8;
        po_buf_u64(&b, series[i]);
        po_buf_u64(&b, h[i].t_first);
        po_buf_u64(&b, h[i].t_last);
        po_buf_u32(&b, h[i].count);
        po_buf_u32(&b, h[i].bits);
        po_buf_u32(&b, (uint32_t)h[i].flags);
        po_buf_u32(&b, (uint32_t)bytes);
        po_buf_put(&b, bits[i], bytes);
    }
    if (b.err) { po_buf_free(&b); return NULL; }
    *out = b.n;
    return b.b;
}

typedef struct {
    po_u64        series;
    po_chunk_hdr  h;
    const char   *bits;
} po_mchunk_ref;

/* Returns the chunk count, or -1. `into` must hold at least that many. */
static int po_metric_open(const char *p, size_t len, po_mchunk_ref *into,
                          uint32_t max) {
    po_rd r;
    uint32_t n, i;
    po_rd_init(&r, p, len);
    n = po_rd_u32(&r);
    if (r.err || n > max) return -1;
    for (i = 0; i < n; i++) {
        uint32_t bytes;
        into[i].series    = po_rd_u64(&r);
        into[i].h.t_first = po_rd_u64(&r);
        into[i].h.t_last  = po_rd_u64(&r);
        into[i].h.count   = po_rd_u32(&r);
        into[i].h.bits    = po_rd_u32(&r);
        into[i].h.flags   = (uint16_t)po_rd_u32(&r);
        bytes             = po_rd_u32(&r);
        /* The declared bit count and the byte count must agree, or a reader
         * walks off the end of a bit stream that claims to be longer than it
         * is. Checked here rather than trusted. */
        if (r.err || bytes != (into[i].h.bits + 7) / 8) return -1;
        into[i].bits = po_rd_bytes(&r, bytes);
        if (r.err) return -1;
    }
    return (int)n;
}

/* ---- logs -----------------------------------------------------------------
 *
 *   [count] ( [hdr fields][bloom bytes][compressed bytes] )*
 */
static char *po_log_serialise(const po_block_hdr *h, const char *const *comp,
                              const unsigned char *const *bloom,
                              uint32_t n, size_t *out) {
    po_buf b;
    uint32_t i;
    if (!po_buf_init(&b)) return NULL;
    po_buf_u32(&b, n);
    for (i = 0; i < n; i++) {
        uint32_t bloom_bytes = (h[i].bloom_bits + 7) / 8;
        po_buf_u64(&b, h[i].stream);
        po_buf_u64(&b, h[i].t_min);
        po_buf_u64(&b, h[i].t_max);
        po_buf_u32(&b, h[i].lines);
        po_buf_u32(&b, h[i].raw_len);
        po_buf_u32(&b, h[i].comp_len);
        po_buf_u32(&b, h[i].crc);
        po_buf_u32(&b, h[i].bloom_bits);
        po_buf_u32(&b, (uint32_t)h[i].flags);
        po_buf_put(&b, bloom[i], bloom_bytes);
        po_buf_put(&b, comp[i], h[i].comp_len);
    }
    if (b.err) { po_buf_free(&b); return NULL; }
    *out = b.n;
    return b.b;
}

typedef struct {
    po_block_hdr         h;
    const unsigned char *bloom;
    const char          *comp;
} po_lblock_ref;

static int po_log_open(const char *p, size_t len, po_lblock_ref *into,
                       uint32_t max) {
    po_rd r;
    uint32_t n, i;
    po_rd_init(&r, p, len);
    n = po_rd_u32(&r);
    if (r.err || n > max) return -1;
    for (i = 0; i < n; i++) {
        uint32_t bloom_bytes;
        into[i].h.stream     = po_rd_u64(&r);
        into[i].h.t_min      = po_rd_u64(&r);
        into[i].h.t_max      = po_rd_u64(&r);
        into[i].h.lines      = po_rd_u32(&r);
        into[i].h.raw_len    = po_rd_u32(&r);
        into[i].h.comp_len   = po_rd_u32(&r);
        into[i].h.crc        = po_rd_u32(&r);
        into[i].h.bloom_bits = po_rd_u32(&r);
        into[i].h.flags      = (uint16_t)po_rd_u32(&r);
        if (r.err) return -1;
        bloom_bytes = (into[i].h.bloom_bits + 7) / 8;
        into[i].bloom = (const unsigned char *)po_rd_bytes(&r, bloom_bytes);
        into[i].comp  = po_rd_bytes(&r, into[i].h.comp_len);
        if (r.err) return -1;
    }
    return (int)n;
}

/* ---- spans ----------------------------------------------------------------
 *
 * The span array is written verbatim: it is already a flat array of fixed
 * 64-byte structs sorted by (trace, start), so serialising it is a memcpy and
 * reading it back is a cast. That is the payoff for making po_span a plain
 * struct with no pointers in it.
 */
static char *po_span_serialise(const po_span *s, uint32_t n, size_t *out) {
    size_t bytes = (size_t)n * sizeof(po_span);
    char *b = (char *)malloc(bytes ? bytes : 1);
    if (!b) return NULL;
    if (bytes) memcpy(b, s, bytes);
    *out = bytes;
    return b;
}

static const po_span *po_span_open(const char *p, size_t len, uint32_t *n) {
    if (len % sizeof(po_span)) { *n = 0; return NULL; }   /* not a span array */
    *n = (uint32_t)(len / sizeof(po_span));
    return (const po_span *)p;
}

/* ---- trace summaries ------------------------------------------------------ */

static char *po_tsum_serialise(const po_tsummary *t, uint32_t n, size_t *out) {
    size_t bytes = (size_t)n * sizeof(po_tsummary);
    char *b = (char *)malloc(bytes ? bytes : 1);
    if (!b) return NULL;
    if (bytes) memcpy(b, t, bytes);
    *out = bytes;
    return b;
}

static const po_tsummary *po_tsum_open(const char *p, size_t len, uint32_t *n) {
    if (len % sizeof(po_tsummary)) { *n = 0; return NULL; }
    *n = (uint32_t)(len / sizeof(po_tsummary));
    return (const po_tsummary *)p;
}

#endif /* PO_SEGIO_H */
