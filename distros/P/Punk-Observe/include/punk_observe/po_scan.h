/* po_scan.h - the pushdown: deciding what a query does NOT have to read.
 *
 * THE JOIN PHASE 9 COULD NOT MAKE.
 *
 * Phase 9's executor ran over rows somebody else had materialised, and its
 * `blocks_skipped` was always zero - not because nothing could be skipped,
 * but because there were no blocks yet to skip. Phase 10 gave the segment a
 * region table and phase 12 shipped without closing the gap. This is the
 * closure: the plan's predicates, turned into the question "can this segment,
 * this chunk, this block possibly hold a matching row", asked BEFORE anything
 * is mapped, decompressed or decoded.
 *
 * That ordering is the whole value. A bloom filter consulted after
 * decompressing the block has cost more than it saved, and phase 6's filter
 * has been sitting unconsulted since it was built.
 *
 * THE ASYMMETRY THAT GOVERNS EVERY TEST HERE.
 *
 * Skipping something that could have matched LOSES DATA, silently, and the
 * answer still looks complete. Reading something that turns out not to match
 * costs time and nothing else. So every predicate below is conservative:
 * when it cannot prove a block is irrelevant it reads it, and an expression
 * shape this file does not understand narrows nothing at all rather than
 * narrowing by guess.
 *
 * In particular an OR narrows NOTHING. `t > noon or service = "api"` still
 * admits every row outside the range, and treating either branch as a bound
 * would drop rows the query asked for.
 */
#ifndef PO_SCAN_H
#define PO_SCAN_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_query.h"
#include "punk_observe/po_expr.h"
#include "punk_observe/po_result.h"
#include "punk_observe/po_qexec.h"
#include "punk_observe/po_seg.h"
#include "punk_observe/po_segio.h"
#include "punk_observe/po_logidx.h"
#include "punk_observe/po_bloom.h"

/* ---- what the plan pushes down -------------------------------------------- */

typedef struct {
    po_u64 from, to;          /* the closed time range, in nanoseconds */
    int    time_bounded;      /* did anything actually narrow it?      */

    const char *search; size_t search_len;   /* for the trigram filter */

    /* the first equality on a label, which a stream or series directory can
     * answer without opening the payload */
    const char *eq_field; size_t eq_field_len;
    const char *eq_val;   size_t eq_val_len;
    int    have_eq;

    po_u64 min_dur;           /* `duration > ...` on traces */
    int    have_min_dur;
} po_pushdown;

static int po_field_is_time(const po_expr *e) {
    return (e->field_len == 1 && e->field[0] == 't')
        || (e->field_len == 4 && memcmp(e->field, "time", 4) == 0);
}

static int po_field_is_duration(const po_expr *e) {
    return e->field_len == 8 && memcmp(e->field, "duration", 8) == 0;
}

/* The numeric value of a comparison, as nanoseconds.
 *
 * A NUMBER arrives as a double and a DURATION as an exact po_u64. Rounding a
 * nanosecond timestamp through a double loses the low bits, so the exact one
 * is used exactly and only a genuine PO_V_NUMBER goes through the NV. */
static int po_expr_u64_value(const po_expr *e, po_u64 *out) {
    if (e->vkind == PO_V_DURATION || e->vkind == PO_V_SEVERITY) {
        *out = e->uval;
        return 1;
    }
    if (e->vkind == PO_V_NUMBER) {
        /* Clamped BEFORE the cast, both ends. Converting a double that does
         * not fit the destination integer type is undefined behaviour, not a
         * wrap, so a query saying `t > 1e30` must not be allowed to reach the
         * cast at all. */
        if (!(e->nval == e->nval)) return 0;          /* NaN narrows nothing */
        if (e->nval < 0) { *out = 0; return 1; }
        if (e->nval >= 1.8446744073709550e19) { *out = PO_U64_MAX; return 1; }
        *out = (po_u64)e->nval;
        return 1;
    }
    return 0;
}

static void po_range_narrow(po_pushdown *pd, int op, po_u64 v) {
    switch (op) {
        case PO_OP_GT:
            if (v == PO_U64_MAX) { pd->from = PO_U64_MAX; pd->to = 0; }
            else if (v + 1 > pd->from) pd->from = v + 1;
            pd->time_bounded = 1;
            break;
        case PO_OP_GE:
            if (v > pd->from) pd->from = v;
            pd->time_bounded = 1;
            break;
        case PO_OP_LT:
            if (v == 0) { pd->from = PO_U64_MAX; pd->to = 0; }
            else if (v - 1 < pd->to) pd->to = v - 1;
            pd->time_bounded = 1;
            break;
        case PO_OP_LE:
            if (v < pd->to) pd->to = v;
            pd->time_bounded = 1;
            break;
        case PO_OP_EQ:
            if (v > pd->from) pd->from = v;
            if (v < pd->to)   pd->to   = v;
            pd->time_bounded = 1;
            break;
        default:
            /* !=, =~, !~ narrow nothing: every one of them admits rows on
             * both sides of the value. */
            break;
    }
}

static void po_pushdown_walk(po_pushdown *pd, const po_expr *e) {
    if (!e) return;

    /* Only a conjunction narrows. An OR or a NOT is walked no further: see
     * the header comment - a bound taken from one arm of an OR would drop
     * rows the other arm asked for. */
    if (e->kind == PO_E_AND) {
        po_pushdown_walk(pd, e->a);
        po_pushdown_walk(pd, e->b);
        return;
    }
    if (e->kind != PO_E_CMP) return;

    if (po_field_is_time(e)) {
        po_u64 v;
        if (po_expr_u64_value(e, &v)) po_range_narrow(pd, e->op, v);
        return;
    }

    if (po_field_is_duration(e)) {
        po_u64 v;
        if ((e->op == PO_OP_GT || e->op == PO_OP_GE)
            && po_expr_u64_value(e, &v)) {
            if (!pd->have_min_dur || v > pd->min_dur) {
                pd->min_dur = (e->op == PO_OP_GT && v != PO_U64_MAX) ? v + 1 : v;
                pd->have_min_dur = 1;
            }
        }
        return;
    }

    if (e->op == PO_OP_EQ && e->vkind == PO_V_STRING && !pd->have_eq) {
        pd->eq_field     = e->field;
        pd->eq_field_len = e->field_len;
        pd->eq_val       = e->sval;
        pd->eq_val_len   = e->sval_len;
        pd->have_eq      = 1;
    }
}

static void po_pushdown_build(po_pushdown *pd, const po_plan *p) {
    memset(pd, 0, sizeof(*pd));
    pd->from = 0;
    pd->to   = PO_U64_MAX;
    if (!p) return;
    {   /* Each where is a conjunct, so a bound proven by ANY of them
         * narrows the read for all of them. */
        int i;
        for (i = 0; i < p->nwhere; i++) po_pushdown_walk(pd, p->wheres[i]);
    }
    pd->search     = p->search;
    pd->search_len = p->search_len;
}

/* An empty range is a range no row can be in: `t > 100 and t < 50`. Answering
 * it by reading nothing is correct, and saying so here keeps every caller
 * below from having to notice. */
static int po_pushdown_empty(const po_pushdown *pd) {
    return pd->from > pd->to;
}

/* ---- segment-level pruning ------------------------------------------------- */

/* Worth opening at all? The footer carries t_min/t_max, so this is answered
 * from 32 bytes rather than from the payload. */
static int po_scan_segment_wanted(const po_seg_r *s, const po_pushdown *pd,
                                  po_result *res) {
    int want;
    if (po_pushdown_empty(pd)) want = 0;
    else want = po_seg_overlaps(s, pd->from, pd->to);
    if (res) {
        res->blocks++;
        if (!want) res->blocks_skipped++;
    }
    return want;
}

/* ---- metrics ---------------------------------------------------------------
 *
 * A chunk carries its own first and last timestamp, so a range query reads
 * only the chunks that overlap it and never touches the bit streams of the
 * rest. */
static int po_scan_metric_chunks(const po_seg_r *s, const po_pushdown *pd,
                                 po_mchunk_ref *into, uint32_t max,
                                 po_result *res) {
    size_t len = 0;
    const char *p = po_seg_region_ptr(s, PO_RGN_MCHUNKS, &len);
    po_mchunk_ref *all;
    int n, i, keep = 0;

    if (!p) return 0;
    all = (po_mchunk_ref *)malloc(sizeof(po_mchunk_ref) * (max ? max : 1));
    if (!all) return -1;
    n = po_metric_open(p, len, all, max);
    if (n < 0) { free(all); return -1; }

    for (i = 0; i < n; i++) {
        int want = !po_pushdown_empty(pd)
                && all[i].h.t_first <= pd->to
                && all[i].h.t_last  >= pd->from;
        if (res) {
            res->blocks++;
            if (!want) res->blocks_skipped++;
        }
        if (want) into[keep++] = all[i];
    }
    free(all);
    return keep;
}

/* ---- logs ------------------------------------------------------------------
 *
 * Three filters in increasing cost order, and the order is the point: a
 * stream mismatch is a comparison, a time mismatch is two, and the bloom is
 * a handful of hashes - all of them before the block is inflated.
 *
 * A query shorter than a trigram cannot use the filter and MUST fall through
 * to reading the block. Answering "no match" from a filter that cannot see
 * the term is the one failure mode that loses log lines. */
static int po_scan_log_blocks(const po_seg_r *s, const po_pushdown *pd,
                              int have_stream, po_u64 stream,
                              po_lblock_ref *into, uint32_t max,
                              po_result *res, po_prune_stats *st) {
    size_t len = 0;
    const char *p = po_seg_region_ptr(s, PO_RGN_LOGBLOCKS, &len);
    po_lblock_ref *all;
    int n, i, keep = 0;

    if (!p) return 0;
    all = (po_lblock_ref *)malloc(sizeof(po_lblock_ref) * (max ? max : 1));
    if (!all) return -1;
    n = po_log_open(p, len, all, max);
    if (n < 0) { free(all); return -1; }

    for (i = 0; i < n; i++) {
        po_dir_ent e;
        int want;
        memset(&e, 0, sizeof(e));
        e.h = all[i].h;
        want = !po_pushdown_empty(pd)
            && po_block_candidate(&e, have_stream, stream, pd->from, pd->to,
                                  all[i].bloom, pd->search, pd->search_len, st);
        if (res) {
            res->blocks++;
            if (!want) res->blocks_skipped++;
        }
        if (want) into[keep++] = all[i];
    }
    free(all);
    return keep;
}

/* ---- traces ----------------------------------------------------------------
 *
 * Spans are one flat array rather than blocks, so the pruning that pays is at
 * the summary level: a `duration >` or a time range answers from the trace
 * summaries without touching a span. */
static int po_scan_trace_summaries(const po_seg_r *s, const po_pushdown *pd,
                                   const po_tsummary **into, uint32_t max,
                                   po_result *res) {
    size_t len = 0;
    const char *p = po_seg_region_ptr(s, PO_RGN_TRACESUM, &len);
    const po_tsummary *t;
    uint32_t n = 0, i;
    int keep = 0;

    if (!p) return 0;
    t = po_tsum_open(p, len, &n);
    if (!t) return -1;

    for (i = 0; i < n && (uint32_t)keep < max; i++) {
        /* A trace OVERLAPS the range when it starts before the end of it and
         * ends after the beginning: a slow request straddling the boundary is
         * exactly the one being looked for, and keying on start_ns alone
         * would drop it. */
        po_u64 end = t[i].start_ns + t[i].dur_ns;
        int want = !po_pushdown_empty(pd)
                && t[i].start_ns <= pd->to && end >= pd->from
                && (!pd->have_min_dur || t[i].dur_ns >= pd->min_dur);
        if (res) {
            res->blocks++;
            if (!want) res->blocks_skipped++;
        }
        if (want) into[keep++] = &t[i];
    }
    return keep;
}

#endif /* PO_SCAN_H */
