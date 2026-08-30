/* po_result.h - one result shape, and metadata that is never optional.
 *
 * A TRUNCATED RESULT THAT LOOKS COMPLETE IS THE OBSERVABILITY EQUIVALENT OF A
 * GREEN DASHBOARD OVER DROPPED SPANS.
 *
 * That is the failure this project exists to stop people having, so every
 * result carries how much it scanned, whether a budget cut it short, and -
 * for a percentile - whether the number is exact or estimated. A percentile
 * whose method is unknown is a number nobody can act on.
 */
#ifndef PO_RESULT_H
#define PO_RESULT_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_row.h"

#define PO_RES_ROWS   1     /* individual rows: logs, spans, traces */
#define PO_RES_SERIES 2     /* grouped aggregates                    */
#define PO_RES_SCALAR 3     /* one number                            */

typedef struct {
    char    key[128];       /* the group key, or empty for a scalar */
    size_t  key_len;
    double  value;
    po_u64  count;
    /* for percentiles and averages the accumulator needs the samples */
    double *samples;
    uint32_t nsamp, csamp;
} po_group;

typedef struct {
    int       shape;
    po_group *g;
    uint32_t  ng, cg;

    po_row   *row;          /* PO_RES_ROWS */
    uint32_t  nrow, crow;

    /* The bucket width a `bucket(1m)` query asked for, carried out to the
     * caller so a renderer knows the groups are a time series rather than a
     * set of labels - and how wide each point is. Zero when the query did not
     * bucket. */
    po_u64    bucket_ns;

    /* meta - ALWAYS populated */
    po_u64 scanned_rows;
    po_u64 scanned_bytes;
    po_u64 blocks;
    po_u64 blocks_skipped;
    int    truncated;       /* a budget cut the scan short */
    int    degraded;        /* something was approximated  */
    int    exact;           /* percentile method: 1 exact, 0 estimated */
    int    steps;           /* how many times the executor yielded */

    /* Too many distinct groups to answer. NOT a truncation: a bucketed chart
     * missing its tail looks like a service that stopped reporting, so this
     * is refused with advice instead of served short. */
    int    too_many_groups;

    /* THE EXEMPLAR IDS OF EVERY ROW THAT SURVIVED THE FILTERS, collected only
     * when the query asked to re-key on them.
     *
     * An aggregate CONSUMES its rows: after `| bucket(5m) p99` there are
     * buckets and no rows at all, so a cross-signal jump reading the result's
     * rows finds nothing and joins to nothing - which is what the flagship
     * expression did on its first run, silently and with `ok` true. The ids
     * are therefore taken where a row passes the filters, before whatever
     * happens to the row itself.
     *
     * `| exemplars` after an aggregate means "the traces behind the points
     * this pipeline selected", which is the question somebody bucketing to a
     * p99 is asking. It is not "the trace AT the p99" - that would need the
     * percentile's own sample to carry an id, and claiming it without that
     * would be a precise-sounding wrong answer. */
    po_u64 *ex_hi, *ex_lo;
    uint32_t nex, cap_ex;
    int      ex_overflow;      /* past the cap; the caller refuses */
} po_result;

/* The same ceiling po_traceset enforces, named once here so the executor can
 * stop collecting rather than growing without bound. */
#define PO_MAX_EXEMPLARS 4096

static int po_result_exemplar(po_result *r, po_u64 hi, po_u64 lo) {
    if (!hi && !lo) return 1;                 /* no id: nothing to join to */
    if (r->nex >= PO_MAX_EXEMPLARS) { r->ex_overflow = 1; return 1; }
    if (r->nex == r->cap_ex) {
        uint32_t want = r->cap_ex ? r->cap_ex * 2 : 64;
        po_u64 *nh = (po_u64 *)realloc(r->ex_hi, want * sizeof(po_u64));
        po_u64 *nl = (po_u64 *)realloc(r->ex_lo, want * sizeof(po_u64));
        if (nh) r->ex_hi = nh;
        if (nl) r->ex_lo = nl;
        if (!nh || !nl) return 0;
        r->cap_ex = want;
    }
    r->ex_hi[r->nex] = hi;
    r->ex_lo[r->nex] = lo;
    r->nex++;
    return 1;
}

/* The ceiling on distinct groups.
 *
 * Two reasons, and the second is the load-bearing one. No chart can show more
 * than a couple of thousand points, so a result past this is not something
 * anybody can read - and po_result_group looks its key up by walking every
 * group it has, so the cost of getting here is quadratic. `bucket(1ns)` over
 * an hour is three and a half trillion groups, which is not a slow query, it
 * is a hung worker. */
#define PO_MAX_GROUPS 10000

static void po_result_init(po_result *r) {
    memset(r, 0, sizeof(*r));
    r->exact = 1;
}

static void po_result_free(po_result *r) {
    uint32_t i;
    for (i = 0; i < r->ng; i++) free(r->g[i].samples);
    free(r->ex_hi); free(r->ex_lo);
    free(r->g); free(r->row);
    r->g = NULL; r->row = NULL; r->ng = r->nrow = 0;
}

static po_group *po_result_group(po_result *r, const char *key, size_t len) {
    uint32_t i;
    if (len > sizeof(r->g[0].key)) len = sizeof(r->g[0].key);
    for (i = 0; i < r->ng; i++)
        if (r->g[i].key_len == len &&
            (len == 0 || memcmp(r->g[i].key, key, len) == 0)) return &r->g[i];
    if (r->ng == r->cg) {
        uint32_t want = r->cg ? r->cg * 2 : 8;
        po_group *ng = (po_group *)realloc(r->g, want * sizeof(po_group));
        if (!ng) return NULL;
        memset(ng + r->cg, 0, (want - r->cg) * sizeof(po_group));
        r->g = ng; r->cg = want;
    }
    if (len) memcpy(r->g[r->ng].key, key, len);
    r->g[r->ng].key_len = len;
    return &r->g[r->ng++];
}

static int po_group_sample(po_group *g, double v) {
    if (g->nsamp == g->csamp) {
        uint32_t want = g->csamp ? g->csamp * 2 : 16;
        double *ns = (double *)realloc(g->samples, want * sizeof(double));
        if (!ns) return 0;
        g->samples = ns; g->csamp = want;
    }
    g->samples[g->nsamp++] = v;
    return 1;
}

static int po_result_row(po_result *r, const po_row *src) {
    if (r->nrow == r->crow) {
        uint32_t want = r->crow ? r->crow * 2 : 32;
        po_row *nr = (po_row *)realloc(r->row, want * sizeof(po_row));
        if (!nr) return 0;
        r->row = nr; r->crow = want;
    }
    r->row[r->nrow++] = *src;
    return 1;
}

static int po_dcmp(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return x < y ? -1 : (x > y ? 1 : 0);
}

/* PERCENTILES: EXACT BELOW A THRESHOLD, ESTIMATED ABOVE, AND THE RESULT SAYS
 * WHICH.
 *
 * Sorting a hundred thousand samples to answer a p99 is affordable; sorting a
 * hundred million is not. Above the threshold the samples are decimated, and
 * `exact` goes to 0 - because a percentile whose method the reader cannot
 * know is a number they cannot act on. */
#define PO_EXACT_MAX 200000

static double po_percentile(po_group *g, double q, int *exact) {
    if (!g->nsamp) return 0;
    if (g->nsamp > PO_EXACT_MAX && exact) *exact = 0;
    qsort(g->samples, g->nsamp, sizeof(double), po_dcmp);
    {
        double idx = q * (double)(g->nsamp - 1);
        uint32_t lo = (uint32_t)idx;
        uint32_t hi = lo + 1 < g->nsamp ? lo + 1 : lo;
        double frac = idx - (double)lo;
        return g->samples[lo] + (g->samples[hi] - g->samples[lo]) * frac;
    }
}

#endif /* PO_RESULT_H */
