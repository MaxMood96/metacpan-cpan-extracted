/* po_labels.h - the series id, derived rather than assigned.
 *
 * The obvious design hands the compactor a dictionary and has it allocate
 * dense monotonic ids. That needs a single authority, and phase 4 has just
 * removed the one place an authority could live: every worker seals its own
 * segments, so an assigner would be a lock on the hottest path in the system.
 *
 * It is also unnecessary. A series IS its label set, so:
 *
 *     series_id = H128(canonical sorted label block)
 *
 * Two workers computing that independently get the same answer with no
 * coordination, no lock and no shared file. That single property is what
 * makes per-worker writing affordable.
 *
 * The canonical block is what po_attrs_encode already produces in phase 1 -
 * sorted by key, then tag, then value bytes - and the sort is load-bearing
 * here rather than tidiness: if the input order leaked into the bytes, the
 * same series would get two ids, storage would double, and the cardinality
 * cap would count everything twice.
 *
 * AND THE HASH IS STILL VERIFIED. Every lookup compares the full block with
 * memcmp before returning an existing id. 128 bits makes a collision
 * vanishingly unlikely; the memcmp makes it impossible. A hash that is only
 * probably unique is not an identity, and the failure it would cause - two
 * unrelated services silently merged into one chart - is one nobody would
 * ever find.
 */
#ifndef PO_LABELS_H
#define PO_LABELS_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_hash.h"
#include "punk_observe/po_rec.h"

/* One interned series: its id, and where its label block lives. */
typedef struct {
    po_h128  id;
    uint32_t off;        /* into the owning arena */
    uint32_t len;
    uint32_t slot;       /* dense ordinal within this segment */
} po_series;

typedef struct {
    po_series *ent;
    uint32_t  *idx;      /* open-addressed: hash -> ent index + 1, 0 = empty */
    uint32_t   n;
    uint32_t   cap;      /* entries                                        */
    uint32_t   mask;     /* idx is a power of two                          */
    po_arena  *arena;    /* borrowed: where label blocks live              */
    uint32_t   collisions;   /* full-hash collisions caught by memcmp      */
} po_series_tab;

static int po_series_tab_init(po_series_tab *t, po_arena *arena, uint32_t hint) {
    uint32_t slots = 64;
    while (slots < hint * 2) slots <<= 1;
    memset(t, 0, sizeof(*t));
    t->cap = hint < 32 ? 32 : hint;
    t->ent = (po_series *)calloc(t->cap, sizeof(po_series));
    if (!t->ent) return 0;
    t->idx = (uint32_t *)calloc(slots, sizeof(uint32_t));
    if (!t->idx) { free(t->ent); t->ent = NULL; return 0; }
    t->mask  = slots - 1;
    t->arena = arena;
    return 1;
}

static void po_series_tab_free(po_series_tab *t) {
    free(t->ent); free(t->idx);
    t->ent = NULL; t->idx = NULL; t->n = t->cap = 0;
}

static int po_series_grow(po_series_tab *t) {
    uint32_t slots = (t->mask + 1) * 2;
    uint32_t *ni = (uint32_t *)calloc(slots, sizeof(uint32_t));
    uint32_t i;
    if (!ni) return 0;
    for (i = 0; i < t->n; i++) {
        uint32_t h = (uint32_t)(t->ent[i].id.lo) & (slots - 1);
        while (ni[h]) h = (h + 1) & (slots - 1);
        ni[h] = i + 1;
    }
    free(t->idx);
    t->idx  = ni;
    t->mask = slots - 1;
    return 1;
}

/* Look up or intern. `block` is the canonical attribute block from
 * po_attrs_encode. Returns the dense slot, or 0xFFFFFFFF on failure.
 *
 * `created` is set when this call introduced the series - which is the ONLY
 * moment the cardinality cap can be enforced, because it is the only moment
 * anything knows the set is new. */
#define PO_SERIES_ERR 0xFFFFFFFFu

static uint32_t po_series_intern(po_series_tab *t,
                                 const char *block, uint32_t len,
                                 po_h128 *id_out, int *created) {
    po_h128 h = po_murmur3_128(block, (size_t)len, 0);
    uint32_t pos = (uint32_t)h.lo & t->mask;

    if (created) *created = 0;

    for (;;) {
        uint32_t e = t->idx[pos];
        if (!e) break;
        {
            po_series *s = &t->ent[e - 1];
            if (po_h128_eq(s->id, h)) {
                /* The hash matched. Now VERIFY, because a 128-bit match is
                 * not proof and the failure it would hide is invisible. */
                if (s->len == len &&
                    (len == 0 || memcmp(t->arena->base + s->off, block, len) == 0)) {
                    if (id_out) *id_out = h;
                    return s->slot;
                }
                /* A genuine full-hash collision on different bytes. Counted,
                 * because if this is ever non-zero in the field it is worth
                 * knowing rather than guessing at. */
                t->collisions++;
            }
        }
        pos = (pos + 1) & t->mask;
    }

    if (t->n == t->cap) {
        uint32_t want = t->cap * 2;
        po_series *ne = (po_series *)realloc(t->ent, want * sizeof(po_series));
        if (!ne) return PO_SERIES_ERR;
        t->ent = ne; t->cap = want;
    }
    if ((t->n + 1) * 2 > t->mask + 1) {
        if (!po_series_grow(t)) return PO_SERIES_ERR;
        pos = (uint32_t)h.lo & t->mask;
        while (t->idx[pos]) pos = (pos + 1) & t->mask;
    }

    {
        uint32_t off = len ? po_arena_put(t->arena, block, (size_t)len) : 0;
        po_series *s;
        if (len && off == PO_ARENA_ERR) return PO_SERIES_ERR;
        s = &t->ent[t->n];
        s->id   = h;
        s->off  = off;
        s->len  = len;
        s->slot = t->n;
        t->idx[pos] = t->n + 1;
        t->n++;
        if (id_out) *id_out = h;
        if (created) *created = 1;
        return s->slot;
    }
}

/* The 64 bits stored in po_rec.series. The full 128 live in the segment's
 * series table; the record carries the low half plus its dense slot, which is
 * all a reader needs to get back to the whole thing. */
static po_u64 po_series_key(po_h128 id) { return id.lo; }

#endif /* PO_LABELS_H */
