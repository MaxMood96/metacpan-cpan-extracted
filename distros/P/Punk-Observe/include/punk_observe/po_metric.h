/* po_metric.h - metric chunks, series metadata, exemplars.
 *
 * A chunk is the unit of DECOMPRESSION, which is what sets its size: closed
 * at 120 points or two hours, whichever comes first. Smaller means more
 * directory and worse ratios; larger means a query for one minute
 * decompresses ten. The chunk header carries the first timestamp and the
 * point count uncompressed, so the index can skip a chunk without entering
 * the bit stream at all.
 */
#ifndef PO_METRIC_H
#define PO_METRIC_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_gorilla.h"
#include "punk_observe/po_rec.h"

#define PO_CHUNK_POINTS 120
#define PO_CHUNK_SPAN   ((po_u64)2 * 3600 * 1000000000ULL)

/* Chunk flags */
#define PO_CH_INT       0x01    /* values are integers, not doubles      */
#define PO_CH_CUMULATIVE 0x02
#define PO_CH_MONOTONIC 0x04
#define PO_CH_RESET     0x08    /* a counter reset occurred inside       */

typedef struct {
    po_u64   t_first, t_last;
    uint32_t count;
    uint32_t bits;          /* the bit stream's length, so a truncated
                             * chunk fails rather than decoding garbage */
    uint16_t flags;
} po_chunk_hdr;

typedef struct {
    po_gor_w g;
    po_chunk_hdr h;
    po_u64  v_last;         /* for reset detection: the previous RAW value */
    int     resets;
    int     is_int;
} po_chunk_w;

static int po_chunk_w_init(po_chunk_w *c, int is_int, uint16_t flags) {
    memset(c, 0, sizeof(*c));
    c->is_int  = is_int;
    c->h.flags = flags | (is_int ? PO_CH_INT : 0);
    return po_gor_w_init(&c->g);
}

static void po_chunk_w_free(po_chunk_w *c) { po_gor_w_free(&c->g); }

static int po_chunk_full(const po_chunk_w *c, po_u64 t) {
    if (c->h.count >= PO_CHUNK_POINTS) return 1;
    if (c->h.count && t >= c->h.t_first + PO_CHUNK_SPAN) return 1;
    return 0;
}

/* A COUNTER RESET IS NOT A NEGATIVE RATE.
 *
 * A cumulative counter that goes backwards means the process restarted. The
 * detection happens HERE, at encode time, and not in the query - because
 * phase 10's rollups outlive the raw points, and a rate computed over a
 * rolled-up range with an undetected reset inside it is simply wrong with
 * nothing left to reveal it. */
static int po_chunk_add(po_chunk_w *c, po_u64 t, po_u64 bits) {
    if (c->h.count == 0) c->h.t_first = t;

    if ((c->h.flags & PO_CH_MONOTONIC) && c->h.count) {
        int went_back = c->is_int
            ? (bits < c->v_last)
            : (po_b2d(bits) < po_b2d(c->v_last));
        if (went_back) { c->h.flags |= PO_CH_RESET; c->resets++; }
    }

    po_gor_put(&c->g, t, bits);
    c->v_last  = bits;
    c->h.t_last = t;
    c->h.count++;
    c->h.bits = (uint32_t)c->g.bw.nbits;
    return !c->g.bw.err;
}

typedef struct {
    po_gor_r g;
    po_chunk_hdr h;
} po_chunk_r;

static void po_chunk_r_init(po_chunk_r *c, const po_chunk_hdr *h,
                            const void *bits) {
    memset(c, 0, sizeof(*c));
    c->h = *h;
    po_gor_r_init(&c->g, bits, h->bits, h->count);
}

static int po_chunk_next(po_chunk_r *c, po_u64 *t, po_u64 *bits) {
    return po_gor_next(&c->g, t, bits);
}

/* ---- exemplars ------------------------------------------------------------
 *
 * (value, timestamp, trace_id, span_id) attached to a point.
 *
 * NOT a nicety and not optional: this is the ENTIRE mechanism behind the
 * `| exemplars` stage, which is the cross-signal jump this project is being
 * built for. A metric store that drops exemplars can never answer "what
 * happened during that spike" without a human copying a trace id between
 * tabs, which is the thing every other self-hosted stack makes you do.
 */
typedef struct {
    po_u64 t;
    po_u64 value_bits;
    po_u64 trace_hi, trace_lo;
    po_u64 span_id;
} po_exemplar;

typedef struct {
    po_exemplar *e;
    uint32_t     n, cap;
} po_exemplars;

static int po_exemplars_init(po_exemplars *x) {
    memset(x, 0, sizeof(*x));
    x->cap = 8;
    x->e = (po_exemplar *)malloc(x->cap * sizeof(po_exemplar));
    return x->e != NULL;
}

static void po_exemplars_free(po_exemplars *x) {
    free(x->e); x->e = NULL; x->n = x->cap = 0;
}

static int po_exemplar_add(po_exemplars *x, const po_exemplar *src) {
    /* An exemplar with no trace id is useless: it points nowhere, and the
     * whole point of the record is the jump. Dropped rather than stored. */
    if (!po_trace_id_valid(src->trace_hi, src->trace_lo)) return 0;
    if (x->n == x->cap) {
        uint32_t want = x->cap * 2;
        po_exemplar *ne = (po_exemplar *)realloc(x->e, want * sizeof(po_exemplar));
        if (!ne) return 0;
        x->e = ne; x->cap = want;
    }
    x->e[x->n++] = *src;
    return 1;
}

#endif /* PO_METRIC_H */
