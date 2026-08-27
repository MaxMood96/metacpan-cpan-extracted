/* po_tsidx.h - the inverted index: label pair to series.
 *
 *     "service=api"   -> [12, 15, 16, 17, 88, 91, ...]
 *     "http.route=/x" -> [15, 91, ...]
 *
 * `where service = "api" and http.route = "/x"` is an INTERSECTION of two
 * sorted lists, smallest first, which is a linear merge needing no allocation
 * beyond the output. That is the whole design.
 *
 * Stored gap-encoded: the gaps between consecutive ids are small, so varints
 * make the list a fraction of its raw size, with a skip table every 128
 * entries so an intersection can SEEK rather than scan.
 *
 * A roaring bitmap would beat this on very dense postings. It is not used,
 * because postings here are sparse by construction - most label pairs belong
 * to a small fraction of series - and a second compressed-set implementation
 * is a second thing to get wrong. If profiling in phase 9 shows a dense case
 * dominating, that is the moment to add it, with the number that justified it.
 */
#ifndef PO_TSIDX_H
#define PO_TSIDX_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_rec.h"

#define PO_SKIP_EVERY 128

/* ---- building ------------------------------------------------------------ */

typedef struct {
    uint32_t *id;
    uint32_t  n, cap;
    int       sorted;
} po_postings;

static int po_postings_init(po_postings *p) {
    memset(p, 0, sizeof(*p));
    p->cap = 16;
    p->id = (uint32_t *)malloc(p->cap * sizeof(uint32_t));
    p->sorted = 1;
    return p->id != NULL;
}

static void po_postings_free(po_postings *p) {
    free(p->id); p->id = NULL; p->n = p->cap = 0;
}

static int po_postings_add(po_postings *p, uint32_t id) {
    if (p->n == p->cap) {
        uint32_t want = p->cap * 2;
        uint32_t *ni = (uint32_t *)realloc(p->id, want * sizeof(uint32_t));
        if (!ni) return 0;
        p->id = ni; p->cap = want;
    }
    if (p->n && id <= p->id[p->n - 1]) p->sorted = 0;
    p->id[p->n++] = id;
    return 1;
}

static int po_u32cmp(const void *a, const void *b) {
    uint32_t x = *(const uint32_t *)a, y = *(const uint32_t *)b;
    return x < y ? -1 : (x > y ? 1 : 0);
}

/* Sort and dedupe. A series can carry the same label pair only once, but a
 * caller feeding one record per point would add it repeatedly, so the list is
 * made a set here rather than trusting every caller to. */
static void po_postings_finish(po_postings *p) {
    uint32_t i, w = 0;
    if (!p->sorted) qsort(p->id, p->n, sizeof(uint32_t), po_u32cmp);
    for (i = 0; i < p->n; i++)
        if (i == 0 || p->id[i] != p->id[i - 1]) p->id[w++] = p->id[i];
    p->n = w;
    p->sorted = 1;
}

/* Encode gap-varints plus a skip table.
 *
 *   [varint count][skip count][ (u32 id, u32 bitoff) * skips ][gap varints]
 */
static size_t po_postings_encode(const po_postings *p, char **out) {
    size_t cap = 16 + (size_t)p->n * 5 + ((size_t)p->n / PO_SKIP_EVERY + 1) * 8;
    char *b = (char *)malloc(cap);
    size_t o = 0;
    uint32_t i, prev = 0, skips = (p->n + PO_SKIP_EVERY - 1) / PO_SKIP_EVERY;
    size_t skip_at;

    if (!b) { *out = NULL; return 0; }

#define PUTV(v) do { po_u64 _v = (v); \
        do { unsigned char _c = (unsigned char)(_v & 0x7F); _v >>= 7; \
             if (_v) _c |= 0x80; b[o++] = (char)_c; } while (_v); } while (0)

    PUTV((po_u64)p->n);
    PUTV((po_u64)skips);
    skip_at = o;
    o += (size_t)skips * 8;               /* filled in as we go */

    for (i = 0; i < p->n; i++) {
        if (i % PO_SKIP_EVERY == 0) {
            uint32_t s = i / PO_SKIP_EVERY;
            uint32_t v = po_le32(p->id[i]);
            uint32_t f = po_le32((uint32_t)o);
            memcpy(b + skip_at + (size_t)s * 8,     &v, 4);
            memcpy(b + skip_at + (size_t)s * 8 + 4, &f, 4);
            PUTV((po_u64)p->id[i]);       /* skip entries store the id whole */
        }
        else PUTV((po_u64)(p->id[i] - prev));
        prev = p->id[i];
    }
#undef PUTV
    *out = b;
    return o;
}

/* ---- reading ------------------------------------------------------------- */

typedef struct {
    const unsigned char *b;
    size_t   len, pos;
    uint32_t n, i, prev;
    const unsigned char *skip;
    uint32_t skips;
} po_post_r;

static po_u64 po_getv(const unsigned char *b, size_t len, size_t *pos) {
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

static int po_post_open(po_post_r *r, const void *buf, size_t len) {
    size_t pos = 0;
    const unsigned char *b = (const unsigned char *)buf;
    memset(r, 0, sizeof(*r));
    r->b = b; r->len = len;
    r->n     = (uint32_t)po_getv(b, len, &pos);
    r->skips = (uint32_t)po_getv(b, len, &pos);
    if (pos + (size_t)r->skips * 8 > len) return 0;
    r->skip = b + pos;
    r->pos  = pos + (size_t)r->skips * 8;
    return 1;
}

static int po_post_next(po_post_r *r, uint32_t *id) {
    if (r->i >= r->n || r->pos >= r->len) return 0;
    {
        po_u64 v = po_getv(r->b, r->len, &r->pos);
        if (r->i % PO_SKIP_EVERY == 0) r->prev = (uint32_t)v;
        else r->prev = r->prev + (uint32_t)v;
    }
    *id = r->prev;
    r->i++;
    return 1;
}

/* Seek to the first id >= target, using the skip table to avoid decoding
 * every gap. This is what makes an intersection sublinear on the larger list. */
static int po_post_seek(po_post_r *r, uint32_t target, uint32_t *id) {
    uint32_t s;
    for (s = r->skips; s > 0; s--) {
        uint32_t sid, soff;
        memcpy(&sid,  r->skip + (size_t)(s - 1) * 8,     4); sid  = po_le32(sid);
        memcpy(&soff, r->skip + (size_t)(s - 1) * 8 + 4, 4); soff = po_le32(soff);
        if (sid <= target) {
            uint32_t block = s - 1;
            if (block * PO_SKIP_EVERY >= r->i) {
                r->i   = block * PO_SKIP_EVERY;
                r->pos = soff;
            }
            break;
        }
    }
    while (po_post_next(r, id)) if (*id >= target) return 1;
    return 0;
}

/* Intersect two encoded lists. SMALLEST FIRST is the caller's job and it is
 * the difference between a merge and a scan. */
static uint32_t po_post_intersect(const void *a, size_t alen,
                                  const void *b, size_t blen,
                                  uint32_t *out, uint32_t outmax) {
    po_post_r ra, rb;
    uint32_t ia, ib, n = 0;
    if (!po_post_open(&ra, a, alen) || !po_post_open(&rb, b, blen)) return 0;
    if (!po_post_next(&ra, &ia)) return 0;
    if (!po_post_next(&rb, &ib)) return 0;
    for (;;) {
        if (ia == ib) {
            if (n < outmax) out[n] = ia;
            n++;
            if (!po_post_next(&ra, &ia)) break;
            if (!po_post_next(&rb, &ib)) break;
        }
        else if (ia < ib) { if (!po_post_seek(&ra, ib, &ia)) break; }
        else              { if (!po_post_seek(&rb, ia, &ib)) break; }
    }
    return n;
}

#endif /* PO_TSIDX_H */
