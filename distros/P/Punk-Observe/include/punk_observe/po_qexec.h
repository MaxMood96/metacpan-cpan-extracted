/* po_qexec.h - planning, refusing, and executing in steps.
 *
 * A QUERY THAT BLOCKS THE LOOP TAKES THE WHOLE WORKER WITH IT.
 *
 * A Hyperman worker holds hundreds of connections. A query that scans two
 * gigabytes synchronously stalls every one of them, and the operator's
 * experience is that the service froze because somebody opened a dashboard.
 *
 * So this is a RESUMABLE STATE MACHINE, not a function. po_qexec_step
 * processes at most `budget` rows and returns PO_Q_MORE; the caller drives it
 * from a zero-second timer so the event loop runs in between.
 */
#ifndef PO_QEXEC_H
#define PO_QEXEC_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_query.h"
#include "punk_observe/po_expr.h"
#include "punk_observe/po_result.h"

#define PO_Q_MORE 0
#define PO_Q_DONE 1
#define PO_Q_ERR  2

/* ---- planning --------------------------------------------------------------
 *
 * FOUR DECISIONS, AND THE FOURTH IS REFUSING.
 *
 * A refused query with an actionable message is a better product than a
 * thirty-second one, and far better than a timeout. So the planner estimates
 * what a query will cost and, over budget, says what to add rather than what
 * went wrong.
 */
typedef struct {
    po_u64 max_rows;        /* the scan budget; 0 = unlimited */
    po_u64 rows_available;  /* what the store says is in range */
} po_budget;

typedef struct {
    const po_query *q;

    /* pushed-down predicates, in evaluation order */
    const po_expr *where;
    const char    *search; size_t search_len;

    int  agg, has_agg;
    const char *by[8]; size_t by_len[8]; int nby;

    /* THE BUCKET IS JUST ANOTHER GROUPING DIMENSION.
     *
     * It is prepended to the group key rather than given a structure of its
     * own, so every aggregate composes with it for free - including the
     * percentiles, which need the samples of each bucket kept separately and
     * would otherwise need their whole reservoir story written a second time.
     *
     * BOUNDARIES ARE ALIGNED TO THE EPOCH, NOT TO THE QUERY.
     *
     * Aligning bucket 0 to the start of the window is the obvious choice and
     * the wrong one: panning a chart by thirty seconds would move every
     * boundary, so the same minute of traffic reports a different number
     * before and after, and two panels on one dashboard whose ranges differ
     * slightly disagree about the same data with nothing to explain it.
     *
     * At multiples of the window a bucket means the same span whoever asks,
     * which is the same reasoning block_start already uses for retention. It
     * also means the executor needs no window: the row's own t is enough. */
    po_u64 bucket_ns;           /* 0 when the query is not bucketed */
    int    bucket_rate;         /* divide by the window: rate(), not bucket() */
    po_u64 limit;
    po_u64 slowest;
    int  sort_desc;
    const char *sort_field; size_t sort_field_len;
    int  rekey;             /* the last re-keying stage seen */

    char err[256];
    int  refused;
} po_plan;

static void po_plan_refuse(po_plan *p, const char *why, const char *fix) {
    size_t n = 0, i;
    for (i = 0; why[i] && n < sizeof(p->err) - 1; i++) p->err[n++] = why[i];
    if (fix) {
        const char *sep = " - try ";
        for (i = 0; sep[i] && n < sizeof(p->err) - 1; i++) p->err[n++] = sep[i];
        for (i = 0; fix[i] && n < sizeof(p->err) - 1; i++) p->err[n++] = fix[i];
    }
    p->err[n] = '\0';
    p->refused = 1;
}

static int po_plan_build(po_plan *p, const po_query *q, const po_budget *b) {
    const po_stage *s;

    memset(p, 0, sizeof(*p));
    p->q = q;
    p->where = q->selector;      /* the selector is a leading where */

    for (s = q->stages; s; s = s->next) {
        switch (s->kind) {
            case PO_ST_WHERE:
                /* Several `where` stages: the planner keeps the first and the
                 * executor evaluates the rest in order. Kept simple because
                 * they are a conjunction either way. */
                if (!p->where) p->where = s->expr;
                break;
            case PO_ST_SEARCH:
                p->search = s->str; p->search_len = s->str_len;
                break;
            /* `by` IS ITS OWN STAGE, and the planner has to read it.
             *
             * The language offers two spellings of the same thing - a
             * trailing `count by service` and a separate `| by service |
             * count` - and only the first was ever collected, off the
             * aggregate's own field list. The second parsed cleanly, planned
             * to nothing, and returned ONE group with an empty key: the right
             * total, presented as though the grouping had been applied and
             * every row had happened to fall in the same bucket.
             *
             * A wrong answer that is the right shape, on the stage whose
             * whole purpose is to split the answer up. */
            case PO_ST_BY:
            case PO_ST_AGG:
            case PO_ST_BUCKET:
            case PO_ST_RATE: {
                int i;
                if (s->kind != PO_ST_BY) {
                    p->has_agg = 1;
                    if (s->kind == PO_ST_AGG) p->agg = s->agg;
                }
                /* THE WINDOW WAS PARSED AND THEN DROPPED ON THE FLOOR.
                 *
                 * `rate` reached here, set has_agg, collected its `by` fields
                 * and never once looked at s->dur - so `rate(5m) by status`
                 * was a plain count over the whole range, wearing the name of
                 * something time-binned. The grammar advertised it, the POD's
                 * own synopsis used it, and no test ever executed one. */
                if (s->kind == PO_ST_BUCKET || s->kind == PO_ST_RATE) {
                    p->bucket_ns   = s->dur;
                    p->bucket_rate = (s->kind == PO_ST_RATE);
                    /* Its own aggregate wins; otherwise count, but only if no
                     * other stage has named one. `| p95 | bucket(1m)` is the
                     * p95 per bucket, not a row count wearing its name. A
                     * later `| p95` overwrites this in its own turn. */
                    if (s->agg) p->agg = s->agg;
                    else if (!p->agg) p->agg = PO_AGG_COUNT;
                }
                for (i = 0; i < s->nfields && p->nby < 8; i++) {
                    p->by[p->nby] = s->fields[i];
                    p->by_len[p->nby] = s->field_lens[i];
                    p->nby++;
                }
                break;
            }
            case PO_ST_LIMIT:   p->limit = s->num; break;
            case PO_ST_SLOWEST: p->slowest = s->num; break;
            case PO_ST_SORT:
                p->sort_field = s->fields[0];
                p->sort_field_len = s->field_lens[0];
                p->sort_desc = s->desc;
                break;
            case PO_ST_EXEMPLARS:
            case PO_ST_TRACES:
            case PO_ST_LOGS:
            case PO_ST_SPANS:
                p->rekey = s->kind;
                break;
            default: break;
        }
    }

    /* A pattern the matcher cannot honour is refused, not approximated. */
    {
        const po_expr *bad = po_expr_bad_pattern(p->where);
        if (bad) {
            po_plan_refuse(p,
                "that pattern needs a full regular expression engine",
                "an anchored prefix like \"^api-\", a suffix, or a plain substring");
            return 0;
        }
    }

    /* THE COST REFUSAL. Over budget, say what to ADD. */
    if (b && b->max_rows && b->rows_available > b->max_rows) {
        if (!po_expr_time_bounded(p->where))
            po_plan_refuse(p, "this query would scan too much",
                           "narrowing the time range, as in | where t > ...");
        else if (!po_expr_selective(p->where))
            po_plan_refuse(p, "this query would scan too much",
                           "an equality filter, as in | where service = \"...\"");
        else
            po_plan_refuse(p, "this query would scan too much",
                           "a shorter time range or a narrower filter");
        return 0;
    }
    return 1;
}

/* ---- the resumable executor ----------------------------------------------- */

typedef struct {
    const po_plan *plan;
    const po_row  *rows;      /* the scan's input */
    po_u64         n;
    po_u64         i;         /* the cursor: THIS is what makes it resumable */
    po_u64         budget;    /* rows per step */
    po_u64         hard_max;  /* total rows before truncating */
    po_result     *res;
    int            done;
} po_qexec;

static void po_qexec_init(po_qexec *x, const po_plan *p, const po_row *rows,
                          po_u64 n, po_result *res, po_u64 budget,
                          po_u64 hard_max) {
    memset(x, 0, sizeof(*x));
    x->plan = p; x->rows = rows; x->n = n; x->res = res;
    x->budget = budget ? budget : 1024;
    x->hard_max = hard_max;
    res->shape = p->has_agg ? PO_RES_SERIES : PO_RES_ROWS;
    /* A BUCKETED QUERY IS NEVER A SCALAR, however few fields it groups by.
     * `log | bucket(1m)` has no `by` at all and is still a line over time;
     * collapsing it to one number because nby is zero would answer a chart
     * with a total. */
    if (p->has_agg && p->nby == 0 && !p->bucket_ns) res->shape = PO_RES_SCALAR;
    res->bucket_ns = p->bucket_ns;
}

/* Build the group key from the `by` fields of a row.
 *
 * A FIELD WITH NO STRING FORM IS STILL A FIELD. `severity`, `duration`,
 * `status` and `t` are numbers on the row, and po_row_str does not know about
 * them - so `by severity` produced an empty key for every row, which is one
 * bucket containing everything, labelled with nothing. The right total, split
 * the way somebody asked for, except not split at all.
 *
 * So a field the string accessor cannot answer is tried as a number and
 * rendered. Integral values print without a fraction, because "17" is the
 * severity and "17.0000" is a rendering artefact somebody would then have to
 * explain. */
static size_t po_group_key(const po_plan *p, const po_row *r,
                           char *out, size_t cap) {
    size_t n = 0;
    int i;

    /* The bucket goes FIRST, and under its own separator. The reader that
     * splits this back apart has to tell "the bucket, then the fields" from
     * "a first field that happens to contain a separator", and one delimiter
     * for both jobs cannot say which it is. */
    if (p->bucket_ns) {
        char buf[24];
        int len = snprintf(buf, sizeof(buf), "%llu",
                           (unsigned long long)(r->t / p->bucket_ns));
        int k;
        for (k = 0; k < len && n < cap; k++) out[n++] = buf[k];
        if (n < cap) out[n++] = '\x1e';
    }

    for (i = 0; i < p->nby; i++) {
        size_t vl = 0;
        const char *v = po_row_str(r, p->by[i], p->by_len[i], &vl);
        if (i && n < cap) out[n++] = '\x1f';
        if (v && vl) {
            size_t k;
            for (k = 0; k < vl && n < cap; k++) out[n++] = v[k];
            continue;
        }
        {
            double d = 0;
            char buf[40];
            int len;
            if (!po_row_num(r, p->by[i], p->by_len[i], &d)) continue;
            if (d == (double)(po_u64)d && d >= 0)
                len = snprintf(buf, sizeof(buf), "%llu",
                               (unsigned long long)(po_u64)d);
            else
                len = snprintf(buf, sizeof(buf), "%.6g", d);
            if (len > 0) {
                int k;
                for (k = 0; k < len && n < cap; k++) out[n++] = buf[k];
            }
        }
    }
    return n;
}

static int po_qexec_step(po_qexec *x) {
    po_u64 processed = 0;
    const po_plan *p = x->plan;

    if (x->done) return PO_Q_DONE;
    x->res->steps++;

    while (x->i < x->n && processed < x->budget) {
        const po_row *r = &x->rows[x->i++];
        processed++;
        x->res->scanned_rows++;
        x->res->scanned_bytes += (po_u64)(r->body_len + r->service_len + 64);

        if (p->where && !po_eval(p->where, r)) continue;

        if (p->search_len) {
            /* The bloom prunes blocks; here the survivor is matched EXACTLY,
             * case-folded to agree with how the filter was built. */
            if (!r->body || !po_memfind(r->body, r->body_len,
                                        p->search, p->search_len)) continue;
        }

        if (p->has_agg) {
            char key[128];
            size_t klen = po_group_key(p, r, key, sizeof(key));
            po_group *g = po_result_group(x->res, key, klen);
            double v = 0;
            if (!g) return PO_Q_ERR;
            /* Checked AFTER the lookup, so it fires only when a new group
             * took it over the line. Testing before would refuse a query that
             * has exactly the cap and whose remaining rows all land in groups
             * it already has. */
            if (x->res->ng > PO_MAX_GROUPS) {
                x->res->too_many_groups = 1;
                x->done = 1;
                break;
            }
            g->count++;
            switch (p->agg) {
                case PO_AGG_COUNT: g->value = (double)g->count; break;
                case PO_AGG_SUM: case PO_AGG_AVG:
                case PO_AGG_MIN: case PO_AGG_MAX:
                case PO_AGG_P50: case PO_AGG_P90:
                case PO_AGG_P95: case PO_AGG_P99: {
                    const char *f = "value"; size_t fl = 5;
                    if (r->kind == PO_SPAN) { f = "duration"; fl = 8; }
                    else if (r->kind == PO_LOG) { f = "severity"; fl = 8; }
                    if (po_row_num(r, f, fl, &v)) {
                        if (!po_group_sample(g, v)) return PO_Q_ERR;
                        if (p->agg == PO_AGG_SUM) g->value += v;
                        else if (p->agg == PO_AGG_MIN)
                            g->value = (g->count == 1 || v < g->value) ? v : g->value;
                        else if (p->agg == PO_AGG_MAX)
                            g->value = (g->count == 1 || v > g->value) ? v : g->value;
                    }
                    break;
                }
                case PO_AGG_DISTINCT: g->value = (double)x->res->ng; break;
                default: g->value = (double)g->count; break;
            }
        }
        else {
            if (!po_result_row(x->res, r)) return PO_Q_ERR;
        }

        /* THE HARD CAP. Over it the scan stops and `truncated` is set - the
         * partial answer is the correct PREFIX of the real one, and the
         * result says so rather than looking complete. */
        if (x->hard_max && x->res->scanned_rows >= x->hard_max) {
            x->res->truncated = 1;
            x->done = 1;
            break;
        }
    }

    if (x->i >= x->n) x->done = 1;
    if (!x->done) return PO_Q_MORE;

    /* ORDERING, and it happens HERE - before the limit is applied, which is
     * the whole point.
     *
     * `slowest 20` and `sort` were both recorded by the planner and then used
     * by nobody: `slowest` acted as a bare limit and `sort` did nothing at
     * all. Taking the first twenty of an unordered scan does not give the
     * slowest twenty, it gives whichever twenty the scan reached first - and
     * because the store hands rows over newest first, `slowest` returned the
     * NEWEST twenty while looking exactly like it had worked.
     *
     * A wrong answer that is the right SHAPE is the worst kind: nothing in
     * the result says it is not ordered, and the reader is looking at the
     * screen precisely because they want the extreme. */
    if (x->res->shape == PO_RES_ROWS && x->res->nrow > 1) {
        if (p->slowest) po_rows_sort_dur(x->res->row, x->res->nrow);
        else if (p->sort_field)
            po_rows_sort_field(x->res->row, x->res->nrow,
                               p->sort_field, p->sort_field_len, p->sort_desc);
    }

    /* finish: the aggregates that need every sample */
    if (p->has_agg) {
        uint32_t i;
        for (i = 0; i < x->res->ng; i++) {
            po_group *g = &x->res->g[i];
            switch (p->agg) {
                case PO_AGG_AVG: {
                    double s = 0; uint32_t k;
                    for (k = 0; k < g->nsamp; k++) s += g->samples[k];
                    g->value = g->nsamp ? s / g->nsamp : 0;
                    break;
                }
                case PO_AGG_P50: g->value = po_percentile(g, 0.50, &x->res->exact); break;
                case PO_AGG_P90: g->value = po_percentile(g, 0.90, &x->res->exact); break;
                case PO_AGG_P95: g->value = po_percentile(g, 0.95, &x->res->exact); break;
                case PO_AGG_P99: g->value = po_percentile(g, 0.99, &x->res->exact); break;
                default: break;
            }
        }

        /* RATE IS THE AGGREGATE DIVIDED BY THE SPAN, and it is done here
         * rather than per row because the aggregate is not final until the
         * loop above has run: dividing as we went would divide a running
         * count and then divide it again on the next row.
         *
         * Only count and sum are rates. A p95 per second is not a quantity -
         * it is a latency, and dividing it by three hundred would report a
         * service as getting faster because somebody widened the bucket.
         */
        if (p->bucket_rate
            && (p->agg == PO_AGG_COUNT || p->agg == PO_AGG_SUM)) {
            const double secs = (double)p->bucket_ns / 1e9;
            if (secs > 0) {
                uint32_t i;
                for (i = 0; i < x->res->ng; i++) x->res->g[i].value /= secs;
            }
        }
    }
    return PO_Q_DONE;
}

/* Run to completion, counting the yields. Production drives the steps from a
 * timer; this is for a caller that genuinely wants to block. */
static int po_qexec_run(po_qexec *x) {
    int s;
    do { s = po_qexec_step(x); } while (s == PO_Q_MORE);
    return s;
}

#endif /* PO_QEXEC_H */
