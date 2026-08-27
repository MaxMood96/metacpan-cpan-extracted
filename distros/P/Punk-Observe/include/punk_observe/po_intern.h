/* po_intern.h - the per-segment symbol table.
 *
 * Where the compression actually comes from. Not the codecs: this.
 *
 * Every attribute key, string value, service name, span name and metric name
 * in a segment becomes a uint32_t, stored once. A million spans from one
 * service store the string "checkout" once and a four-byte reference a
 * million times. It also means predicate evaluation in phase 9 compares
 * integers rather than strings, which is the difference between a scan that
 * is memory-bound and one that is not.
 *
 * Interning is PER SEGMENT, not global. Phase 4 has no global authority by
 * design - every worker seals its own segments - so each segment carries its
 * own table and compaction re-interns globally for the block. The duplication
 * across N workers is bounded by distinct-strings times workers within one
 * two-hour block, and it is paid off exactly once, later, off the hot path.
 */
#ifndef PO_INTERN_H
#define PO_INTERN_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_hash.h"
#include "punk_observe/po_rec.h"

#define PO_SYM_NONE 0xFFFFFFFFu

typedef struct {
    uint32_t off;        /* into the blob */
    uint32_t len;
} po_sym;

typedef struct {
    po_sym   *sym;
    uint32_t *idx;       /* open-addressed: hash -> sym index + 1 */
    uint32_t  n, cap, mask;
    po_arena  blob;      /* the bytes, owned */
} po_intern;

static int po_intern_init(po_intern *t, uint32_t hint) {
    uint32_t slots = 64;
    while (slots < hint * 2) slots <<= 1;
    memset(t, 0, sizeof(*t));
    t->cap = hint < 32 ? 32 : hint;
    t->sym = (po_sym *)calloc(t->cap, sizeof(po_sym));
    if (!t->sym) return 0;
    t->idx = (uint32_t *)calloc(slots, sizeof(uint32_t));
    if (!t->idx) { free(t->sym); t->sym = NULL; return 0; }
    if (!po_arena_init(&t->blob, 4096)) {
        free(t->sym); free(t->idx); t->sym = NULL; t->idx = NULL; return 0;
    }
    t->mask = slots - 1;
    return 1;
}

static void po_intern_free(po_intern *t) {
    free(t->sym); free(t->idx);
    po_arena_free(&t->blob);
    t->sym = NULL; t->idx = NULL; t->n = t->cap = 0;
}

static int po_intern_grow(po_intern *t) {
    uint32_t slots = (t->mask + 1) * 2;
    uint32_t *ni = (uint32_t *)calloc(slots, sizeof(uint32_t));
    uint32_t i;
    if (!ni) return 0;
    for (i = 0; i < t->n; i++) {
        uint32_t h = po_hash32(t->blob.base + t->sym[i].off, t->sym[i].len)
                   & (slots - 1);
        while (ni[h]) h = (h + 1) & (slots - 1);
        ni[h] = i + 1;
    }
    free(t->idx);
    t->idx = ni;
    t->mask = slots - 1;
    return 1;
}

/* Intern a string, returning its id. Same bytes always give the same id
 * WITHIN a segment; ids mean nothing across segments, which is why a reader
 * always resolves through the segment's own table. */
static uint32_t po_intern_put(po_intern *t, const char *p, size_t len) {
    uint32_t h = po_hash32(p, len) & t->mask;

    for (;;) {
        uint32_t e = t->idx[h];
        if (!e) break;
        {
            po_sym *s = &t->sym[e - 1];
            /* memcmp, always: a 32-bit hash match here is a probe hint and
             * nothing more. */
            if (s->len == len &&
                (len == 0 || memcmp(t->blob.base + s->off, p, len) == 0))
                return e - 1;
        }
        h = (h + 1) & t->mask;
    }

    if (t->n == t->cap) {
        uint32_t want = t->cap * 2;
        po_sym *ns = (po_sym *)realloc(t->sym, want * sizeof(po_sym));
        if (!ns) return PO_SYM_NONE;
        t->sym = ns; t->cap = want;
    }
    if ((t->n + 1) * 2 > t->mask + 1) {
        if (!po_intern_grow(t)) return PO_SYM_NONE;
        h = po_hash32(p, len) & t->mask;
        while (t->idx[h]) h = (h + 1) & t->mask;
    }

    {
        uint32_t off = po_arena_put(&t->blob, p, len);
        if (off == PO_ARENA_ERR) return PO_SYM_NONE;
        t->sym[t->n].off = off;
        t->sym[t->n].len = (uint32_t)len;
        t->idx[h] = t->n + 1;
        return t->n++;
    }
}

static const char *po_intern_get(const po_intern *t, uint32_t id, uint32_t *len) {
    if (id >= t->n) { if (len) *len = 0; return NULL; }
    if (len) *len = t->sym[id].len;
    return t->blob.base + t->sym[id].off;
}

/* Serialise: [count][offsets][blob]. The offsets are relative to the blob, so
 * the whole region is position-independent once mmap'd. */
static size_t po_intern_size(const po_intern *t) {
    return 8 + (size_t)t->n * 8 + t->blob.len;
}

static void po_intern_write(const po_intern *t, char *out) {
    uint32_t i;
    uint32_t v;
    char *q = out;
    v = po_le32(t->n);                 memcpy(q, &v, 4); q += 4;
    v = po_le32((uint32_t)t->blob.len); memcpy(q, &v, 4); q += 4;
    for (i = 0; i < t->n; i++) {
        v = po_le32(t->sym[i].off); memcpy(q, &v, 4); q += 4;
        v = po_le32(t->sym[i].len); memcpy(q, &v, 4); q += 4;
    }
    if (t->blob.len) memcpy(q, t->blob.base, t->blob.len);
}

/* A read-only view over a serialised table, straight out of an mmap. Nothing
 * is copied and nothing is allocated. */
typedef struct {
    const char *base;
    uint32_t    n;
    const char *offs;    /* n pairs of (off, len) */
    const char *blob;
    uint32_t    bloblen;
} po_intern_view;

static int po_intern_open(po_intern_view *v, const char *p, size_t len) {
    uint32_t n, bl;
    if (len < 8) return 0;
    memcpy(&n,  p,     4); n  = po_le32(n);
    memcpy(&bl, p + 4, 4); bl = po_le32(bl);
    if ((size_t)8 + (size_t)n * 8 + bl > len) return 0;
    v->base = p; v->n = n;
    v->offs = p + 8;
    v->blob = p + 8 + (size_t)n * 8;
    v->bloblen = bl;
    return 1;
}

static const char *po_intern_view_get(const po_intern_view *v, uint32_t id,
                                      uint32_t *len) {
    uint32_t off, l;
    if (id >= v->n) { if (len) *len = 0; return NULL; }
    memcpy(&off, v->offs + (size_t)id * 8,     4); off = po_le32(off);
    memcpy(&l,   v->offs + (size_t)id * 8 + 4, 4); l   = po_le32(l);
    if ((size_t)off + l > v->bloblen) { if (len) *len = 0; return NULL; }
    if (len) *len = l;
    return v->blob + off;
}

#endif /* PO_INTERN_H */
