/* po_rec.h - the one record shape.
 *
 * A span is not a metric point and a log line is neither, so three structs is
 * the obvious design. Taken, the query language then has three row shapes,
 * `where` has three implementations, and the cross-signal stages have to
 * convert between them at runtime. That is the shape most observability
 * stacks have, and it is exactly why they cannot express
 *
 *     metric ... | exemplars | traces | logs
 *
 * So: one record, and the signals are three views of it. A span is a record
 * with a duration and a trace id. A log line is a record with a body and a
 * severity. A metric point is a record with a value. The three storage
 * layouts differ in how they lay records OUT, not in what a record IS, and
 * the executor sees po_rec from all three.
 *
 * Fixed width, no pointers, no allocation. Variable-length data lives in a
 * per-batch arena and the record carries offsets into it, which is what makes
 * a memcpy of the record array into the WAL correct without a serialiser.
 */
#ifndef PO_REC_H
#define PO_REC_H

#include "punk_observe/po_compat.h"

#define PO_REC_VERSION 1

/* kind. The byte has room for PO_PROFILE and nothing in the struct forbids
 * it; that is the entire accommodation OTLP profiles get until the spec
 * settles, and it is deliberately not more. */
#define PO_METRIC   1
#define PO_LOG      2
#define PO_SPAN     3
/* #define PO_PROFILE 4  - reserved, not implemented */

/* flags */
#define PO_F_HAS_TRACE     0x0001  /* trace_id is present and non-zero      */
#define PO_F_HAS_PARENT    0x0002  /* parent_span_id is present             */
#define PO_F_MONOTONIC     0x0004  /* metric: the sum is monotonic          */
#define PO_F_CUMULATIVE    0x0008  /* metric: cumulative, else delta        */
#define PO_F_VALUE_IS_INT  0x0010  /* metric: as_int, not as_double         */
#define PO_F_CLAMPED_DUR   0x0020  /* span: end < start, clamped, counted   */
#define PO_F_TRUNCATED     0x0040  /* body or attributes hit a limit        */

/* span kind, in the high nibble of `aux`; OTLP SpanKind values. */
#define PO_SK_UNSPECIFIED 0
#define PO_SK_INTERNAL    1
#define PO_SK_SERVER      2
#define PO_SK_CLIENT      3
#define PO_SK_PRODUCER    4
#define PO_SK_CONSUMER    5

/* status, OTLP StatusCode. */
#define PO_ST_UNSET 0
#define PO_ST_OK    1
#define PO_ST_ERROR 2

/* Field order is chosen so that the struct packs the same on every ABI in the
 * smoker matrix: all 8-byte members first, then 4, then 2. t/0001-contracts.t
 * asserts sizeof and the absence of interior padding rather than trusting it. */
typedef struct {
    po_u64   t_unix_nano;      /* event time; a span's START time           */
    po_u64   series;           /* interned (name + label set); 0 until seal */
    po_u64   trace_id_hi;      /* 0 when absent                             */
    po_u64   trace_id_lo;
    po_u64   span_id;
    po_u64   parent_span_id;
    po_u64   dur_nano;         /* spans; 0 otherwise                        */
    double   value;            /* metric points; also the int, bit-cast     */

    uint32_t body_off;         /* arena: log body, span name, metric name   */
    uint32_t body_len;
    uint32_t attr_off;         /* arena: the sorted attribute block         */
    uint32_t attr_len;

    uint16_t severity;         /* OTLP SeverityNumber, the 24-point scale   */
    uint16_t flags;
    uint8_t  kind;             /* PO_METRIC | PO_LOG | PO_SPAN              */
    uint8_t  aux;              /* span kind low nibble, status high nibble  */
    uint16_t pad;              /* explicit, so sizeof is stable and stated  */
} po_rec;

#define PO_REC_SIZE 88

/* aux packing. Two 4-bit fields rather than two bytes, because the struct is
 * copied by the million and 88 bytes divides cleanly by 8. */
#define po_rec_span_kind(r)     ((r)->aux & 0x0F)
#define po_rec_status(r)        (((r)->aux >> 4) & 0x0F)
#define po_rec_set_aux(r, k, s) ((r)->aux = (uint8_t)(((k) & 0x0F) | (((s) & 0x0F) << 4)))

/* An all-zero trace id is invalid and OTLP says so. It arrives anyway, from a
 * misconfigured propagator, and a "trace" that collects every unparented span
 * from a broken deployment is a landmine in the UI. Rejected at ingest and
 * counted, never stored. */
#define po_trace_id_valid(hi, lo) ((hi) != 0 || (lo) != 0)

static void po_rec_zero(po_rec *r) { memset(r, 0, sizeof(*r)); }

/* The arena a batch's variable-length bytes live in. Records hold offsets
 * into it and never pointers, so the whole array survives being memcpy'd to
 * disk, and nothing dangles when the request body goes away. */
typedef struct {
    char  *base;
    size_t len;
    size_t cap;
} po_arena;

static int po_arena_init(po_arena *a, size_t hint) {
    a->base = (char *)malloc(hint ? hint : 4096);
    if (!a->base) { a->len = a->cap = 0; return 0; }
    a->len = 0; a->cap = hint ? hint : 4096;
    return 1;
}

static void po_arena_free(po_arena *a) {
    free(a->base); a->base = NULL; a->len = a->cap = 0;
}

/* Returns the offset, or PO_ARENA_ERR. Offsets are uint32_t in po_rec, so an
 * arena is capped at 4GB and the cap is enforced HERE rather than discovered
 * as a wrapped offset pointing at the wrong bytes. */
#define PO_ARENA_ERR 0xFFFFFFFFu

static uint32_t po_arena_put(po_arena *a, const char *p, size_t n) {
    size_t off = a->len;
    if (n > PO_ARENA_ERR || off + n >= PO_ARENA_ERR) return PO_ARENA_ERR;
    if (off + n > a->cap) {
        size_t want = a->cap * 2;
        char *nb;
        while (want < off + n) want *= 2;
        if (want >= PO_ARENA_ERR) return PO_ARENA_ERR;
        nb = (char *)realloc(a->base, want);
        if (!nb) return PO_ARENA_ERR;
        a->base = nb; a->cap = want;
    }
    if (n) memcpy(a->base + off, p, n);
    a->len = off + n;
    return (uint32_t)off;
}

#endif /* PO_REC_H */
