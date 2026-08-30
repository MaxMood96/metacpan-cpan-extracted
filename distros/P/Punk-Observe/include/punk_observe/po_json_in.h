/* po_json_in.h - OTLP/JSON to the same po_rec.
 *
 * OTLP/JSON is a supported encoding, not a convenience, and it is NOT a naive
 * rendering of the protobuf tree. Punk::OpenTelemetry's otel_json.h:7-25
 * enumerates the four rules its ENCODER follows; this file reverses them, and
 * each one has a failure mode worth naming:
 *
 *   1. Keys are lowerCamelCase. `startTimeUnixNano`, not
 *      `start_time_unix_nano`. A payload with snake_case keys parses as a
 *      message with every field absent - accepted, stored, and empty.
 *   2. trace_id and span_id are HEX, not base64. proto3 maps `bytes` to
 *      base64 and OTLP explicitly overrides it for these two. This reader
 *      accepts BOTH and normalises to the same sixteen raw bytes, because a
 *      trace whose ids are spelled two ways silently splits in half and
 *      presents as data simply being missing.
 *   3. 64-bit integers are STRINGS. A nanosecond timestamp is ~1.8e18 and
 *      loses its last two digits as a JSON number. Read as a string here, and
 *      a number is accepted only where it cannot have lost anything.
 *   4. Enums are NAMES - `SPAN_KIND_SERVER`, not 2. Numbers are tolerated
 *      too, because real exporters emit them.
 *
 * The input is an already-parsed Perl structure from File::Raw::JSON. That is
 * deliberate and it follows the SDK's own reasoning about the same transport:
 * this is the debug path, not the hot one. The protobuf receiver is what runs
 * in production, and duplicating a JSON parser to save allocations on a path
 * nobody benchmarks would be the wrong trade. The WALK is still C, so no SV
 * is allocated per record.
 */
#ifndef PO_JSON_IN_H
#define PO_JSON_IN_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_rec.h"
#include "punk_observe/po_attr.h"
#include "punk_observe/po_otlp_in.h"

/* ---- small SV helpers ---------------------------------------------------- */

static SV *po_j_get(pTHX_ HV *h, const char *k) {
    SV **p = hv_fetch(h, k, (I32)strlen(k), 0);
    return (p && SvOK(*p)) ? *p : NULL;
}

static HV *po_j_hv(SV *sv) {
    if (!sv || !SvROK(sv) || SvTYPE(SvRV(sv)) != SVt_PVHV) return NULL;
    return (HV *)SvRV(sv);
}

static AV *po_j_av(SV *sv) {
    if (!sv || !SvROK(sv) || SvTYPE(SvRV(sv)) != SVt_PVAV) return NULL;
    return (AV *)SvRV(sv);
}

/* Rule 3. A string is parsed as a string; a numeric SV is trusted ONLY when
 * it is an integer slot, never an NV - taking SvUV of an NV-backed SV is
 * exactly the silent truncation the rule exists to prevent. */
static po_u64 po_j_u64(pTHX_ SV *sv) {
    po_u64 v = 0;
    if (!sv) return 0;
    if (po_sv_to_u64(aTHX_ sv, &v)) return v;
    return 0;
}

static IV po_j_iv(pTHX_ SV *sv) {
    if (!sv) return 0;
    if (SvIOK(sv)) return SvIV(sv);
    if (SvPOK(sv)) {
        STRLEN l; const char *p = SvPV(sv, l);
        return (IV)atol(p);
    }
    return 0;
}

/* Rule 2. Accept hex (the spec) or base64 (what hand-rolled clients send) and
 * normalise both to raw bytes. Returns the byte count written. */
static int po_j_hexval(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static size_t po_j_b64(const char *p, size_t n, uint8_t *out, size_t outmax) {
    static const char T[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    uint32_t acc = 0; int bits = 0; size_t o = 0; size_t i;
    for (i = 0; i < n; i++) {
        const char *q;
        if (p[i] == '=' || p[i] == '\n' || p[i] == '\r') continue;
        q = strchr(T, p[i]);
        if (!q) return 0;                    /* not base64 either */
        acc = (acc << 6) | (uint32_t)(q - T);
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            if (o >= outmax) return 0;
            out[o++] = (uint8_t)((acc >> bits) & 0xFF);
        }
    }
    return o;
}

static size_t po_j_id(pTHX_ SV *sv, uint8_t *out, size_t want) {
    STRLEN len; const char *p;
    size_t i;
    if (!sv) return 0;
    p = SvPV(sv, len);
    if (len == want * 2) {                   /* hex, the spec's spelling */
        int ok = 1;
        for (i = 0; i < len; i++) if (po_j_hexval(p[i]) < 0) { ok = 0; break; }
        if (ok) {
            for (i = 0; i < want; i++)
                out[i] = (uint8_t)((po_j_hexval(p[i * 2]) << 4)
                                 | po_j_hexval(p[i * 2 + 1]));
            return want;
        }
    }
    {   /* base64, which is what a hand-rolled client sends */
        size_t n = po_j_b64(p, len, out, want);
        if (n == want) return n;
    }
    return 0;                                /* wrong length: OMIT, never pad */
}

/* Rule 4. Accept the name or the number. */
static int po_j_enum(pTHX_ SV *sv, const char *const *names, int n) {
    STRLEN len; const char *p; int i;
    if (!sv) return 0;
    if (SvIOK(sv) && !SvPOK(sv)) return (int)SvIV(sv);
    p = SvPV(sv, len);
    for (i = 0; i < n; i++)
        if (names[i] && strlen(names[i]) == len && memcmp(p, names[i], len) == 0)
            return i;
    if (len && p[0] >= '0' && p[0] <= '9') return (int)atol(p);
    return 0;
}

static const char *const PO_J_KIND[] = {
    "SPAN_KIND_UNSPECIFIED", "SPAN_KIND_INTERNAL", "SPAN_KIND_SERVER",
    "SPAN_KIND_CLIENT", "SPAN_KIND_PRODUCER", "SPAN_KIND_CONSUMER"
};
static const char *const PO_J_STATUS[] = {
    "STATUS_CODE_UNSET", "STATUS_CODE_OK", "STATUS_CODE_ERROR"
};

/* ---- attributes ----------------------------------------------------------- */

static void po_j_value(pTHX_ SV *v, po_attrs *s, const char *key, size_t klen,
                       po_arena *ar, int depth);

/* One JSON AnyValue: { "stringValue": "x" } and friends. */
static void po_j_anyvalue(pTHX_ HV *h, po_attrs *s,
                          const char *key, size_t klen,
                          po_arena *ar, int depth) {
    SV *v;
    po_attr *a;

    /* a->sp BORROWS from the decoded SV, never from the arena.
     *
     * The arena reallocs as it grows, so a pointer into it dangles the moment
     * a later attribute is added - and the corruption would appear only in
     * batches large enough to trigger a realloc, which is to say in
     * production and not in a small test. The decoded Perl structure is alive
     * for the whole walk and its PV buffers are stable, exactly as the
     * protobuf path borrows from the stable request buffer.
     * po_attrs_encode does the one copy, at the end. */
    if ((v = po_j_get(aTHX_ h, "stringValue"))) {
        STRLEN l; const char *p = SvPV(v, l);
        if ((a = po_attrs_push(s, key, klen))) {
            a->tag = PO_AV_STRING;
            a->sp = (const uint8_t *)p;
            a->slen = (size_t)l;
        }
        return;
    }
    if ((v = po_j_get(aTHX_ h, "boolValue"))) {
        if ((a = po_attrs_push(s, key, klen)))
            { a->tag = PO_AV_BOOL; a->u = SvTRUE(v) ? 1 : 0; }
        return;
    }
    if ((v = po_j_get(aTHX_ h, "intValue"))) {
        if ((a = po_attrs_push(s, key, klen)))
            { a->tag = PO_AV_INT; a->u = po_j_u64(aTHX_ v); }
        return;
    }
    if ((v = po_j_get(aTHX_ h, "doubleValue"))) {
        if ((a = po_attrs_push(s, key, klen)))
            { a->tag = PO_AV_DOUBLE; a->d = SvNV(v); }
        return;
    }
    if ((v = po_j_get(aTHX_ h, "bytesValue"))) {
        STRLEN l; const char *p = SvPV(v, l);
        if ((a = po_attrs_push(s, key, klen))) {
            a->tag = PO_AV_BYTES;
            a->sp = (const uint8_t *)p;
            a->slen = (size_t)l;
        }
        return;
    }
    if ((v = po_j_get(aTHX_ h, "arrayValue"))) {
        HV *av_h = po_j_hv(v);
        AV *vals = av_h ? po_j_av(po_j_get(aTHX_ av_h, "values")) : NULL;
        SSize_t i, n;
        if (!vals || depth >= PO_ATTR_MAX_DEPTH) return;
        n = av_len(vals) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(vals, i, 0);
            char k[PO_ATTR_KEYMAX]; char num[16]; size_t nl = 0, kl;
            IV t = i;
            if (t == 0) num[nl++] = '0';
            else { char tmp[16]; size_t tn = 0;
                   while (t) { tmp[tn++] = (char)('0' + (int)(t % 10)); t /= 10; }
                   while (tn) num[nl++] = tmp[--tn]; }
            kl = po_attr_join(k, sizeof(k), key, klen, num, nl);
            if (!kl || !e) continue;
            po_j_value(aTHX_ *e, s, k, kl, ar, depth + 1);
        }
        return;
    }
    if ((v = po_j_get(aTHX_ h, "kvlistValue"))) {
        HV *kv_h = po_j_hv(v);
        AV *vals = kv_h ? po_j_av(po_j_get(aTHX_ kv_h, "values")) : NULL;
        SSize_t i, n;
        if (!vals || depth >= PO_ATTR_MAX_DEPTH) return;
        n = av_len(vals) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(vals, i, 0);
            HV *kv = e ? po_j_hv(*e) : NULL;
            SV *ks, *vs;
            char k[PO_ATTR_KEYMAX]; size_t kl;
            STRLEN sl; const char *sp;
            if (!kv) continue;
            ks = po_j_get(aTHX_ kv, "key");
            vs = po_j_get(aTHX_ kv, "value");
            if (!ks || !vs) continue;
            sp = SvPV(ks, sl);
            kl = po_attr_join(k, sizeof(k), key, klen, sp, (size_t)sl);
            if (!kl) continue;
            po_j_value(aTHX_ vs, s, k, kl, ar, depth + 1);
        }
        return;
    }
}

static void po_j_value(pTHX_ SV *v, po_attrs *s, const char *key, size_t klen,
                       po_arena *ar, int depth) {
    HV *h = po_j_hv(v);
    if (h) po_j_anyvalue(aTHX_ h, s, key, klen, ar, depth);
}

/* A JSON attributes array: [ { "key": "k", "value": {...} }, ... ] */
static void po_j_attrs(pTHX_ SV *sv, po_attrs *s, po_arena *ar) {
    AV *av = po_j_av(sv);
    SSize_t i, n;
    if (!av) return;
    n = av_len(av) + 1;
    for (i = 0; i < n; i++) {
        SV **e = av_fetch(av, i, 0);
        HV *kv = e ? po_j_hv(*e) : NULL;
        SV *k, *v;
        STRLEN kl; const char *kp;
        if (!kv) continue;
        k = po_j_get(aTHX_ kv, "key");
        v = po_j_get(aTHX_ kv, "value");
        if (!k || !v) continue;
        kp = SvPV(k, kl);
        po_j_value(aTHX_ v, s, kp, (size_t)kl, ar, 0);
    }
}

/* ---- the three signals ---------------------------------------------------- */

typedef void (*po_j_leaf)(pTHX_ HV *, po_batch *, po_attrs *);

static void po_j_span(pTHX_ HV *h, po_batch *b, po_attrs *inherited) {
    po_rec *rec;
    po_attrs at = *inherited;
    uint8_t tid[16], sid[8], pid[8];
    size_t tn, sn, pn;
    po_u64 t_start, t_end;
    SV *v;

    tn = po_j_id(aTHX_ po_j_get(aTHX_ h, "traceId"), tid, 16);
    sn = po_j_id(aTHX_ po_j_get(aTHX_ h, "spanId"),  sid, 8);
    pn = po_j_id(aTHX_ po_j_get(aTHX_ h, "parentSpanId"), pid, 8);

    t_start = po_j_u64(aTHX_ po_j_get(aTHX_ h, "startTimeUnixNano"));
    t_end   = po_j_u64(aTHX_ po_j_get(aTHX_ h, "endTimeUnixNano"));

    po_j_attrs(aTHX_ po_j_get(aTHX_ h, "attributes"), &at, &b->arena);

    if (!(rec = po_batch_next(b))) return;
    rec->kind = PO_SPAN;
    rec->t_unix_nano = t_start;

    if (tn == 16) {
        po_id16(tid, 16, &rec->trace_id_hi, &rec->trace_id_lo);
        if (!po_trace_id_valid(rec->trace_id_hi, rec->trace_id_lo)) {
            b->n--;                       /* un-take the record */
            b->dropped_bad_trace++;
            return;
        }
        rec->flags |= PO_F_HAS_TRACE;
    }
    if (sn == 8) rec->span_id = po_id8(sid, 8);
    if (pn == 8) { rec->parent_span_id = po_id8(pid, 8);
                   rec->flags |= PO_F_HAS_PARENT; }

    if (t_end >= t_start) rec->dur_nano = t_end - t_start;
    else { rec->dur_nano = 0; rec->flags |= PO_F_CLAMPED_DUR;
           b->clamped_durations++; }

    {
        int kind = po_j_enum(aTHX_ po_j_get(aTHX_ h, "kind"), PO_J_KIND, 6);
        int st = 0;
        HV *sh = po_j_hv(po_j_get(aTHX_ h, "status"));
        if (sh) st = po_j_enum(aTHX_ po_j_get(aTHX_ sh, "code"), PO_J_STATUS, 3);
        po_rec_set_aux(rec, (uint8_t)kind, (uint8_t)st);
    }

    if ((v = po_j_get(aTHX_ h, "name"))) {
        STRLEN l; const char *p = SvPV(v, l);
        rec->body_off = po_arena_put(&b->arena, p, (size_t)l);
        if (rec->body_off == PO_ARENA_ERR) { b->err = 1; return; }
        rec->body_len = (uint32_t)l;
    }
    rec->attr_off = po_attrs_encode(&at, &b->arena, &rec->attr_len);
    if (rec->attr_off == PO_ARENA_ERR) b->err = 1;
}

static void po_j_log(pTHX_ HV *h, po_batch *b, po_attrs *inherited) {
    po_rec *rec;
    po_attrs at = *inherited;
    uint8_t tid[16], sid[8];
    size_t tn, sn;
    po_u64 t, tobs;
    SV *v;

    tn = po_j_id(aTHX_ po_j_get(aTHX_ h, "traceId"), tid, 16);
    sn = po_j_id(aTHX_ po_j_get(aTHX_ h, "spanId"),  sid, 8);
    t    = po_j_u64(aTHX_ po_j_get(aTHX_ h, "timeUnixNano"));
    tobs = po_j_u64(aTHX_ po_j_get(aTHX_ h, "observedTimeUnixNano"));

    po_j_attrs(aTHX_ po_j_get(aTHX_ h, "attributes"), &at, &b->arena);

    if (!(rec = po_batch_next(b))) return;
    rec->kind = PO_LOG;
    rec->t_unix_nano = t ? t : tobs;
    {
        IV sev = po_j_iv(aTHX_ po_j_get(aTHX_ h, "severityNumber"));
        rec->severity = (uint16_t)(sev < 0 ? 0 : (sev > 24 ? 24 : sev));
    }
    if (tn == 16) {
        po_id16(tid, 16, &rec->trace_id_hi, &rec->trace_id_lo);
        if (po_trace_id_valid(rec->trace_id_hi, rec->trace_id_lo))
            rec->flags |= PO_F_HAS_TRACE;
    }
    if (sn == 8) rec->span_id = po_id8(sid, 8);

    if ((v = po_j_get(aTHX_ h, "body"))) {
        HV *bh = po_j_hv(v);
        SV *s = bh ? po_j_get(aTHX_ bh, "stringValue") : NULL;
        if (s) {
            STRLEN l; const char *p = SvPV(s, l);
            rec->body_off = po_arena_put(&b->arena, p, (size_t)l);
            if (rec->body_off == PO_ARENA_ERR) { b->err = 1; return; }
            rec->body_len = (uint32_t)l;
        }
        else if (bh) po_j_anyvalue(aTHX_ bh, &at, "body", 4, &b->arena, 0);
    }
    rec->attr_off = po_attrs_encode(&at, &b->arena, &rec->attr_len);
    if (rec->attr_off == PO_ARENA_ERR) b->err = 1;
}

/* The first exemplar carrying a trace id, out of a point's `exemplars` array.
 * The protobuf decoder's rule, in the other spelling: one exemplar reaches
 * the record because the record has one slot, and an exemplar with no trace
 * id points nowhere. See po_otlp_in.h for why this field is the whole
 * cross-signal jump. */
static void po_j_exemplar(pTHX_ SV *exs, po_rec *rec) {
    AV *av = po_j_av(exs);
    SSize_t i, n;
    if (!av) return;
    n = av_len(av) + 1;
    for (i = 0; i < n; i++) {
        SV **e = av_fetch(av, i, 0);
        HV *x = e ? po_j_hv(*e) : NULL;
        uint8_t tid[16], sid[8];
        size_t tn, sn;
        po_u64 hi = 0, lo = 0;
        if (!x) continue;
        tn = po_j_id(aTHX_ po_j_get(aTHX_ x, "traceId"), tid, 16);
        if (tn != 16) continue;
        po_id16(tid, tn, &hi, &lo);
        if (!po_trace_id_valid(hi, lo)) continue;
        sn = po_j_id(aTHX_ po_j_get(aTHX_ x, "spanId"), sid, 8);
        rec->trace_id_hi = hi;
        rec->trace_id_lo = lo;
        rec->span_id     = sn == 8 ? po_id8(sid, sn) : 0;
        return;
    }
}

static void po_j_points(pTHX_ SV *pts, po_batch *b, po_attrs *inherited,
                        const char *name, size_t namelen, uint16_t mflags) {
    AV *av = po_j_av(pts);
    SSize_t i, n;
    if (!av) return;
    n = av_len(av) + 1;
    for (i = 0; i < n; i++) {
        SV **e = av_fetch(av, i, 0);
        HV *p = e ? po_j_hv(*e) : NULL;
        po_attrs at = *inherited;
        po_rec *rec;
        SV *dv, *iv2;
        if (!p) continue;
        po_j_attrs(aTHX_ po_j_get(aTHX_ p, "attributes"), &at, &b->arena);

        dv  = po_j_get(aTHX_ p, "asDouble");
        iv2 = po_j_get(aTHX_ p, "asInt");
        if (!dv && !iv2) continue;

        if (!(rec = po_batch_next(b))) return;
        rec->kind = PO_METRIC;
        rec->t_unix_nano = po_j_u64(aTHX_ po_j_get(aTHX_ p, "timeUnixNano"));
        rec->flags |= mflags;
        if (iv2) {
            po_u64 u = po_j_u64(aTHX_ iv2);
            rec->flags |= PO_F_VALUE_IS_INT;
            memcpy(&rec->value, &u, 8);
        }
        else rec->value = SvNV(dv);

        po_j_exemplar(aTHX_ po_j_get(aTHX_ p, "exemplars"), rec);

        if (name) {
            rec->body_off = po_arena_put(&b->arena, name, namelen);
            if (rec->body_off == PO_ARENA_ERR) { b->err = 1; return; }
            rec->body_len = (uint32_t)namelen;
        }
        rec->attr_off = po_attrs_encode(&at, &b->arena, &rec->attr_len);
        if (rec->attr_off == PO_ARENA_ERR) { b->err = 1; return; }
    }
}

static void po_j_metric(pTHX_ HV *h, po_batch *b, po_attrs *inherited) {
    SV *nv = po_j_get(aTHX_ h, "name");
    STRLEN nl = 0;
    const char *np = nv ? SvPV(nv, nl) : NULL;
    HV *w;

    if ((w = po_j_hv(po_j_get(aTHX_ h, "sum")))) {
        uint16_t f = 0;
        SV *t = po_j_get(aTHX_ w, "aggregationTemporality");
        SV *m = po_j_get(aTHX_ w, "isMonotonic");
        /* Rule 4 plus the reversed-enum trap: OTLP names CUMULATIVE as
         * AGGREGATION_TEMPORALITY_CUMULATIVE = 2. Same map back as the
         * protobuf path, and the same one function decides. */
        static const char *const T[] = {
            "AGGREGATION_TEMPORALITY_UNSPECIFIED",
            "AGGREGATION_TEMPORALITY_DELTA",
            "AGGREGATION_TEMPORALITY_CUMULATIVE"
        };
        if (po_temporality_is_cumulative((po_u64)po_j_enum(aTHX_ t, T, 3)))
            f |= PO_F_CUMULATIVE;
        if (m && SvTRUE(m)) f |= PO_F_MONOTONIC;
        po_j_points(aTHX_ po_j_get(aTHX_ w, "dataPoints"), b, inherited, np, nl, f);
        return;
    }
    if ((w = po_j_hv(po_j_get(aTHX_ h, "gauge")))) {
        po_j_points(aTHX_ po_j_get(aTHX_ w, "dataPoints"), b, inherited, np, nl, 0);
        return;
    }
    /* histogram, exponentialHistogram, summary: phase 5. Skipped, not
     * half-decoded, exactly as the protobuf path skips them. */
}

/* ---- the walk ------------------------------------------------------------- */

static void po_j_walk(pTHX_ SV *top, po_batch *b, const char *f_resource_list,
                      const char *f_scope_list, const char *f_leaf_list,
                      po_j_leaf leaf) {
    HV *root = po_j_hv(top);
    AV *rl;
    SSize_t i, n;

    if (!root) return;
    rl = po_j_av(po_j_get(aTHX_ root, f_resource_list));
    if (!rl) return;
    n = av_len(rl) + 1;

    for (i = 0; i < n; i++) {
        SV **re = av_fetch(rl, i, 0);
        HV *rh = re ? po_j_hv(*re) : NULL;
        po_attrs res_attrs;
        AV *sl;
        SSize_t j, m;
        if (!rh) continue;

        po_attrs_init(&res_attrs);
        {
            HV *res = po_j_hv(po_j_get(aTHX_ rh, "resource"));
            if (res) po_j_attrs(aTHX_ po_j_get(aTHX_ res, "attributes"),
                                &res_attrs, &b->arena);
        }

        sl = po_j_av(po_j_get(aTHX_ rh, f_scope_list));
        if (!sl) continue;
        m = av_len(sl) + 1;
        for (j = 0; j < m; j++) {
            SV **se = av_fetch(sl, j, 0);
            HV *sh = se ? po_j_hv(*se) : NULL;
            AV *ll;
            SSize_t k, o;
            if (!sh) continue;
            ll = po_j_av(po_j_get(aTHX_ sh, f_leaf_list));
            if (!ll) continue;
            o = av_len(ll) + 1;
            for (k = 0; k < o; k++) {
                SV **le = av_fetch(ll, k, 0);
                HV *lh = le ? po_j_hv(*le) : NULL;
                if (lh) leaf(aTHX_ lh, b, &res_attrs);
            }
        }
    }
}

static void po_json_traces(pTHX_ SV *top, po_batch *b) {
    po_j_walk(aTHX_ top, b, "resourceSpans", "scopeSpans", "spans", po_j_span);
}
static void po_json_logs(pTHX_ SV *top, po_batch *b) {
    po_j_walk(aTHX_ top, b, "resourceLogs", "scopeLogs", "logRecords", po_j_log);
}
static void po_json_metrics(pTHX_ SV *top, po_batch *b) {
    po_j_walk(aTHX_ top, b, "resourceMetrics", "scopeMetrics", "metrics",
              po_j_metric);
}

#endif /* PO_JSON_IN_H */
