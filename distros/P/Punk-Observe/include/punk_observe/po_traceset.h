/* po_traceset.h - a set of trace ids, and the join key it makes.
 *
 * THE CROSS-SIGNAL PIPELINE IS A JOIN, and this is its key. `metric ... |
 * exemplars | traces | logs` runs the metric side, collects the trace ids the
 * surviving points carried, and reads the log side filtered to that SET. The
 * single-id filter has always existed - it is how the trace page shows a
 * trace's own log lines - and this is the same operation for more than one.
 *
 * SORTED ARRAY, BINARY SEARCH, NOT A HASH. The set is built once and then
 * tested against every row of a scan, which is the ratio a hash is the wrong
 * shape for: the build is one qsort, the test is a handful of comparisons
 * with no pointer chasing, and the whole thing is contiguous in a scan that
 * is already memory-bound. A thousand ids is ten comparisons per row.
 *
 * The set is BOUNDED, and the bound is a refusal rather than a degradation -
 * a join whose left side produced more traces than this cannot be answered by
 * scanning, and answering it approximately would be the silent-wrong-rows
 * failure the whole query layer refuses elsewhere.
 */
#ifndef PO_TRACESET_H
#define PO_TRACESET_H

#include "punk_observe/po_compat.h"

/* Above this, the join refuses and says so. Sized from what a join can
 * usefully return rather than from what fits: a person reading the logs of
 * four thousand traces is not reading anything, and the query that produced
 * them wanted an aggregate. */
#define PO_TRACESET_MAX 4096

typedef struct { po_u64 hi, lo; } po_traceid;

typedef struct {
    po_traceid *id;
    uint32_t    n, cap;
    int         overflowed;   /* hit PO_TRACESET_MAX; the caller refuses */
} po_traceset;

static int po_traceset_init(po_traceset *s) {
    memset(s, 0, sizeof(*s));
    s->cap = 64;
    s->id = (po_traceid *)malloc(s->cap * sizeof(po_traceid));
    return s->id != NULL;
}

static void po_traceset_free(po_traceset *s) {
    free(s->id); s->id = NULL; s->n = s->cap = 0;
}

/* Appended, not inserted: duplicates are expected - every point of a spiky
 * series may carry the same exemplar - and are removed once by the sort
 * rather than searched for on every add. */
static int po_traceset_add(po_traceset *s, po_u64 hi, po_u64 lo) {
    if (!po_trace_id_valid(hi, lo)) return 1;   /* nothing to join to */
    if (s->n >= PO_TRACESET_MAX) { s->overflowed = 1; return 0; }
    if (s->n == s->cap) {
        uint32_t want = s->cap * 2;
        po_traceid *ni = (po_traceid *)realloc(s->id, want * sizeof(po_traceid));
        if (!ni) return 0;
        s->id = ni; s->cap = want;
    }
    s->id[s->n].hi = hi;
    s->id[s->n].lo = lo;
    s->n++;
    return 1;
}

static int po_traceid_cmp(const void *a, const void *b) {
    const po_traceid *x = (const po_traceid *)a, *y = (const po_traceid *)b;
    if (x->hi != y->hi) return x->hi < y->hi ? -1 : 1;
    if (x->lo != y->lo) return x->lo < y->lo ? -1 : 1;
    return 0;
}

/* Sort and unique, in place. Called once, after the whole left side is in. */
static void po_traceset_seal(po_traceset *s) {
    uint32_t i, k;
    if (s->n < 2) return;
    qsort(s->id, (size_t)s->n, sizeof(po_traceid), po_traceid_cmp);
    for (i = 1, k = 1; i < s->n; i++) {
        if (po_traceid_cmp(&s->id[i], &s->id[k - 1]) == 0) continue;
        s->id[k++] = s->id[i];
    }
    s->n = k;
}

static int po_traceset_has(const po_traceset *s, po_u64 hi, po_u64 lo) {
    uint32_t lo_i = 0, hi_i = s->n;
    while (lo_i < hi_i) {
        uint32_t mid = lo_i + (hi_i - lo_i) / 2;
        const po_traceid *m = &s->id[mid];
        if (m->hi == hi && m->lo == lo) return 1;
        if (m->hi < hi || (m->hi == hi && m->lo < lo)) lo_i = mid + 1;
        else hi_i = mid;
    }
    return 0;
}

#endif /* PO_TRACESET_H */
