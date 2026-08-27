/* po_tattr.h - trace summaries, duration search, and segment pruning.
 *
 * "Find traces slower than 500ms with a 5xx" must not decompress spans to
 * answer. Three structures, and the cheapest one runs first.
 *
 * 1. THE SEGMENT FOOTER. Per-segment min and max duration and whether any
 *    error span is present. A segment holding no error span is skipped for an
 *    error query without opening its index at all.
 *
 * 2. THE DURATION ORDINAL ARRAY. Trace summaries sorted BY DURATION, so
 *    `duration > 500ms` is a binary search plus a contiguous range rather
 *    than a scan. This single index is what makes "slow traces in the last
 *    hour" instant, and that is the question people actually come with.
 *
 * 3. THE SUMMARY ROW ITSELF, 48 bytes. A trace SEARCH never opens span data:
 *    the result list, the duration scatter and the service map are all
 *    computed from these rows.
 */
#ifndef PO_TATTR_H
#define PO_TATTR_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_span.h"

typedef struct {
    po_u64   trace_hi, trace_lo;
    po_u64   start_ns;
    po_u64   dur_ns;         /* the ROOT's duration: the request's latency */
    uint32_t root_name_sym;
    uint32_t root_service_sym;
    uint32_t spans;
    uint32_t errors;
} po_tsummary;

typedef struct {
    po_tsummary *t;
    uint32_t     n, cap;
    uint32_t    *by_dur;     /* ordinals into t, sorted by duration */
} po_tsum_set;

static int po_tsum_init(po_tsum_set *s) {
    memset(s, 0, sizeof(*s));
    s->cap = 64;
    s->t = (po_tsummary *)malloc(s->cap * sizeof(po_tsummary));
    return s->t != NULL;
}

static void po_tsum_free(po_tsum_set *s) {
    free(s->t); free(s->by_dur);
    s->t = NULL; s->by_dur = NULL; s->n = s->cap = 0;
}

static int po_tsum_add(po_tsum_set *s, const po_tsummary *src) {
    if (s->n == s->cap) {
        uint32_t want = s->cap * 2;
        po_tsummary *nt = (po_tsummary *)realloc(s->t, want * sizeof(po_tsummary));
        if (!nt) return 0;
        s->t = nt; s->cap = want;
    }
    s->t[s->n++] = *src;
    return 1;
}

/* Summarise a segment's spans into one row per trace.
 *
 * The root's duration is the trace's duration, because that is the request's
 * latency. Using the MAX span duration instead would report an async
 * background span as the request time, which is a plausible number and the
 * wrong one. */
static int po_tsum_build(po_tsum_set *s, const po_span *sp, uint32_t n) {
    uint32_t i = 0;
    while (i < n) {
        uint32_t j = i + 1, k;
        po_tsummary sum;
        po_tree tree;

        while (j < n && sp[j].trace_hi == sp[i].trace_hi
                     && sp[j].trace_lo == sp[i].trace_lo) j++;

        memset(&sum, 0, sizeof(sum));
        sum.trace_hi = sp[i].trace_hi;
        sum.trace_lo = sp[i].trace_lo;
        sum.start_ns = sp[i].start_ns;      /* sorted by start within a trace */
        sum.spans    = j - i;

        for (k = i; k < j; k++) if (po_span_is_error(&sp[k])) sum.errors++;

        /* The root is found by assembling the trace, not by trusting
         * parent_span_id == 0 on any single span. */
        if (po_tree_build(&tree, sp + i, j - i)) {
            uint32_t r;
            for (r = 0; r < tree.n; r++) {
                if (tree.depth[r] == 0) {
                    sum.dur_ns           = sp[i + r].dur_ns;
                    sum.root_name_sym    = sp[i + r].name_sym;
                    sum.root_service_sym = sp[i + r].service_sym;
                    break;
                }
            }
            po_tree_free(&tree);
        }
        if (!po_tsum_add(s, &sum)) return 0;
        i = j;
    }
    return 1;
}

/* Build the by-duration ordinal array. Sorting ORDINALS rather than the rows
 * keeps the summary array in trace order for everything else. */
static const po_tsummary *po_dur_base;   /* qsort has no user pointer in C89 */

static int po_dur_ord_cmp(const void *va, const void *vb) {
    uint32_t a = *(const uint32_t *)va, b = *(const uint32_t *)vb;
    po_u64 da = po_dur_base[a].dur_ns, db = po_dur_base[b].dur_ns;
    if (da != db) return da < db ? -1 : 1;
    /* Total order, or a top-N is non-deterministic and the same query gives
     * different answers on refresh. */
    if (po_dur_base[a].trace_hi != po_dur_base[b].trace_hi)
        return po_dur_base[a].trace_hi < po_dur_base[b].trace_hi ? -1 : 1;
    if (po_dur_base[a].trace_lo != po_dur_base[b].trace_lo)
        return po_dur_base[a].trace_lo < po_dur_base[b].trace_lo ? -1 : 1;
    return 0;
}

static int po_tsum_index(po_tsum_set *s) {
    uint32_t i;
    free(s->by_dur);
    s->by_dur = (uint32_t *)malloc((s->n ? s->n : 1) * sizeof(uint32_t));
    if (!s->by_dur) return 0;
    for (i = 0; i < s->n; i++) s->by_dur[i] = i;
    po_dur_base = s->t;
    if (s->n > 1) qsort(s->by_dur, s->n, sizeof(uint32_t), po_dur_ord_cmp);
    return 1;
}

/* First ordinal whose duration is >= want. Binary search over the ordinal
 * array; the answer is a contiguous range [lo, n) of everything slower. */
static uint32_t po_tsum_lower_bound(const po_tsum_set *s, po_u64 want) {
    uint32_t lo = 0, hi = s->n;
    while (lo < hi) {
        uint32_t mid = lo + (hi - lo) / 2;
        if (s->t[s->by_dur[mid]].dur_ns < want) lo = mid + 1;
        else hi = mid;
    }
    return lo;
}

/* ---- segment-level pruning ------------------------------------------------ */

typedef struct {
    po_u64 t_min, t_max;
    po_u64 dur_min, dur_max;
    int    any_error;
} po_seg_trace_stats;

/* Can this segment possibly contain a matching trace? Answered from the
 * footer alone, with no index and no mmap of the data. */
static int po_seg_may_match(const po_seg_trace_stats *st,
                            po_u64 from, po_u64 to,
                            po_u64 min_dur, int want_error) {
    if (st->t_min > to || st->t_max < from) return 0;
    if (min_dur && st->dur_max < min_dur)   return 0;
    if (want_error && !st->any_error)       return 0;
    return 1;
}

#endif /* PO_TATTR_H */
