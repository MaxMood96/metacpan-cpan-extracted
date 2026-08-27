/* po_otlp_in.h - OTLP request messages to po_rec.
 *
 * The schema layer. po_pb_read.h knows the wire; this file knows what the
 * fields MEAN, and it learns the numbers from Punk::OpenTelemetry's
 * otel_proto.h by dependency rather than by copying. Two sources of truth for
 * a field number is the one thing that must not happen here: the client
 * writing field 9 and the server reading field 9 as something else produces
 * plausible wrong data, silently, with no error anywhere.
 *
 * All three signals reduce to the same po_rec, because that is what makes one
 * `where` work across all three and the cross-signal stages expressible.
 */
#ifndef PO_OTLP_IN_H
#define PO_OTLP_IN_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_pb_read.h"
#include "punk_observe/po_rec.h"
#include "punk_observe/po_attr.h"
#include "otel_proto.h"          /* the field numbers, from the SDK next door */

typedef struct {
    po_rec   *rec;
    size_t    n;
    size_t    cap;
    po_arena  arena;
    int       dropped_bad_trace;   /* all-zero trace ids, refused and counted */
    int       clamped_durations;   /* end < start, clamped and counted        */
    int       err;
} po_batch;

static int po_batch_init(po_batch *b, size_t hint) {
    memset(b, 0, sizeof(*b));
    b->cap = hint ? hint : 64;
    b->rec = (po_rec *)malloc(b->cap * sizeof(po_rec));
    if (!b->rec) return 0;
    if (!po_arena_init(&b->arena, 4096)) { free(b->rec); b->rec = NULL; return 0; }
    return 1;
}

static void po_batch_free(po_batch *b) {
    free(b->rec); b->rec = NULL;
    po_arena_free(&b->arena);
    b->n = b->cap = 0;
}

static po_rec *po_batch_next(po_batch *b) {
    if (b->n == b->cap) {
        size_t want = b->cap * 2;
        po_rec *nr = (po_rec *)realloc(b->rec, want * sizeof(po_rec));
        if (!nr) { b->err = 1; return NULL; }
        b->rec = nr; b->cap = want;
    }
    po_rec_zero(&b->rec[b->n]);
    return &b->rec[b->n++];
}

/* A trace or span id arrives as raw bytes: 16 for a trace, 8 for a span.
 * A wrong length is OMITTED rather than padded - padding invents an id that
 * collides with a real one. */
static void po_id16(const uint8_t *p, size_t n, po_u64 *hi, po_u64 *lo) {
    int i;
    *hi = *lo = 0;
    if (n != 16) return;
    for (i = 0; i < 8; i++) *hi = (*hi << 8) | p[i];
    for (i = 8; i < 16; i++) *lo = (*lo << 8) | p[i];
}

static po_u64 po_id8(const uint8_t *p, size_t n) {
    po_u64 v = 0; int i;
    if (n != 8) return 0;
    for (i = 0; i < 8; i++) v = (v << 8) | p[i];
    return v;
}

/* ---- temporality, and the trap otel_proto.h wrote down for this reader ----
 *
 * otel_proto.h:217-226 says it plainly: the OTLP enum is DELTA=1,
 * CUMULATIVE=2, the REVERSE of the SDK's internal constants. Its own
 * description of the consequence is why this lives in one function and is
 * tested directly - a backend that gets it wrong "accepts without complaint
 * and then draws completely wrongly".
 *
 * Temporality is not cosmetic. rate() over a delta sum is a division; over a
 * cumulative sum it is a difference that must handle counter resets. The flag
 * picks the algorithm. */
static int po_temporality_is_cumulative(po_u64 otlp_value) {
    return otlp_value == (po_u64)PB_TEMPORALITY_CUMULATIVE;
}

/* ---- traces -------------------------------------------------------------- */

static int po_span_read(po_pbr *r, po_batch *b, po_attrs *inherited) {
    po_rec *rec;
    po_attrs at;
    uint32_t f, w;
    const uint8_t *namep = NULL; size_t namen = 0;
    po_u64 t_start = 0, t_end = 0;
    po_u64 tr_hi = 0, tr_lo = 0, span = 0, parent = 0;
    int32_t kind = 0, status = 0;
    int have_trace = 0;

    at = *inherited;                  /* resource + scope attributes first */

    while (po_pbr_next(r, &f, &w)) {
        switch (f) {
            case PB_SPAN_TRACE_ID: {
                const uint8_t *p; size_t n;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_bytes(r, &p, &n)) return 0;
                po_id16(p, n, &tr_hi, &tr_lo); have_trace = 1;
                break;
            }
            case PB_SPAN_SPAN_ID: {
                const uint8_t *p; size_t n;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_bytes(r, &p, &n)) return 0;
                span = po_id8(p, n);
                break;
            }
            case PB_SPAN_PARENT_SPAN_ID: {
                const uint8_t *p; size_t n;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_bytes(r, &p, &n)) return 0;
                parent = po_id8(p, n);
                break;
            }
            case PB_SPAN_NAME:
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_bytes(r, &namep, &namen)) return 0;
                break;
            case PB_SPAN_KIND:
                if (w != PO_PB_VARINT) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_int32(r, &kind)) return 0;
                break;
            /* START and END are FIXED64, not varint. Reading one as a varint
             * produces garbage rather than an error, which is the worst kind
             * of wrong, so the wire type is checked rather than assumed. */
            case PB_SPAN_START_TIME:
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_fixed64(r, &t_start)) return 0;
                break;
            case PB_SPAN_END_TIME:
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_fixed64(r, &t_end)) return 0;
                break;
            case PB_SPAN_ATTRIBUTES:
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_attrs_read(r, &at)) return 0;
                break;
            case PB_SPAN_STATUS: {
                po_pbr st; uint32_t sf, sw;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_sub(r, &st)) return 0;
                while (po_pbr_next(&st, &sf, &sw)) {
                    if (sf == PB_STATUS_CODE && sw == PO_PB_VARINT) {
                        if (!po_pbr_int32(&st, &status)) { po_pbr_join(r, &st); return 0; }
                    }
                    else if (!po_pbr_skip(&st, sw)) { po_pbr_join(r, &st); return 0; }
                }
                po_pbr_join(r, &st);
                if (r->err) return 0;
                break;
            }
            default:
                if (!po_pbr_skip(r, w)) return 0;
        }
    }
    if (r->err) return 0;

    /* An all-zero trace id is invalid and OTLP says so. It arrives anyway,
     * from a misconfigured propagator, and a "trace" collecting every
     * unparented span from a broken deployment is a landmine in the UI. */
    if (have_trace && !po_trace_id_valid(tr_hi, tr_lo)) {
        b->dropped_bad_trace++;
        return 1;
    }

    if (!(rec = po_batch_next(b))) return 0;
    rec->kind        = PO_SPAN;
    rec->t_unix_nano = t_start;
    rec->trace_id_hi = tr_hi;
    rec->trace_id_lo = tr_lo;
    rec->span_id     = span;
    rec->parent_span_id = parent;
    if (have_trace)  rec->flags |= PO_F_HAS_TRACE;
    if (parent)      rec->flags |= PO_F_HAS_PARENT;

    /* end < start means the wall clock stepped. In a uint64_t that
     * subtraction is about 1.8e19, not a small negative number. */
    if (t_end >= t_start) rec->dur_nano = t_end - t_start;
    else { rec->dur_nano = 0; rec->flags |= PO_F_CLAMPED_DUR; b->clamped_durations++; }

    po_rec_set_aux(rec, (uint8_t)kind, (uint8_t)status);

    if (namep) {
        rec->body_off = po_arena_put(&b->arena, (const char *)namep, namen);
        if (rec->body_off == PO_ARENA_ERR) { b->err = 1; return 0; }
        rec->body_len = (uint32_t)namen;
    }
    rec->attr_off = po_attrs_encode(&at, &b->arena, &rec->attr_len);
    if (rec->attr_off == PO_ARENA_ERR) { b->err = 1; return 0; }
    if (at.dropped) rec->flags |= PO_F_TRUNCATED;
    return 1;
}

/* ---- logs ---------------------------------------------------------------- */

static int po_logrec_read(po_pbr *r, po_batch *b, po_attrs *inherited) {
    po_rec *rec;
    po_attrs at = *inherited;
    uint32_t f, w;
    const uint8_t *bodyp = NULL; size_t bodyn = 0;
    po_u64 t = 0, t_obs = 0, tr_hi = 0, tr_lo = 0, span = 0;
    int32_t sev = 0;
    int have_trace = 0;

    while (po_pbr_next(r, &f, &w)) {
        switch (f) {
            case PB_LOGRECORD_TIME:
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_fixed64(r, &t)) return 0;
                break;
            case PB_LOGRECORD_OBSERVED_TIME:
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_fixed64(r, &t_obs)) return 0;
                break;
            case PB_LOGRECORD_SEVERITY_NUMBER:
                if (w != PO_PB_VARINT) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_int32(r, &sev)) return 0;
                break;
            case PB_LOGRECORD_BODY: {
                /* The body is an AnyValue. A string body is the common case
                 * and is stored as the record's body; anything else is
                 * flattened into the attributes under "body", because a log
                 * record whose body is a map is real and dropping it is not
                 * an option. */
                po_pbr bv; uint32_t bf, bw;
                const uint8_t *bstart; size_t blen;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_sub(r, &bv)) return 0;
                bstart = bv.p;
                blen   = (size_t)(bv.end - bv.p);

                if (po_pbr_next(&bv, &bf, &bw)
                        && bf == PB_ANYVALUE_STRING && bw == PO_PB_BYTES) {
                    if (!po_pbr_bytes(&bv, &bodyp, &bodyn))
                        { po_pbr_join(r, &bv); return 0; }
                }
                else {
                    /* Not a plain string. Re-read from the start as a generic
                     * AnyValue under the key "body", so a structured body is
                     * preserved and searchable instead of dropped. */
                    po_pbr again;
                    po_pbr_init(&again, bstart, blen);
                    if (!po_attr_value(&again, &at, "body", 4, 0))
                        { po_pbr_join(r, &again); return 0; }
                }
                po_pbr_join(r, &bv);
                if (r->err) return 0;
                break;
            }
            case PB_LOGRECORD_ATTRIBUTES:
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_attrs_read(r, &at)) return 0;
                break;
            case PB_LOGRECORD_TRACE_ID: {
                const uint8_t *p; size_t n;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_bytes(r, &p, &n)) return 0;
                po_id16(p, n, &tr_hi, &tr_lo);
                have_trace = po_trace_id_valid(tr_hi, tr_lo);
                break;
            }
            case PB_LOGRECORD_SPAN_ID: {
                const uint8_t *p; size_t n;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_bytes(r, &p, &n)) return 0;
                span = po_id8(p, n);
                break;
            }
            default:
                if (!po_pbr_skip(r, w)) return 0;
        }
    }
    if (r->err) return 0;

    if (!(rec = po_batch_next(b))) return 0;
    rec->kind = PO_LOG;
    /* An absent time_unix_nano falls back to observed_time, which is what the
     * spec intends and what every collector does. A record with neither is
     * stamped at ingest by the caller, not here. */
    rec->t_unix_nano = t ? t : t_obs;
    rec->severity    = (uint16_t)(sev < 0 ? 0 : (sev > 24 ? 24 : sev));
    rec->trace_id_hi = tr_hi;
    rec->trace_id_lo = tr_lo;
    rec->span_id     = span;
    if (have_trace) rec->flags |= PO_F_HAS_TRACE;

    if (bodyp) {
        rec->body_off = po_arena_put(&b->arena, (const char *)bodyp, bodyn);
        if (rec->body_off == PO_ARENA_ERR) { b->err = 1; return 0; }
        rec->body_len = (uint32_t)bodyn;
    }
    rec->attr_off = po_attrs_encode(&at, &b->arena, &rec->attr_len);
    if (rec->attr_off == PO_ARENA_ERR) { b->err = 1; return 0; }
    if (at.dropped) rec->flags |= PO_F_TRUNCATED;
    return 1;
}

/* ---- metrics ------------------------------------------------------------- */

/* One NumberDataPoint. `flags` carries the temporality and monotonic bits
 * already resolved by the caller, because they live on the wrapper message
 * rather than on the point. */
/* ---- histograms, summaries and exponential histograms ---------------------
 *
 * A HISTOGRAM POINT IS NOT ONE VALUE, so it cannot be one record. It carries a
 * count, a sum, and a bucket array - and the whole reason anybody records one
 * is that those buckets let a percentile be computed EXACTLY over any range,
 * which is the promise the rollup tier makes and could not keep while this
 * decoder skipped them.
 *
 * So a point is EXPLODED into records that the existing series model already
 * knows how to store:
 *
 *     <name>_bucket  {le="0.005"}   cumulative count at or below that bound
 *     <name>_bucket  {le="+Inf"}    the total, which is also the count
 *     <name>_sum                    the sum of observations
 *     <name>_count                  how many there were
 *
 * That is the convention Prometheus made ordinary, and it is chosen here for a
 * structural reason rather than familiarity: every one of those is a plain
 * (timestamp, double) series, so histograms need no new chunk format, no new
 * index and no new merge rule. They get content-derived series ids, Gorilla
 * compression, the postings index and the rollup for free.
 *
 * The cost is honest and worth naming: N buckets is N series. A histogram with
 * fifty buckets and ten routes is five hundred series, which is exactly what
 * the cardinality cap exists to bound - and the cap counts them, so the
 * operator sees it rather than discovering it.
 */

/* One derived series from a histogram point: the name gains a suffix and,
 * for a bucket, one more attribute. */
static int po_hist_emit(po_batch *b, const po_attrs *base,
                        const uint8_t *namep, size_t namen,
                        const char *suffix, size_t suflen,
                        const char *lekey, const char *leval, size_t levlen,
                        double value, po_u64 t, uint16_t mflags) {
    po_rec *rec;
    po_attrs at = *base;
    char nm[PO_ATTR_KEYMAX];
    size_t nl;

    if (lekey) {
        po_attr *a = po_attrs_push(&at, lekey, strlen(lekey));
        /* BORROWED, like every other attribute value. The caller's buffer
         * outlives this call, and po_attrs_encode copies into the arena
         * before it goes anywhere. */
        if (a) {
            a->tag  = PO_AV_STRING;
            a->sp   = (const uint8_t *)leval;
            a->slen = levlen;
        }
    }

    if (!(rec = po_batch_next(b))) return 0;
    rec->kind        = PO_METRIC;
    rec->t_unix_nano = t;
    rec->flags       = mflags;
    rec->value       = value;

    nl = namen < sizeof(nm) - suflen - 1 ? namen : sizeof(nm) - suflen - 1;
    if (namep && nl) memcpy(nm, namep, nl); else nl = 0;
    memcpy(nm + nl, suffix, suflen);
    rec->body_off = po_arena_put(&b->arena, nm, nl + suflen);
    if (rec->body_off == PO_ARENA_ERR) { b->err = 1; return 0; }
    rec->body_len = (uint32_t)(nl + suflen);

    rec->attr_off = po_attrs_encode(&at, &b->arena, &rec->attr_len);
    if (rec->attr_off == PO_ARENA_ERR) { b->err = 1; return 0; }
    if (at.dropped) rec->flags |= PO_F_TRUNCATED;
    return 1;
}

/* A bound as text, for the `le` attribute.
 *
 * Hand-formatted for the reason po_svg.h is: %f in a Perl-flavoured formatter
 * reads an NV, and this string becomes part of a SERIES IDENTITY - two
 * spellings of the same bound are two series that never merge, so the
 * rendering has to be stable rather than merely readable. */
static size_t po_le_str(double v, char *out) {
    size_t n = 0;
    po_u64 whole, frac;
    int neg = 0;

    if (!(v == v)) { memcpy(out, "NaN", 3); return 3; }
    if (v > 1e18)  { memcpy(out, "+Inf", 4); return 4; }
    if (v < -1e18) { memcpy(out, "-Inf", 4); return 4; }
    if (v < 0) { neg = 1; v = -v; }

    whole = (po_u64)v;
    frac  = (po_u64)((v - (double)whole) * 1000000.0 + 0.5);
    if (frac >= 1000000) { whole++; frac -= 1000000; }

    if (neg) out[n++] = '-';
    if (!whole) out[n++] = '0';
    else {
        char t[24]; size_t k = 0;
        while (whole) { t[k++] = (char)('0' + (int)(whole % 10)); whole /= 10; }
        while (k) out[n++] = t[--k];
    }
    if (frac) {
        char t[8]; int k;
        out[n++] = '.';
        for (k = 5; k >= 0; k--) { t[k] = (char)('0' + (int)(frac % 10)); frac /= 10; }
        {   /* trailing zeroes are noise, and a differently-trimmed bound is a
             * different series id */
            int last = 5;
            while (last > 0 && t[last] == '0') last--;
            for (k = 0; k <= last; k++) out[n++] = t[k];
        }
    }
    return n;
}

#define PO_HIST_MAX_BUCKETS 256

static int po_hdp_read(po_pbr *r, po_batch *b, po_attrs *inherited,
                       const uint8_t *namep, size_t namen, uint16_t mflags) {
    po_attrs at = *inherited;
    uint32_t f, w;
    po_u64 t = 0, count = 0;
    double sum = 0, mn = 0, mx = 0;
    int have_sum = 0, have_min = 0, have_max = 0;
    po_u64 counts[PO_HIST_MAX_BUCKETS];
    double bounds[PO_HIST_MAX_BUCKETS];
    uint32_t ncounts = 0, nbounds = 0;
    uint32_t i;
    po_u64 cumulative = 0;

    while (po_pbr_next(r, &f, &w)) {
        switch (f) {
            case PB_HDP_TIME:
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_fixed64(r, &t)) return 0;
                break;
            case PB_HDP_COUNT:
                /* FIXED64, not a varint. `count` is one of the few integer
                 * fields OTLP declares fixed-width, and reading it as a
                 * varint skips it silently - the point still decodes, with a
                 * count of zero, so every percentile computed from it is
                 * divided by nothing.
                 *
                 * A varint is accepted too, because an encoder that wrote one
                 * meant a count and there is nothing to gain by losing it. */
                if (w == PO_PB_FIXED64) { if (!po_pbr_fixed64(r, &count)) return 0; }
                else if (w == PO_PB_VARINT) { if (!po_pbr_varint(r, &count)) return 0; }
                else if (!po_pbr_skip(r, w)) return 0;
                break;
            case PB_HDP_SUM:
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_double(r, &sum)) return 0;
                have_sum = 1;
                break;
            case PB_HDP_MIN:
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_double(r, &mn)) return 0;
                have_min = 1;
                break;
            case PB_HDP_MAX:
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_double(r, &mx)) return 0;
                have_max = 1;
                break;
            case PB_HDP_BUCKET_COUNTS: {
                /* Packed OR unpacked: proto3 says a repeated scalar may
                 * arrive either way, and a reader that assumes packed loses
                 * every bucket from an encoder that did not pack. */
                po_pb_packed it;
                if (!po_pb_packed_begin(r, w, &it)) { if (!po_pbr_skip(r, w)) return 0; break; }
                {
                    po_u64 v;
                    while (po_pb_packed_varint(r, &it, &v))
                        if (ncounts < PO_HIST_MAX_BUCKETS) counts[ncounts++] = v;
                }
                if (r->err) return 0;
                break;
            }
            case PB_HDP_EXPLICIT_BOUNDS: {
                po_pb_packed it;
                if (!po_pb_packed_begin(r, w, &it)) { if (!po_pbr_skip(r, w)) return 0; break; }
                {
                    double v;
                    while (po_pb_packed_double(r, &it, &v))
                        if (nbounds < PO_HIST_MAX_BUCKETS) bounds[nbounds++] = v;
                }
                if (r->err) return 0;
                break;
            }
            case PB_HDP_ATTRIBUTES:
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_attrs_read(r, &at)) return 0;
                break;
            default:
                if (!po_pbr_skip(r, w)) return 0;
        }
    }
    if (r->err) return 0;

    /* THE BUCKET ARRAY IS ONE LONGER THAN THE BOUNDS ARRAY - the last bucket
     * is everything above the highest bound. A point where that does not hold
     * is malformed, and half-decoding it would produce a histogram whose
     * percentiles are quietly wrong. */
    if (ncounts && ncounts != nbounds + 1) return 1;

    for (i = 0; i < ncounts; i++) {
        char le[32];
        size_t len;
        /* CUMULATIVE counts, not per-bucket. That is what makes a percentile
         * a search rather than a sum, and what lets two points merge. */
        cumulative += counts[i];
        len = i < nbounds ? po_le_str(bounds[i], le)
                          : (memcpy(le, "+Inf", 4), 4);
        if (!po_hist_emit(b, &at, namep, namen, "_bucket", 7,
                          "le", le, len, (double)cumulative, t, mflags))
            return 0;
    }

    if (have_sum && !po_hist_emit(b, &at, namep, namen, "_sum", 4,
                                  NULL, NULL, 0, sum, t, mflags)) return 0;
    if (!po_hist_emit(b, &at, namep, namen, "_count", 6,
                      NULL, NULL, 0, (double)count, t, mflags)) return 0;
    if (have_min && !po_hist_emit(b, &at, namep, namen, "_min", 4,
                                  NULL, NULL, 0, mn, t, mflags)) return 0;
    if (have_max && !po_hist_emit(b, &at, namep, namen, "_max", 4,
                                  NULL, NULL, 0, mx, t, mflags)) return 0;
    return 1;
}

static int po_ndp_read(po_pbr *r, po_batch *b, po_attrs *inherited,
                       const uint8_t *namep, size_t namen, uint16_t mflags) {
    po_rec *rec;
    po_attrs at = *inherited;
    uint32_t f, w;
    po_u64 t = 0;
    double dv = 0; po_u64 iv = 0;
    int is_int = 0, have_val = 0;

    while (po_pbr_next(r, &f, &w)) {
        switch (f) {
            case PB_NDP_TIME:
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_fixed64(r, &t)) return 0;
                break;
            /* as_double is fixed64, as_int is a VARINT (sfixed64 would be
             * fixed64; the schema says int64, so varint it is). A point
             * carries one or the other, never both, and real series switch
             * representation mid-stream. */
            case PB_NDP_AS_DOUBLE:
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_double(r, &dv)) return 0;
                is_int = 0; have_val = 1;
                break;
            case PB_NDP_AS_INT:
                if (w != PO_PB_VARINT) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_varint(r, &iv)) return 0;
                is_int = 1; have_val = 1;
                break;
            case PB_NDP_ATTRIBUTES:
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_attrs_read(r, &at)) return 0;
                break;
            default:
                if (!po_pbr_skip(r, w)) return 0;
        }
    }
    if (r->err) return 0;
    if (!have_val) return 1;              /* a point with no value is nothing */

    if (!(rec = po_batch_next(b))) return 0;
    rec->kind        = PO_METRIC;
    rec->t_unix_nano = t;
    rec->flags      |= mflags;
    if (is_int) {
        rec->flags |= PO_F_VALUE_IS_INT;
        /* The int is kept exactly, as a bit pattern in the double slot. A
         * cast to double loses integers above 2^53, and a counter that big
         * is exactly the one somebody is watching. */
        memcpy(&rec->value, &iv, 8);
    }
    else rec->value = dv;

    if (namep) {
        rec->body_off = po_arena_put(&b->arena, (const char *)namep, namen);
        if (rec->body_off == PO_ARENA_ERR) { b->err = 1; return 0; }
        rec->body_len = (uint32_t)namen;
    }
    rec->attr_off = po_attrs_encode(&at, &b->arena, &rec->attr_len);
    if (rec->attr_off == PO_ARENA_ERR) { b->err = 1; return 0; }
    if (at.dropped) rec->flags |= PO_F_TRUNCATED;
    return 1;
}

static int po_metric_read(po_pbr *r, po_batch *b, po_attrs *inherited) {
    uint32_t f, w;
    const uint8_t *namep = NULL; size_t namen = 0;
    /* The name precedes the data on the wire in practice, but nothing
     * guarantees it, so the points are collected after a full pass finds the
     * name. Two passes over one small message is cheaper than being wrong. */
    const uint8_t *save_p = r->p;
    const uint8_t *save_end = r->end;

    while (po_pbr_next(r, &f, &w)) {
        if (f == PB_METRIC_NAME && w == PO_PB_BYTES) {
            if (!po_pbr_bytes(r, &namep, &namen)) return 0;
        }
        else if (!po_pbr_skip(r, w)) return 0;
    }
    if (r->err) return 0;

    po_pbr_init(r, save_p, (size_t)(save_end - save_p));

    while (po_pbr_next(r, &f, &w)) {
        uint16_t mflags = 0;
        int is_sum = 0;
        switch (f) {
            case PB_METRIC_SUM: is_sum = 1; /* fall through */
            case PB_METRIC_GAUGE: {
                po_pbr d; uint32_t df, dw;
                po_u64 temporality = 0; po_u64 monotonic = 0;
                const uint8_t *dp_start;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_sub(r, &d)) return 0;
                dp_start = d.p;

                if (is_sum) {           /* the wrapper's own fields first */
                    while (po_pbr_next(&d, &df, &dw)) {
                        if (df == PB_SUM_TEMPORALITY && dw == PO_PB_VARINT) {
                            if (!po_pbr_varint(&d, &temporality)) { po_pbr_join(r,&d); return 0; }
                        }
                        else if (df == PB_SUM_IS_MONOTONIC && dw == PO_PB_VARINT) {
                            if (!po_pbr_varint(&d, &monotonic)) { po_pbr_join(r,&d); return 0; }
                        }
                        else if (!po_pbr_skip(&d, dw)) { po_pbr_join(r,&d); return 0; }
                    }
                    if (d.err) { po_pbr_join(r, &d); return 0; }
                    if (po_temporality_is_cumulative(temporality))
                        mflags |= PO_F_CUMULATIVE;
                    if (monotonic) mflags |= PO_F_MONOTONIC;
                    po_pbr_init(&d, dp_start, (size_t)(d.end - dp_start));
                }

                while (po_pbr_next(&d, &df, &dw)) {
                    if ((df == PB_SUM_DATA_POINTS || df == PB_GAUGE_DATA_POINTS)
                            && dw == PO_PB_BYTES) {
                        po_pbr pt;
                        if (!po_pbr_sub(&d, &pt)) { po_pbr_join(r,&d); return 0; }
                        if (!po_ndp_read(&pt, b, inherited, namep, namen, mflags))
                            { po_pbr_join(r,&d); return 0; }
                    }
                    else if (!po_pbr_skip(&d, dw)) { po_pbr_join(r,&d); return 0; }
                }
                po_pbr_join(r, &d);
                if (r->err) return 0;
                break;
            }
            case PB_METRIC_HISTOGRAM: {
                po_pbr d; uint32_t df, dw;
                po_u64 temporality = 0;
                const uint8_t *dp_start;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_sub(r, &d)) return 0;
                dp_start = d.p;

                while (po_pbr_next(&d, &df, &dw)) {
                    if (df == PB_HIST_TEMPORALITY && dw == PO_PB_VARINT) {
                        if (!po_pbr_varint(&d, &temporality)) { po_pbr_join(r,&d); return 0; }
                    }
                    else if (!po_pbr_skip(&d, dw)) { po_pbr_join(r,&d); return 0; }
                }
                if (d.err) { po_pbr_join(r, &d); return 0; }
                if (po_temporality_is_cumulative(temporality))
                    mflags |= PO_F_CUMULATIVE;
                /* A histogram's buckets are counts, and counts only go up
                 * within a point. Marking them monotonic is what lets rate()
                 * treat a cumulative histogram the way it treats a counter. */
                mflags |= PO_F_MONOTONIC;
                po_pbr_init(&d, dp_start, (size_t)(d.end - dp_start));

                while (po_pbr_next(&d, &df, &dw)) {
                    if (df == PB_HIST_DATA_POINTS && dw == PO_PB_BYTES) {
                        po_pbr pt;
                        if (!po_pbr_sub(&d, &pt)) { po_pbr_join(r,&d); return 0; }
                        if (!po_hdp_read(&pt, b, inherited, namep, namen, mflags))
                            { po_pbr_join(r,&d); return 0; }
                    }
                    else if (!po_pbr_skip(&d, dw)) { po_pbr_join(r,&d); return 0; }
                }
                po_pbr_join(r, &d);
                if (r->err) return 0;
                break;
            }
            default:
                /* Exponential histograms and summaries remain. An exponential
                 * histogram's buckets are base-2 rather than explicit, so the
                 * bounds have to be COMPUTED from a scale before they can
                 * become `le` labels; a summary carries pre-computed quantiles
                 * that cannot be merged across points at all, which makes it a
                 * different storage question rather than the same one.
                 *
                 * Skipped rather than half-decoded, and the skip still costs
                 * nothing. */
                if (!po_pbr_skip(r, w)) return 0;
        }
    }
    return !r->err;
}

/* ---- the three request messages ------------------------------------------ */

/* Each Export*ServiceRequest has one repeated field at number 1, and each
 * Resource* has resource at 1, scope* at 2. The three walks are the same
 * shape with different leaf readers, which is the whole reason one record
 * type was worth insisting on. */
typedef int (*po_leaf_fn)(po_pbr *, po_batch *, po_attrs *);

static int po_walk(po_pbr *r, po_batch *b, po_leaf_fn leaf,
                   uint32_t f_scope, uint32_t f_leaf) {
    uint32_t f, w;
    while (po_pbr_next(r, &f, &w)) {                  /* Resource* */
        if (f != 1 || w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; continue; }
        {
            po_pbr rs; uint32_t rf, rw;
            po_attrs res_attrs;
            po_attrs_init(&res_attrs);
            if (!po_pbr_sub(r, &rs)) return 0;

            /* resource attributes first: they are inherited by every record
             * below, which is what makes service.name a label on a span. */
            {
                po_pbr scan; uint32_t sf, sw;
                po_pbr_init(&scan, rs.p, (size_t)(rs.end - rs.p));
                while (po_pbr_next(&scan, &sf, &sw)) {
                    if (sf == 1 && sw == PO_PB_BYTES) {   /* Resource */
                        po_pbr res; uint32_t af, aw;
                        if (!po_pbr_sub(&scan, &res)) { po_pbr_join(r,&scan); return 0; }
                        while (po_pbr_next(&res, &af, &aw)) {
                            if (af == PB_RESOURCE_ATTRIBUTES && aw == PO_PB_BYTES) {
                                if (!po_attrs_read(&res, &res_attrs))
                                    { po_pbr_join(r,&res); return 0; }
                            }
                            else if (!po_pbr_skip(&res, aw)) { po_pbr_join(r,&res); return 0; }
                        }
                        po_pbr_join(&scan, &res);
                    }
                    else if (!po_pbr_skip(&scan, sw)) { po_pbr_join(r,&scan); return 0; }
                }
                if (scan.err) { po_pbr_join(r, &scan); return 0; }
            }

            while (po_pbr_next(&rs, &rf, &rw)) {
                if (rf == f_scope && rw == PO_PB_BYTES) {   /* Scope* */
                    po_pbr ss; uint32_t sf, sw;
                    if (!po_pbr_sub(&rs, &ss)) { po_pbr_join(r,&rs); return 0; }
                    while (po_pbr_next(&ss, &sf, &sw)) {
                        if (sf == f_leaf && sw == PO_PB_BYTES) {
                            po_pbr leafr;
                            if (!po_pbr_sub(&ss, &leafr)) { po_pbr_join(r,&ss); return 0; }
                            if (!leaf(&leafr, b, &res_attrs)) { po_pbr_join(r,&ss); return 0; }
                        }
                        else if (!po_pbr_skip(&ss, sw)) { po_pbr_join(r,&ss); return 0; }
                    }
                    po_pbr_join(&rs, &ss);
                    if (rs.err) { po_pbr_join(r, &rs); return 0; }
                }
                else if (!po_pbr_skip(&rs, rw)) { po_pbr_join(r,&rs); return 0; }
            }
            po_pbr_join(r, &rs);
            if (r->err) return 0;
        }
    }
    return !r->err;
}

static int po_otlp_traces(const void *buf, size_t len, po_batch *b) {
    po_pbr r; po_pbr_init(&r, buf, len);
    if (!po_walk(&r, b, po_span_read,
                 PB_RESOURCESPANS_SCOPE_SPANS, PB_SCOPESPANS_SPANS)) return 0;
    return 1;
}

static int po_otlp_logs(const void *buf, size_t len, po_batch *b) {
    po_pbr r; po_pbr_init(&r, buf, len);
    if (!po_walk(&r, b, po_logrec_read,
                 PB_RESOURCELOGS_SCOPE_LOGS, PB_SCOPELOGS_RECORDS)) return 0;
    return 1;
}

static int po_otlp_metrics(const void *buf, size_t len, po_batch *b) {
    po_pbr r; po_pbr_init(&r, buf, len);
    if (!po_walk(&r, b, po_metric_read,
                 PB_RESOURCEMETRICS_SCOPE_METRICS, PB_SCOPEMETRICS_METRICS)) return 0;
    return 1;
}

#endif /* PO_OTLP_IN_H */
