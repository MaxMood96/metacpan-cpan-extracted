/* po_log.h - log streams and compressed blocks.
 *
 * INDEX THE LABELS, BRUTE-FORCE THE TEXT, PRUNE WITH A BLOOM.
 *
 * A block is up to 1MB of lines from ONE stream, raw-deflated. 1MB because a
 * block is the decompression unit: smaller means more directory and worse
 * ratios, larger means a query for one minute inflates ten. 1MB of log lines
 * is roughly 5,000-10,000 lines, which is seconds to minutes of a busy
 * service - the granularity of the time ranges people actually ask for.
 *
 * RAW deflate (RFC 1951), not gzip: a gzip header and trailer on every block
 * is 18 bytes of nothing, and the block directory already carries the length
 * and the checksum. The dictionary is reset per block so blocks decompress
 * INDEPENDENTLY, which is what makes the directory useful at all.
 *
 * STRUCTURED FIELDS, because OTLP logs are not strings. trace_id and span_id
 * are first-class columns rather than text to be searched for, and that is
 * what makes phase 9's `| logs` stage a lookup instead of a hunt for a hex
 * string in a haystack.
 */
#ifndef PO_LOG_H
#define PO_LOG_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_rec.h"
#include "punk_observe/po_bloom.h"
#include "punk_observe/po_crc32c.h"

#ifdef PO_HAVE_ZLIB
#  include <zlib.h>
#endif

#define PO_BLOCK_RAW_MAX (1024 * 1024)

/* Block flags */
#define PO_BLK_STORED 0x01     /* not compressed: deflate did not help, or
                                * there is no zlib. Never a silent failure. */

typedef struct {
    po_u64   stream;           /* the interned label set */
    po_u64   t_min, t_max;
    uint32_t lines;
    uint32_t raw_len;
    uint32_t comp_len;
    uint32_t crc;              /* over the RAW bytes, so a bad decompress is
                                * caught rather than fed onward */
    uint32_t bloom_bits;
    uint16_t flags;
} po_block_hdr;

/* ---- writing --------------------------------------------------------------
 *
 * Lines accumulate raw, then the whole block is deflated once when sealed.
 * Per-line compression would give up almost all the ratio: the redundancy in
 * logs is BETWEEN lines, not within one.
 */
typedef struct {
    po_arena     raw;
    po_block_hdr h;
    po_bloom     bloom;
    po_u64       t_last;
    int          have_bloom;
} po_block_w;

static int po_block_w_init(po_block_w *b, po_u64 stream) {
    memset(b, 0, sizeof(*b));
    if (!po_arena_init(&b->raw, 8192)) return 0;
    b->h.stream = stream;
    b->h.t_min  = PO_U64_MAX;
    return 1;
}

static void po_block_w_free(po_block_w *b) {
    po_arena_free(&b->raw);
    if (b->have_bloom) po_bloom_free(&b->bloom);
}

static int po_block_full(const po_block_w *b) {
    return b->raw.len >= PO_BLOCK_RAW_MAX;
}

/* One record on the wire inside a block:
 *
 *   [varint dt][varint severity][varint body_len][body]
 *   [flags byte][trace_id 16][span_id 8]   (ids only when flagged)
 *
 * The timestamp is a DELTA from the previous line, which for a log stream is
 * usually small - lines cluster in time - and costs one or two bytes instead
 * of eight.
 */
static void po_lputv(po_arena *a, po_u64 v) {
    char b[10]; size_t n = 0;
    do { unsigned char c = (unsigned char)(v & 0x7F); v >>= 7;
         if (v) c |= 0x80; b[n++] = (char)c; } while (v);
    po_arena_put(a, b, n);
}

static po_u64 po_lgetv(const unsigned char *b, size_t len, size_t *pos) {
    po_u64 v = 0; int sh = 0;
    while (*pos < len) {
        unsigned char c = b[(*pos)++];
        v |= (po_u64)(c & 0x7F) << sh;
        if (!(c & 0x80)) return v;
        sh += 7;
        if (sh > 63) break;
    }
    return v;
}

static int po_block_add(po_block_w *b, po_u64 t, uint16_t severity,
                        const char *body, size_t body_len,
                        po_u64 tr_hi, po_u64 tr_lo, po_u64 span) {
    unsigned char flags = 0;
    po_u64 dt;

    if (b->h.lines == 0) { b->h.t_min = t; b->t_last = t; dt = 0; }
    else dt = t >= b->t_last ? t - b->t_last : 0;   /* out of order: 0, and
                                                     * t_min/t_max still bound
                                                     * the block correctly */

    po_lputv(&b->raw, dt);
    po_lputv(&b->raw, (po_u64)severity);
    po_lputv(&b->raw, (po_u64)body_len);
    if (body_len && po_arena_put(&b->raw, body, body_len) == PO_ARENA_ERR)
        return 0;

    if (po_trace_id_valid(tr_hi, tr_lo)) flags |= 1;
    if (span) flags |= 2;
    po_arena_put(&b->raw, (const char *)&flags, 1);
    if (flags & 1) {
        char idb[16]; int i;
        for (i = 0; i < 8; i++) idb[i]     = (char)((tr_hi >> (56 - i * 8)) & 0xFF);
        for (i = 0; i < 8; i++) idb[8 + i] = (char)((tr_lo >> (56 - i * 8)) & 0xFF);
        po_arena_put(&b->raw, idb, 16);
    }
    if (flags & 2) {
        char sb[8]; int i;
        for (i = 0; i < 8; i++) sb[i] = (char)((span >> (56 - i * 8)) & 0xFF);
        po_arena_put(&b->raw, sb, 8);
    }

    if (t < b->h.t_min) b->h.t_min = t;
    if (t > b->h.t_max) b->h.t_max = t;
    b->t_last = t;
    b->h.lines++;
    return 1;
}

/* Seal: build the bloom over the block's bodies, then deflate.
 *
 * The bloom is built at seal so it can be SIZED from the block's actual
 * distinct-trigram count rather than from a guess made before any line
 * arrived. */
static int po_block_seal(po_block_w *b, char **out, size_t *outlen) {
    po_tri_count *tc;
    uint32_t distinct;

    /* Count distinct trigrams over the whole raw buffer. Counting over the
     * bodies only would be tighter, but the buffer is a superset and
     * over-sizing a bloom costs bits, while under-sizing it costs the false
     * -negative rate this file exists to keep at zero. */
    tc = (po_tri_count *)calloc(1, sizeof(po_tri_count));
    if (!tc) return 0;
    po_trigrams(b->raw.base, b->raw.len, po_tri_count_cb, tc);
    distinct = tc->n;
    free(tc);

    if (!po_bloom_init(&b->bloom, distinct)) return 0;
    b->have_bloom = 1;
    po_bloom_add_text(&b->bloom, b->raw.base, b->raw.len);
    b->h.bloom_bits = b->bloom.nbits;

    b->h.raw_len = (uint32_t)b->raw.len;
    b->h.crc     = po_crc32c(0, b->raw.base, b->raw.len);

#ifdef PO_HAVE_ZLIB
    {
        z_stream z;
        uLongf cap;
        char *cbuf;
        memset(&z, 0, sizeof(z));
        /* -15: RAW deflate, no zlib or gzip wrapper. */
        if (deflateInit2(&z, 6, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) != Z_OK)
            return 0;
        cap = deflateBound(&z, (uLong)b->raw.len) + 16;
        cbuf = (char *)malloc(cap);
        if (!cbuf) { deflateEnd(&z); return 0; }
        z.next_in   = (Bytef *)b->raw.base;
        z.avail_in  = (uInt)b->raw.len;
        z.next_out  = (Bytef *)cbuf;
        z.avail_out = (uInt)cap;
        if (deflate(&z, Z_FINISH) != Z_STREAM_END) {
            deflateEnd(&z); free(cbuf); return 0;
        }
        b->h.comp_len = (uint32_t)z.total_out;
        deflateEnd(&z);

        /* If deflate did not help, store raw and SAY SO. A block that claims
         * to be compressed and is not would decompress to nothing. */
        if (b->h.comp_len >= b->h.raw_len) {
            free(cbuf);
            b->h.flags |= PO_BLK_STORED;
            b->h.comp_len = b->h.raw_len;
            *out = (char *)malloc(b->raw.len ? b->raw.len : 1);
            if (!*out) return 0;
            memcpy(*out, b->raw.base, b->raw.len);
            *outlen = b->raw.len;
            return 1;
        }
        *out = cbuf;
        *outlen = b->h.comp_len;
        return 1;
    }
#else
    b->h.flags |= PO_BLK_STORED;
    b->h.comp_len = b->h.raw_len;
    *out = (char *)malloc(b->raw.len ? b->raw.len : 1);
    if (!*out) return 0;
    memcpy(*out, b->raw.base, b->raw.len);
    *outlen = b->raw.len;
    return 1;
#endif
}

/* ---- reading -------------------------------------------------------------- */

/* Inflate a block. The caller owns the result. The CRC over the RAW bytes is
 * checked here, so corruption is caught before a single line is handed on. */
static int po_block_inflate(const po_block_hdr *h, const char *comp,
                            size_t comp_len, char **out) {
    char *raw;

    if (h->flags & PO_BLK_STORED) {
        if (comp_len != h->raw_len) return 0;
        raw = (char *)malloc(h->raw_len ? h->raw_len : 1);
        if (!raw) return 0;
        memcpy(raw, comp, h->raw_len);
    }
    else {
#ifdef PO_HAVE_ZLIB
        z_stream z;
        memset(&z, 0, sizeof(z));
        if (inflateInit2(&z, -15) != Z_OK) return 0;
        raw = (char *)malloc(h->raw_len ? h->raw_len : 1);
        if (!raw) { inflateEnd(&z); return 0; }
        z.next_in   = (Bytef *)comp;
        z.avail_in  = (uInt)comp_len;
        z.next_out  = (Bytef *)raw;
        z.avail_out = (uInt)h->raw_len;
        if (inflate(&z, Z_FINISH) != Z_STREAM_END || z.total_out != h->raw_len) {
            inflateEnd(&z); free(raw); return 0;
        }
        inflateEnd(&z);
#else
        return 0;
#endif
    }

    if (po_crc32c(0, raw, h->raw_len) != h->crc) { free(raw); return 0; }
    *out = raw;
    return 1;
}

/* Walk the lines of an inflated block. */
typedef struct {
    const unsigned char *b;
    size_t   len, pos;
    po_u64   t;
    uint32_t i, n;
} po_line_r;

static void po_line_r_init(po_line_r *r, const po_block_hdr *h,
                           const char *raw) {
    memset(r, 0, sizeof(*r));
    r->b = (const unsigned char *)raw;
    r->len = h->raw_len;
    r->n = h->lines;
    r->t = h->t_min;
}

typedef struct {
    po_u64      t;
    uint16_t    severity;
    const char *body;
    size_t      body_len;
    po_u64      trace_hi, trace_lo, span_id;
    int         has_trace;
} po_line;

static int po_line_next(po_line_r *r, po_line *ln) {
    po_u64 dt, sev, blen;
    unsigned char flags;

    if (r->i >= r->n || r->pos >= r->len) return 0;

    dt   = po_lgetv(r->b, r->len, &r->pos);
    sev  = po_lgetv(r->b, r->len, &r->pos);
    blen = po_lgetv(r->b, r->len, &r->pos);
    if (r->pos + blen > r->len) return 0;

    r->t = (r->i == 0) ? r->t : r->t + dt;

    memset(ln, 0, sizeof(*ln));
    ln->t        = r->t;
    ln->severity = (uint16_t)sev;
    ln->body     = (const char *)r->b + r->pos;
    ln->body_len = (size_t)blen;
    r->pos += (size_t)blen;

    if (r->pos >= r->len) return 0;
    flags = r->b[r->pos++];
    if (flags & 1) {
        int i;
        if (r->pos + 16 > r->len) return 0;
        for (i = 0; i < 8; i++) ln->trace_hi = (ln->trace_hi << 8) | r->b[r->pos + i];
        for (i = 0; i < 8; i++) ln->trace_lo = (ln->trace_lo << 8) | r->b[r->pos + 8 + i];
        r->pos += 16;
        ln->has_trace = 1;
    }
    if (flags & 2) {
        int i;
        if (r->pos + 8 > r->len) return 0;
        for (i = 0; i < 8; i++) ln->span_id = (ln->span_id << 8) | r->b[r->pos + i];
        r->pos += 8;
    }
    r->i++;
    return 1;
}

#endif /* PO_LOG_H */
