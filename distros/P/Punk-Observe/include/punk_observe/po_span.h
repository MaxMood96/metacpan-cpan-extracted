/* po_span.h - spans, and the tree that is built when they are READ.
 *
 * A TRACE IS NEVER COMPLETE, so nothing may wait for one.
 *
 * The spans of one trace arrive from many processes, in many batches, out of
 * order, across a window bounded only by the longest span. A backend that
 * assembles traces at write time has to buffer them, decide when a trace is
 * done, and be wrong.
 *
 * So spans are stored individually and a trace is assembled at read time. The
 * consequences are all good ones: ingest never buffers, a span arriving an
 * hour late still joins its trace, and there is no "trace timeout" setting
 * for anyone to get wrong. The cost is that reading a trace is a lookup
 * rather than a sequential read, which is what po_traceidx.h is for - and
 * spans are SORTED at seal by (trace, start) so that once the lookup lands,
 * the trace's spans are physically contiguous.
 */
#ifndef PO_SPAN_H
#define PO_SPAN_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_rec.h"
#include "punk_observe/po_hash.h"

/* Span flags */
#define PO_SP_ROOT      0x0001   /* no parent AT ALL, decided at read time */
#define PO_SP_ERROR     0x0002
#define PO_SP_CLAMPED   0x0004   /* end < start; see phase 0's clock rule   */

/* Fixed 64 bytes: 8-byte members first, then 4, then 2, then 1, so the
 * layout is stable across every ABI in the smoker matrix. */
typedef struct {
    po_u64   trace_hi, trace_lo;
    po_u64   span_id;
    po_u64   parent_span_id;
    po_u64   start_ns;
    po_u64   dur_ns;
    uint32_t name_sym;        /* into the segment's symbol table */
    uint32_t service_sym;
    uint16_t flags;
    uint8_t  kind;            /* OTLP SpanKind */
    uint8_t  status;          /* OTLP StatusCode */
    uint8_t  pad[4];
} po_span;

#define PO_SPAN_SIZE 64

static int po_span_is_error(const po_span *s) { return s->status == PO_ST_ERROR; }

/* Sort key: trace first so a trace's spans are contiguous, then start time so
 * they are already in waterfall order once found. */
static int po_span_cmp(const void *va, const void *vb) {
    const po_span *a = (const po_span *)va, *b = (const po_span *)vb;
    if (a->trace_hi != b->trace_hi) return a->trace_hi < b->trace_hi ? -1 : 1;
    if (a->trace_lo != b->trace_lo) return a->trace_lo < b->trace_lo ? -1 : 1;
    if (a->start_ns != b->start_ns) return a->start_ns < b->start_ns ? -1 : 1;
    /* A total order: two spans with the same trace and start need a tiebreak,
     * or the sort is unstable and the same segment sealed twice differs. */
    if (a->span_id != b->span_id) return a->span_id < b->span_id ? -1 : 1;
    return 0;
}

/* ---- the writer ----------------------------------------------------------- */

typedef struct {
    po_span *s;
    size_t   n, cap;
    po_u64   t_min, t_max;
    po_u64   dur_min, dur_max;
    int      any_error;         /* so a segment with no error span is never
                                 * opened for an error query */
    uint32_t clamped;
} po_span_w;

static int po_span_w_init(po_span_w *w) {
    memset(w, 0, sizeof(*w));
    w->cap = 256;
    w->s = (po_span *)malloc(w->cap * sizeof(po_span));
    if (!w->s) return 0;
    w->t_min = PO_U64_MAX;
    w->dur_min = PO_U64_MAX;
    return 1;
}

static void po_span_w_free(po_span_w *w) { free(w->s); w->s = NULL; w->n = w->cap = 0; }

static int po_span_add(po_span_w *w, const po_span *src) {
    po_span *d;
    if (w->n == w->cap) {
        size_t want = w->cap * 2;
        po_span *ns = (po_span *)realloc(w->s, want * sizeof(po_span));
        if (!ns) return 0;
        w->s = ns; w->cap = want;
    }
    d = &w->s[w->n++];
    *d = *src;

    if (d->start_ns < w->t_min) w->t_min = d->start_ns;
    if (d->start_ns > w->t_max) w->t_max = d->start_ns;
    if (d->dur_ns < w->dur_min) w->dur_min = d->dur_ns;
    if (d->dur_ns > w->dur_max) w->dur_max = d->dur_ns;
    if (po_span_is_error(d)) w->any_error = 1;
    if (d->flags & PO_SP_CLAMPED) w->clamped++;
    return 1;
}

static void po_span_w_seal(po_span_w *w) {
    if (w->n > 1) qsort(w->s, w->n, sizeof(po_span), po_span_cmp);
}

/* ---- the tree, built at READ time ----------------------------------------
 *
 * A hash join over the spans returned: span_id -> index, then each span's
 * parent is looked up among them.
 *
 * TWO THINGS THAT LOOK LIKE DETAILS AND ARE NOT.
 *
 * 1. parent_span_id == 0 means root, but a span whose parent IS present in
 *    the trace and merely arrived in a later segment is NOT a root. So
 *    rootness is decided only after the whole trace is assembled - deciding
 *    it per span, at write time, makes every trace show several roots.
 *
 * 2. A cycle in the parent chain is possible from broken instrumentation, and
 *    a naive tree walk recurses forever on it. Bounded, and reported.
 */
#define PO_TREE_MAX_DEPTH 256

typedef struct {
    const po_span *s;
    uint32_t       n;
    int32_t       *parent;     /* index of the parent span, or -1  */
    int32_t       *depth;      /* 0 for a root                     */
    uint32_t       roots;
    uint32_t       cycles;     /* spans whose ancestry loops       */
    uint32_t       orphans;    /* parent named but not present     */
} po_tree;

static void po_tree_free(po_tree *t) {
    free(t->parent); free(t->depth);
    t->parent = NULL; t->depth = NULL;
}

static int po_tree_build(po_tree *t, const po_span *spans, uint32_t n) {
    uint32_t i;
    uint32_t slots = 16, mask;
    uint32_t *idx;

    memset(t, 0, sizeof(*t));
    t->s = spans; t->n = n;
    if (n == 0) return 1;

    t->parent = (int32_t *)malloc((size_t)n * sizeof(int32_t));
    t->depth  = (int32_t *)malloc((size_t)n * sizeof(int32_t));
    if (!t->parent || !t->depth) { po_tree_free(t); return 0; }

    while (slots < n * 2) slots <<= 1;
    mask = slots - 1;
    idx = (uint32_t *)calloc(slots, sizeof(uint32_t));
    if (!idx) { po_tree_free(t); return 0; }

    for (i = 0; i < n; i++) {
        uint32_t h = (uint32_t)(spans[i].span_id) & mask;
        while (idx[h]) h = (h + 1) & mask;
        idx[h] = i + 1;
    }

    for (i = 0; i < n; i++) {
        t->parent[i] = -1;
        t->depth[i]  = -1;
        if (spans[i].parent_span_id) {
            uint32_t h = (uint32_t)(spans[i].parent_span_id) & mask;
            int found = 0;
            while (idx[h]) {
                uint32_t j = idx[h] - 1;
                if (spans[j].span_id == spans[i].parent_span_id
                    && spans[j].trace_hi == spans[i].trace_hi
                    && spans[j].trace_lo == spans[i].trace_lo) {
                    t->parent[i] = (int32_t)j;
                    found = 1;
                    break;
                }
                h = (h + 1) & mask;
            }
            /* A parent named but absent: the span is a root FOR NOW, and
             * counted, because that count is how an operator sees that a
             * trace is incomplete rather than genuinely shallow. */
            if (!found) t->orphans++;
        }
    }
    free(idx);

    /* Depths, with the cycle bound. */
    for (i = 0; i < n; i++) {
        int32_t cur = (int32_t)i;
        int d = 0;
        while (cur >= 0 && d <= PO_TREE_MAX_DEPTH) {
            if (t->parent[cur] < 0) break;
            cur = t->parent[cur];
            d++;
        }
        if (d > PO_TREE_MAX_DEPTH) { t->depth[i] = -1; t->cycles++; }
        else t->depth[i] = d;
    }

    for (i = 0; i < n; i++) {
        if (t->depth[i] == 0) {
            t->roots++;
            /* Rootness is set HERE, after assembly, not at write time. */
        }
    }
    return 1;
}

#endif /* PO_SPAN_H */
