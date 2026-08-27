/* po_rollup.h - downsampled tiers, and the aggregate that is refused.
 *
 * A month of a 15-second series is 172,800 points. Charting it on a
 * 1,200-pixel screen decodes 144 points per pixel to draw one, which is a
 * long wait for a picture that could not show the difference.
 *
 * So the compactor writes two tiers, at five minutes and one hour, each point
 * carrying:
 *
 *     { count, sum, min, max, last }
 *
 * THAT SET IS CLOSED UNDER MERGING, which is the property that matters: an
 * hourly point is built from twelve five-minute points without going back to
 * the raw data, and the arithmetic is the same at every tier.
 *
 * IT ANSWERS EVERY AGGREGATE THE LANGUAGE HAS - EXCEPT ONE.
 *
 *     avg  = sum / count
 *     min  = min
 *     max  = max
 *     sum  = sum
 *     rate = a difference over count or sum, per temporality
 *     p50, p90, p95, p99  -> REFUSED
 *
 * PERCENTILES DO NOT MERGE FROM SUMMARY STATISTICS. There is no function of
 * {count, sum, min, max} that yields a p95, and every approximation that
 * looks close is wrong in the tail - which is the only part of a latency
 * chart anybody reads. A store that quietly returns a plausible number here
 * has broken the single thing the chart is for, so it returns an error
 * instead, and phase 12 renders that error rather than an empty panel.
 *
 * Where the series is a HISTOGRAM the percentile merges exactly from the
 * bucket counts, and the rollup keeps them. That is the supported path for a
 * long-range percentile, and it is why histogram instruments are worth using.
 */
#ifndef PO_ROLLUP_H
#define PO_ROLLUP_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_metric.h"

#define PO_TIER_RAW 0
#define PO_TIER_5M  1
#define PO_TIER_1H  2

#define PO_TIER_5M_NS ((po_u64)300  * 1000000000ULL)
#define PO_TIER_1H_NS ((po_u64)3600 * 1000000000ULL)

static po_u64 po_tier_span(int tier) {
    return tier == PO_TIER_5M ? PO_TIER_5M_NS
         : tier == PO_TIER_1H ? PO_TIER_1H_NS : 0;
}

typedef struct {
    po_u64 t;            /* the bucket's start, tier-aligned */
    po_u64 count;
    double sum;
    double min, max;
    double last;
    int    resets;       /* counter resets INSIDE this bucket */
} po_rpoint;

typedef struct {
    po_rpoint *p;
    uint32_t   n, cap;
    int        tier;
} po_rollup;

static int po_rollup_init(po_rollup *r, int tier) {
    memset(r, 0, sizeof(*r));
    r->tier = tier;
    r->cap = 32;
    r->p = (po_rpoint *)calloc(r->cap, sizeof(po_rpoint));
    return r->p != NULL;
}

static void po_rollup_free(po_rollup *r) {
    free(r->p); r->p = NULL; r->n = r->cap = 0;
}

static po_rpoint *po_rollup_bucket(po_rollup *r, po_u64 t) {
    po_u64 span = po_tier_span(r->tier);
    po_u64 start = span ? t - (t % span) : t;
    if (r->n && r->p[r->n - 1].t == start) return &r->p[r->n - 1];
    if (r->n == r->cap) {
        uint32_t want = r->cap * 2;
        po_rpoint *np = (po_rpoint *)realloc(r->p, want * sizeof(po_rpoint));
        if (!np) return NULL;
        memset(np + r->cap, 0, (want - r->cap) * sizeof(po_rpoint));
        r->p = np; r->cap = want;
    }
    r->p[r->n].t = start;
    return &r->p[r->n++];
}

/* Fold one raw point in.
 *
 * `reset` is the flag the CHUNK carries, detected at encode time in phase 5.
 * It is recorded here because the raw points are about to be dropped, and a
 * rate computed over a rolled-up range containing an undetected reset is
 * simply wrong with nothing left in the data to reveal it. */
static int po_rollup_add(po_rollup *r, po_u64 t, double v, int reset) {
    po_rpoint *b = po_rollup_bucket(r, t);
    if (!b) return 0;
    if (b->count == 0) { b->min = v; b->max = v; }
    else {
        if (v < b->min) b->min = v;
        if (v > b->max) b->max = v;
    }
    b->sum += v;
    b->last = v;
    b->count++;
    if (reset) b->resets++;
    return 1;
}

/* Build the next tier up from this one, WITHOUT touching the raw data. This
 * is the closure property in one function. */
static int po_rollup_promote(const po_rollup *from, po_rollup *to, int tier) {
    uint32_t i;
    if (!po_rollup_init(to, tier)) return 0;
    for (i = 0; i < from->n; i++) {
        const po_rpoint *s = &from->p[i];
        po_rpoint *b = po_rollup_bucket(to, s->t);
        if (!b) return 0;
        if (b->count == 0) { b->min = s->min; b->max = s->max; }
        else {
            if (s->min < b->min) b->min = s->min;
            if (s->max > b->max) b->max = s->max;
        }
        b->sum   += s->sum;
        b->count += s->count;
        b->last   = s->last;      /* the latest wins; buckets arrive in order */
        b->resets += s->resets;
    }
    return 1;
}

/* Answering an aggregate from a tier.
 *
 * Returns 1 with *out set, or 0 for an aggregate a rollup cannot honour - and
 * the caller reports that refusal rather than substituting something. */
static int po_rollup_agg(const po_rollup *r, int agg, double *out) {
    uint32_t i;
    double acc = 0;
    po_u64 n = 0;

    switch (agg) {
        case PO_AGG_COUNT:
            for (i = 0; i < r->n; i++) n += r->p[i].count;
            *out = (double)n;
            return 1;
        case PO_AGG_SUM:
            for (i = 0; i < r->n; i++) acc += r->p[i].sum;
            *out = acc;
            return 1;
        case PO_AGG_AVG:
            for (i = 0; i < r->n; i++) { acc += r->p[i].sum; n += r->p[i].count; }
            *out = n ? acc / (double)n : 0;
            return 1;
        case PO_AGG_MIN:
            for (i = 0; i < r->n; i++)
                if (i == 0 || r->p[i].min < acc) acc = r->p[i].min;
            *out = acc;
            return r->n > 0;
        case PO_AGG_MAX:
            for (i = 0; i < r->n; i++)
                if (i == 0 || r->p[i].max > acc) acc = r->p[i].max;
            *out = acc;
            return r->n > 0;
        case PO_AGG_P50: case PO_AGG_P90:
        case PO_AGG_P95: case PO_AGG_P99:
            /* See the header. Not approximated. */
            return 0;
        default:
            return 0;
    }
}

static const char *po_rollup_refusal(int agg) {
    switch (agg) {
        case PO_AGG_P50: case PO_AGG_P90:
        case PO_AGG_P95: case PO_AGG_P99:
            return "a percentile cannot be computed from downsampled data; "
                   "shorten the range to reach raw points, or record the "
                   "series as a histogram";
        default:
            return "that aggregate is not available from downsampled data";
    }
}

/* Does the range contain a counter reset? A rate over a rolled-up range must
 * know, and after retention this is the only place that remembers. */
static int po_rollup_resets(const po_rollup *r) {
    uint32_t i;
    int n = 0;
    for (i = 0; i < r->n; i++) n += r->p[i].resets;
    return n;
}

#endif /* PO_ROLLUP_H */
