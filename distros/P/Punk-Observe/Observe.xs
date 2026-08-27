#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdlib.h>
#include <string.h>
#include <stddef.h>             /* offsetof, for the layout assertions */

/* The headers carry the whole contract; the XS below is a thin surface onto
 * them. Perl headers first, because po_compat.h uses SV, UV and pTHX. */
#include "punk_observe/po_compat.h"
#include "punk_observe/po_time.h"
#include "punk_observe/po_rec.h"
#include "punk_observe/po_store.h"
#include "punk_observe/po_pb_read.h"
#include "punk_observe/po_attr.h"
#include "punk_observe/po_otlp_in.h"
#include "punk_observe/po_crc32c.h"
#include "punk_observe/po_wal.h"
#include "punk_observe/po_json_in.h"
#include "punk_observe/po_ingest.h"
#include "punk_observe/po_hash.h"
#include "punk_observe/po_intern.h"
#include "punk_observe/po_labels.h"
#include "punk_observe/po_seg.h"
#include "punk_observe/po_shared.h"
#include "punk_observe/po_manifest.h"
#include "punk_observe/po_bits.h"
#include "punk_observe/po_gorilla.h"
#include "punk_observe/po_metric.h"
#include "punk_observe/po_tsidx.h"
#include "punk_observe/po_bloom.h"
#include "punk_observe/po_log.h"
#include "punk_observe/po_logidx.h"
#include "punk_observe/po_span.h"
#include "punk_observe/po_traceidx.h"
#include "punk_observe/po_tattr.h"
#include "punk_observe/po_sgraph.h"
#include "punk_observe/po_lex.h"
#include "punk_observe/po_query.h"
#include "punk_observe/po_parse.h"
#include "punk_observe/po_row.h"
#include "punk_observe/po_expr.h"
#include "punk_observe/po_result.h"
#include "punk_observe/po_qexec.h"
#include "punk_observe/po_merge.h"
#include "punk_observe/po_rollup.h"
#include "punk_observe/po_retain.h"
#include "punk_observe/po_segio.h"
#include "punk_observe/po_svg.h"
#include "punk_observe/po_flame.h"
#include "punk_observe/po_maplayout.h"
#include "punk_observe/po_scan.h"
#ifdef PO_HAVE_BUS
#  include "hyperman/hm_bus.h"
#endif
#include "punk_observe/po_live.h"
#include "punk_observe/po_alert.h"
#include "punk_observe/po_route.h"
#include "punk_observe/po_target.h"
#include "punk_observe/po_panel.h"
#include "punk_observe/po_tenant.h"
#include "punk_observe/po_key.h"
#include "punk_observe/po_limit.h"
#include "punk_observe/po_nsarith.h"
#include "punk_observe/po_storeio.h"
#include "punk_observe/po_view.h"
#include "punk_observe/po_plot.h"

#ifdef PO_HAVE_BUS
/* The fanout collector, and its cursor.
 *
 * Declared HERE rather than between XSUBs: xsubpp mangles a declaration that
 * appears between two of them, and this dist has paid for that twice.
 *
 * The cursor is file-scope on purpose. A subscriber's cursor belongs to the
 * process, and a forked worker that inherits one either replays what the
 * parent already saw or skips past what it has not - both of which present as
 * a broken tail rather than as a fork bug. po_live_cursor_reset() is what a
 * post-fork hook calls. */
typedef struct { AV *av; const char *t; size_t tl; } po_live_ud;

static po_u64 po_live_cursor = 0, po_live_gaps = 0;

/* A post-fork reset starts at NOW, not at zero.
 *
 * Zero means "replay the whole ring", which is the opposite of what a freshly
 * forked worker wants: it would re-deliver every line the parent already
 * forwarded. The bus makes the same choice for its own dispatch cursor
 * (hm_bus_reset_cursors), and for the same reason - a cursor is a position in
 * a stream this process has not been reading. */
static void po_live_cursor_reset(void) {
    po_live_cursor = (po_u64)hm_bus_seq();
    po_live_gaps   = 0;
}

static void po_live_collect(void *ud, uint64_t seq,
                            const char *topic, uint32_t tlen,
                            const char *payload, uint32_t plen) {
    po_live_ud *u = (po_live_ud *)ud;
    dTHX;
    (void)seq;
    /* A fanout subscriber sees every topic, so the filter is here. A tail
     * that forwarded another tenant's topic would be the tenancy boundary
     * failing open. */
    if (u->tl != (size_t)tlen || memcmp(u->t, topic, tlen) != 0) return;
    av_push(u->av, newSVpvn(payload, plen));
}
#endif

/* A resolver's answer, borrowed. The seam takes a callback rather than a
 * value so that the constant case and the host-callback case go through ONE
 * validation, and this is the shim that lets an XSUB supply the second. */
typedef struct { const char *p; size_t len; } po_tn_sv;

static int po_tn_cb(void *ud, const char **out, size_t *len) {
    po_tn_sv *s = (po_tn_sv *)ud;
    if (!s->p) return 0;
    *out = s->p;
    *len = s->len;
    return 1;
}

/* The service name out of a record's attribute block, WITHOUT building a
 * hash for the whole thing.
 *
 * Summarising a segment reads one attribute per record and ignores the rest,
 * so decoding all of them into a Perl hash - which is what the Perl this
 * replaced did, by way of po_rec_hv - allocated an SV per attribute per
 * record to throw every one of them away. The block is sorted, so this can
 * also stop as soon as it is past where the key would be. */
static void po_rec_service(const po_rec *rec, const po_arena *ar,
                           const char **out, size_t *out_len) {
    const unsigned char *p, *e;
    po_u64 n = 0;
    int sh = 0;
    static const char KEY[] = "service.name";
    const size_t KEYLEN = sizeof(KEY) - 1;

    *out = NULL; *out_len = 0;
    if (!rec->attr_len) return;

    p = (const unsigned char *)ar->base + rec->attr_off;
    e = p + rec->attr_len;
    while (p < e) { unsigned char c = *p++; n |= (po_u64)(c & 0x7F) << sh;
                    if (!(c & 0x80)) break; sh += 7; }

    while (n-- && p < e) {
        po_u64 kl = 0;
        unsigned char tag;
        const char *kp;
        sh = 0;
        while (p < e) { unsigned char c = *p++; kl |= (po_u64)(c & 0x7F) << sh;
                        if (!(c & 0x80)) break; sh += 7; }
        if ((po_u64)(e - p) < kl) return;
        kp = (const char *)p;
        p += kl;
        if (p >= e) return;
        tag = *p++;

        {
            int is_key = (kl == KEYLEN && memcmp(kp, KEY, KEYLEN) == 0);
            switch (tag) {
                case PO_AV_STRING: case PO_AV_BYTES: case PO_AV_NESTED: {
                    po_u64 vl = 0;
                    sh = 0;
                    while (p < e) { unsigned char c = *p++;
                                    vl |= (po_u64)(c & 0x7F) << sh;
                                    if (!(c & 0x80)) break; sh += 7; }
                    if ((po_u64)(e - p) < vl) return;
                    if (is_key) { *out = (const char *)p; *out_len = (size_t)vl; return; }
                    p += vl;
                    break;
                }
                case PO_AV_DOUBLE:
                    if ((size_t)(e - p) < 8) return;
                    p += 8;
                    break;
                default:
                    /* An int or a bool: EIGHT FIXED BYTES, the same as a
                     * double, because that is what po_attrs_encode writes.
                     *
                     * This skipped a varint instead, and the effect was not a
                     * wrong integer - it was that the walk lost its place.
                     * One byte consumed where eight were written leaves the
                     * cursor inside the value, so every key after it is read
                     * out of the middle of something, `service.name` never
                     * matches, and every row renders as "unknown". The block
                     * is sorted, so a single `process.pid` was enough to hide
                     * every service name in the store. */
                    if ((size_t)(e - p) < 8) return;
                    p += 8;
                    break;
            }
        }
    }
}

/* ---- the sidecar, read and written in C ---------------------------------- */

/* The scalar counters out of a sidecar, WITHOUT building a Perl hash for the
 * whole thing.
 *
 * `stats` wants eight integers and the service table; parsing the file into a
 * hash of SVs to add them up allocates a few dozen SVs per segment and throws
 * every one away. On a store with a thousand segments that is the difference
 * between a status page and a pause.
 *
 * The service counts DO go into an HV, because merging them across segments is
 * the answer rather than a step towards it. */
typedef struct {
    po_u64 records, logs, spans, metrics, errors, traces;
} po_idx_nums;

static int po_idx_num_field(const char *f, size_t fl, const char *want) {
    size_t wl = strlen(want);
    return fl == wl && memcmp(f, want, wl) == 0;
}

static int po_index_nums(const char *path, po_idx_nums *out, HV *svc) {
    size_t len = 0;
    char *buf = po_slurp(path, &len);
    char *p, *end;
    dTHX;

    if (!buf) return 0;
    memset(out, 0, sizeof(*out));

    p = buf; end = buf + len;
    while (p < end) {
        char *nl = memchr(p, '\n', (size_t)(end - p));
        char *line = p;
        size_t llen = nl ? (size_t)(nl - p) : (size_t)(end - p);
        char *f[8];
        size_t fl[8];
        int nf = 0;
        size_t i, start = 0;

        p = nl ? nl + 1 : end;
        if (!llen) continue;

        for (i = 0; i <= llen && nf < 8; i++) {
            if (i == llen || line[i] == '\t') {
                f[nf] = line + start; fl[nf] = i - start; nf++;
                start = i + 1;
            }
        }
        if (nf < 2) continue;

        if (po_idx_num_field(f[0], fl[0], "svc") && nf >= 3 && svc) {
            char key[512];
            size_t kn = po_idx_unesc(f[1], fl[1], key, sizeof(key));
            SV **slot = hv_fetch(svc, key, (I32)kn, 1);
            if (slot) {
                IV had = SvOK(*slot) ? SvIV(*slot) : 0;
                sv_setiv(*slot, had + (IV)atol(f[2]));
            }
            continue;
        }

        {
            po_u64 v = (po_u64)strtoul(f[1], NULL, 10);
            if      (po_idx_num_field(f[0], fl[0], "records")) out->records = v;
            else if (po_idx_num_field(f[0], fl[0], "logs"))    out->logs    = v;
            else if (po_idx_num_field(f[0], fl[0], "spans"))   out->spans   = v;
            else if (po_idx_num_field(f[0], fl[0], "metrics")) out->metrics = v;
            else if (po_idx_num_field(f[0], fl[0], "errors"))  out->errors  = v;
            else if (po_idx_num_field(f[0], fl[0], "traces"))  out->traces  = v;
        }
    }
    free(buf);
    return 1;
}

/* The same figures for a log that has NOT been sealed, counted from the
 * frames themselves because there is no sidecar to read them from.
 *
 * WITHOUT THIS THE STATUS PAGE READS ZERO ON A WORKING STORE. It counted
 * sealed segments only, and a live log contributed nothing but a tally of how
 * many live logs there were - so a fresh receiver that had accepted ten
 * thousand records but not yet passed its seal threshold reported no records,
 * no services and no traces, while every other screen showed the data. A
 * number that is late is a number that is wrong, and this one was wrong in
 * the direction that reads as "nothing is arriving".
 *
 * Distinct traces are NOT counted here. That needs the span set assembled,
 * which is a scan rather than a tally, and the status page is a page people
 * leave open.
 */
static int po_wal_nums(const char *path, po_idx_nums *out, HV *svc) {
    size_t len = 0;
    char *buf = po_slurp(path, &len);
    po_wal_replay rp;
    size_t off = 0;
    dTHX;

    if (!buf) return 0;
    memset(out, 0, sizeof(*out));
    po_wal_replay_buf(buf, len, &rp, NULL, NULL);

    for (;;) {
        uint32_t magic, frame_len, n_recs, arena_len;
        uint16_t flags, version;
        const char *h;
        const po_rec *recs;
        po_arena view;
        size_t i;

        if (len - off < PO_WAL_HDR) break;
        h = buf + off;
        memcpy(&magic, h, 4); magic = po_le32(magic);
        if (magic != PO_WAL_MAGIC) break;
        memcpy(&frame_len, h + 4, 4);  frame_len = po_le32(frame_len);
        memcpy(&n_recs,    h + 8, 4);  n_recs    = po_le32(n_recs);
        memcpy(&arena_len, h + 12, 4); arena_len = po_le32(arena_len);
        flags   = (uint16_t)((unsigned char)h[36] | ((unsigned char)h[37] << 8));
        version = (uint16_t)((unsigned char)h[38] | ((unsigned char)h[39] << 8));
        if (version != PO_WAL_VERSION) break;
        if (flags & PO_WAL_F_SEALED) break;
        if (len - off - PO_WAL_HDR < (size_t)frame_len) break;
        if (off + PO_WAL_HDR + frame_len > rp.bytes_ok) break;

        recs = (const po_rec *)(h + PO_WAL_HDR);
        view.base = (char *)(h + PO_WAL_HDR + (size_t)n_recs * sizeof(po_rec));
        view.len  = (size_t)arena_len;
        view.cap  = (size_t)arena_len;

        for (i = 0; i < n_recs; i++) {
            const po_rec *r = &recs[i];
            const char *service = NULL;
            size_t svc_len = 0;

            out->records++;
            if      (r->kind == PO_LOG)    out->logs++;
            else if (r->kind == PO_METRIC) out->metrics++;
            else if (r->kind == PO_SPAN) {
                out->spans++;
                if (po_rec_status(r) == 2) out->errors++;
            }

            if (!svc) continue;
            po_rec_service(r, &view, &service, &svc_len);
            if (!service || !svc_len) { service = "unknown"; svc_len = 7; }
            {
                SV **slot = hv_fetch(svc, service, (I32)svc_len, 1);
                if (slot) sv_setiv(*slot, (SvOK(*slot) ? SvIV(*slot) : 0) + 1);
            }
        }
        off += PO_WAL_HDR + frame_len;
    }
    free(buf);
    return 1;
}

/* Just the time span out of a sidecar, for the skip that happens before a
 * segment is opened at all. */
static int po_index_span(const char *path, po_u64 *t_min, po_u64 *t_max,
                         int *seen) {
    size_t len = 0;
    char *buf = po_slurp(path, &len);
    char *p, *end;
    int got = 0;

    *seen = 0;
    if (!buf) return 0;
    p = buf; end = buf + len;
    while (p < end) {
        char *nl = memchr(p, '\n', (size_t)(end - p));
        size_t ll = nl ? (size_t)(nl - p) : (size_t)(end - p);
        if (ll > 6 && memcmp(p, "t_min\t", 6) == 0) {
            *t_min = (po_u64)strtoull(p + 6, NULL, 10); got |= 1;
        }
        else if (ll > 6 && memcmp(p, "t_max\t", 6) == 0) {
            *t_max = (po_u64)strtoull(p + 6, NULL, 10); got |= 2;
        }
        p = nl ? nl + 1 : end;
    }
    free(buf);
    *seen = (got == 3);
    return 1;
}

static SV *po_index_read_sv(pTHX_ const char *path) {
    size_t len = 0;
    char *buf = po_slurp(path, &len);
    HV *s;
    HV *sev, *svc;
    AV *edges;
    char *p, *end;

    if (!buf) return newSV(0);
    s = newHV();
    sev = newHV(); svc = newHV(); edges = newAV();

    p = buf; end = buf + len;
    while (p < end) {
        char *nl = memchr(p, '\n', (size_t)(end - p));
        char *line = p;
        size_t llen = nl ? (size_t)(nl - p) : (size_t)(end - p);
        char *f[8];
        size_t fl[8];
        int nf = 0;
        size_t i, start = 0;

        p = nl ? nl + 1 : end;
        if (!llen) continue;

        for (i = 0; i <= llen && nf < 8; i++) {
            if (i == llen || line[i] == '\t') {
                f[nf] = line + start;
                fl[nf] = i - start;
                nf++;
                start = i + 1;
            }
        }
        if (!nf) continue;

        if (fl[0] == 3 && memcmp(f[0], "sev", 3) == 0 && nf >= 3) {
            SV **slot = hv_fetch(sev, f[1], (I32)fl[1], 1);
            if (slot) sv_setpvn(*slot, f[2], fl[2]);
        }
        else if (fl[0] == 3 && memcmp(f[0], "svc", 3) == 0 && nf >= 3) {
            char key[512];
            size_t kn = po_idx_unesc(f[1], fl[1], key, sizeof(key));
            SV **slot = hv_fetch(svc, key, (I32)kn, 1);
            if (slot) sv_setpvn(*slot, f[2], fl[2]);
        }
        else if (fl[0] == 4 && memcmp(f[0], "edge", 4) == 0 && nf >= 6) {
            HV *e = newHV();
            char a[512], b[512];
            size_t an = po_idx_unesc(f[1], fl[1], a, sizeof(a));
            size_t bn = po_idx_unesc(f[2], fl[2], b, sizeof(b));
            hv_stores(e, "caller",  newSVpvn(a, an));
            hv_stores(e, "callee",  newSVpvn(b, bn));
            hv_stores(e, "count",   newSVpvn(f[3], fl[3]));
            hv_stores(e, "errors",  newSVpvn(f[4], fl[4]));
            hv_stores(e, "dur_max", newSVpvn(f[5], fl[5]));
            av_push(edges, newRV_noinc((SV *)e));
        }
        else if (nf >= 2) {
            SV **slot = hv_fetch(s, f[0], (I32)fl[0], 1);
            if (slot) sv_setpvn(*slot, f[1], fl[1]);
        }
    }
    free(buf);

    hv_stores(s, "severity", newRV_noinc((SV *)sev));
    hv_stores(s, "service",  newRV_noinc((SV *)svc));
    hv_stores(s, "edges",    newRV_noinc((SV *)edges));
    return newRV_noinc((SV *)s);
}

#define po_idx_cat(out, s, n) sv_catpvn((out), (s), (n))

static int po_index_write(pTHX_ const char *path, HV *s) {
    static const char *KEYS[] = { "records", "t_min", "t_max", "metrics",
                                  "logs", "spans", "errors", "traces" };
    SV *body = sv_2mortal(newSVpvs(""));
    int i, ok;

    for (i = 0; i < 8; i++) {
        SV **v = hv_fetch(s, KEYS[i], (I32)strlen(KEYS[i]), 0);
        po_idx_cat(body, KEYS[i], strlen(KEYS[i]));
        po_idx_cat(body, "\t", 1);
        if (v && SvOK(*v)) { STRLEN l; const char *p = SvPV(*v, l);
                             po_idx_cat(body, p, l); }
        else po_idx_cat(body, "0", 1);
        po_idx_cat(body, "\n", 1);
    }

    {   /* severity, numerically, so the file reads in order */
        SV **h = hv_fetch(s, "severity", 8, 0);
        if (h && SvROK(*h) && SvTYPE(SvRV(*h)) == SVt_PVHV) {
            HV *sev = (HV *)SvRV(*h);
            IV k;
            for (k = 0; k <= 24; k++) {
                char kb[8];
                int kn = snprintf(kb, sizeof(kb), "%d", (int)k);
                SV **v = hv_fetch(sev, kb, kn, 0);
                if (!v || !SvOK(*v)) continue;
                { STRLEN l; const char *p = SvPV(*v, l);
                  po_idx_cat(body, "sev\t", 4);
                  po_idx_cat(body, kb, (size_t)kn);
                  po_idx_cat(body, "\t", 1);
                  po_idx_cat(body, p, l);
                  po_idx_cat(body, "\n", 1); }
            }
        }
    }

    {   /* services, sorted, so two runs of the same segment agree */
        SV **h = hv_fetch(s, "service", 7, 0);
        if (h && SvROK(*h) && SvTYPE(SvRV(*h)) == SVt_PVHV) {
            HV *svc = (HV *)SvRV(*h);
            AV *keys = newAV();
            HE *he;
            SSize_t j, n;
            hv_iterinit(svc);
            while ((he = hv_iternext(svc)))
                av_push(keys, newSVsv(hv_iterkeysv(he)));
            sortsv(AvARRAY(keys), (SSize_t)(av_len(keys) + 1), Perl_sv_cmp);
            n = av_len(keys) + 1;
            for (j = 0; j < n; j++) {
                SV **k = av_fetch(keys, j, 0);
                STRLEN kl;
                const char *kp;
                SV **v;
                char esc[512];
                size_t en;
                if (!k) continue;
                kp = SvPV(*k, kl);
                v = hv_fetch(svc, kp, (I32)kl, 0);
                if (!v || !SvOK(*v)) continue;
                en = po_idx_esc(kp, kl, esc, sizeof(esc));
                po_idx_cat(body, "svc\t", 4);
                po_idx_cat(body, esc, en);
                po_idx_cat(body, "\t", 1);
                { STRLEN l; const char *p = SvPV(*v, l); po_idx_cat(body, p, l); }
                po_idx_cat(body, "\n", 1);
            }
            SvREFCNT_dec((SV *)keys);
        }
    }

    {   /* the graph, one edge per line */
        SV **h = hv_fetch(s, "edges", 5, 0);
        if (h && SvROK(*h) && SvTYPE(SvRV(*h)) == SVt_PVAV) {
            AV *av = (AV *)SvRV(*h);
            SSize_t j, n = av_len(av) + 1;
            for (j = 0; j < n; j++) {
                SV **e = av_fetch(av, j, 0);
                HV *eh;
                static const char *EK[] = { "caller", "callee", "count",
                                            "errors", "dur_max" };
                int f;
                if (!e || !SvROK(*e)) continue;
                eh = (HV *)SvRV(*e);
                po_idx_cat(body, "edge", 4);
                for (f = 0; f < 5; f++) {
                    SV **v = hv_fetch(eh, EK[f], (I32)strlen(EK[f]), 0);
                    po_idx_cat(body, "\t", 1);
                    if (v && SvOK(*v)) {
                        STRLEN l;
                        const char *p = SvPV(*v, l);
                        if (f < 2) {
                            char esc[512];
                            size_t en = po_idx_esc(p, l, esc, sizeof(esc));
                            po_idx_cat(body, esc, en);
                        }
                        else po_idx_cat(body, p, l);
                    }
                    else po_idx_cat(body, f < 2 ? "*" : "0", 1);
                }
                po_idx_cat(body, "\n", 1);
            }
        }
    }

    {
        STRLEN bl;
        const char *bp = SvPV(body, bl);
        ok = po_atomic_write(path, bp, (size_t)bl);
    }
    return ok;
}

/* ---- spans, collected straight out of the logs ----------------------------
 *
 * THE PERL THIS REPLACES WENT THROUGH PERL TWICE FOR NO REASON.
 *
 * The records are already C structs in the write-ahead log. The old path
 * decoded each one into a Perl hash, built a second Perl hash per span to
 * describe it, handed the array to Trace::analyse - which converted every one
 * back into the po_span struct it started as - and then converted the results
 * back into Perl again to filter them. Four crossings to run an analysis that
 * is C at both ends.
 *
 * This fills po_span directly. Names and services are INTERNED rather than
 * copied, which is what po_span's name_sym and service_sym were for; the
 * table is the reverse map for the output.
 */
typedef struct {
    po_span_w w;
    po_intern sym;        /* span names and service names share one table */
    int       ok;
} po_span_gather;

static int po_gather_init(po_span_gather *g) {
    memset(g, 0, sizeof(*g));
    if (!po_span_w_init(&g->w)) return 0;
    if (!po_intern_init(&g->sym, 256)) { po_span_w_free(&g->w); return 0; }
    g->ok = 1;
    return 1;
}

static void po_gather_free(po_span_gather *g) {
    if (!g->ok) return;
    po_span_w_free(&g->w);
    po_intern_free(&g->sym);
    g->ok = 0;
}

/* Every span in one log that the range admits. */
static void po_gather_wal(po_span_gather *g, const char *p, size_t len,
                          int have_from, po_u64 from,
                          int have_to, po_u64 to) {
    po_wal_replay rp;
    size_t off = 0;

    po_wal_replay_buf(p, len, &rp, NULL, NULL);

    for (;;) {
        uint32_t magic, frame_len, n_recs, arena_len;
        uint16_t flags, version;
        const char *h;
        const po_rec *recs;
        po_arena view;
        size_t i;

        if (len - off < PO_WAL_HDR) break;
        h = p + off;
        memcpy(&magic, h, 4); magic = po_le32(magic);
        if (magic != PO_WAL_MAGIC) break;
        memcpy(&frame_len, h + 4, 4);  frame_len = po_le32(frame_len);
        memcpy(&n_recs,    h + 8, 4);  n_recs    = po_le32(n_recs);
        memcpy(&arena_len, h + 12, 4); arena_len = po_le32(arena_len);
        flags   = (uint16_t)((unsigned char)h[36] | ((unsigned char)h[37] << 8));
        version = (uint16_t)((unsigned char)h[38] | ((unsigned char)h[39] << 8));
        if (version != PO_WAL_VERSION) break;

        /* THE SEAL TRAILER IS NOT A FRAME OF RECORDS.
         *
         * It is the one frame allowed to have none, and it carries the FILE'S
         * TOTAL RECORD COUNT in the field every other frame uses for its own
         * count - with frame_len zero. Walked as if it were data, the loop
         * below reads that many po_rec past the end of the buffer: 88 bytes
         * times every record the segment ever held.
         *
         * Every other walker in this file checks this flag. This one read the
         * version two bytes further along and never looked at it, so a store
         * whose segments were small enough for the overread to land in heap
         * slack worked, and a real one took SIGBUS on the trace screen. */
        if (flags & PO_WAL_F_SEALED) break;

        if (len - off - PO_WAL_HDR < (size_t)frame_len) break;
        if (off + PO_WAL_HDR + frame_len > rp.bytes_ok) break;

        recs = (const po_rec *)(h + PO_WAL_HDR);
        view.base = (char *)(h + PO_WAL_HDR + (size_t)n_recs * sizeof(po_rec));
        view.len  = (size_t)arena_len;
        view.cap  = (size_t)arena_len;

        for (i = 0; i < n_recs; i++) {
            const po_rec *r = &recs[i];
            po_span sp;
            const char *svc = NULL;
            size_t svc_len = 0;

            if (r->kind != PO_SPAN) continue;
            if (have_from && r->t_unix_nano < from) continue;
            if (have_to   && r->t_unix_nano > to)   continue;

            memset(&sp, 0, sizeof(sp));
            sp.trace_hi       = r->trace_id_hi;
            sp.trace_lo       = r->trace_id_lo;
            sp.span_id        = r->span_id;
            sp.parent_span_id = r->parent_span_id;
            sp.start_ns       = r->t_unix_nano;
            sp.dur_ns         = r->dur_nano;
            sp.kind           = po_rec_span_kind(r);
            sp.status         = po_rec_status(r);

            po_rec_service(r, &view, &svc, &svc_len);
            if (!svc || !svc_len) { svc = "unknown"; svc_len = 7; }
            sp.service_sym = po_intern_put(&g->sym, svc, svc_len);
            sp.name_sym    = r->body_len
                ? po_intern_put(&g->sym, view.base + r->body_off, r->body_len)
                : po_intern_put(&g->sym, "", 0);

            po_span_add(&g->w, &sp);
        }
        off += PO_WAL_HDR + frame_len;
    }
}

/* A case-insensitive substring test.
 *
 * Written out rather than reached for through strcasestr, which is not in
 * every libc this dist builds on, and through tolower, which is
 * locale-dependent: in a Turkish locale tolower('I') is not 'i', and a search
 * box that behaves differently under one LANG is a bug nobody can reproduce.
 */
static int po_substr_i(const char *hay, size_t hn, const char *needle,
                       size_t nn) {
    size_t i, j;
    if (!needle || !nn) return 1;      /* an empty term matches everything */
    if (!hay || hn < nn) return 0;
    for (i = 0; i + nn <= hn; i++) {
        for (j = 0; j < nn; j++) {
            char a = hay[i + j], b = needle[j];
            if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
            if (b >= 'A' && b <= 'Z') b = (char)(b - 'A' + 'a');
            if (a != b) break;
        }
        if (j == nn) return 1;
    }
    return 0;
}

/* A trace identifier as the 32 hex characters everybody else spells it with.
 *
 * In Observe.xs rather than beside its XSUB, because a bare function between
 * two XSUBs is something xsubpp tries to parse. */
static SV *povw_trace_hex_sv(pTHX_ SV *hi_sv, SV *lo_sv) {
    static const char H[] = "0123456789abcdef";
    po_u64 hi = 0, lo = 0;
    char out[32];
    int i;
    (void)po_sv_to_u64(aTHX_ hi_sv, &hi);
    (void)po_sv_to_u64(aTHX_ lo_sv, &lo);
    for (i = 0; i < 16; i++) out[15 - i] = H[(hi >> (i * 4)) & 0xF];
    for (i = 0; i < 16; i++) out[31 - i] = H[(lo >> (i * 4)) & 0xF];
    return newSVpvn(out, 32);
}

/* The record identifier, as C. It is called from three places now - the XSUB,
 * record_matches and the record page - and a call_pv back into Perl for a
 * function that lives here would be a round trip for nothing. */
static SV *povw_record_id_sv(pTHX_ SV *rec) {
    HV *h;
    SV **f;
    const char *body = "", *svc = "";
    STRLEN bl = 0, sl = 0;
    char buf[1024];
    size_t n = 0;
    po_h128 hash;
    char idb[64];
    int k;
    const char *t = "0";
    STRLEN tl = 1;

    if (!SvROK(rec) || SvTYPE(SvRV(rec)) != SVt_PVHV)
        croak("Punk::Observe::View::record_id: expected a record hashref");
    h = (HV *)SvRV(rec);
    if ((f = hv_fetchs(h, "body", 0))    && SvOK(*f)) body = SvPV(*f, bl);
    if ((f = hv_fetchs(h, "service", 0)) && SvOK(*f)) svc  = SvPV(*f, sl);
    if ((f = hv_fetchs(h, "t", 0))       && SvOK(*f)) t    = SvPV(*f, tl);

    /* body NUL service, exactly as the Perl hashed it - the id has to be
     * stable across a version of this code, not merely unique within one. */
    if (bl + 1 + sl <= sizeof(buf)) {
        memcpy(buf, body, bl); n = bl;
        buf[n++] = '\0';
        memcpy(buf + n, svc, sl); n += sl;
        hash = po_murmur3_128(buf, n, 0);
    }
    else {
        char *big;
        Newx(big, bl + 1 + sl, char);
        memcpy(big, body, bl); n = bl;
        big[n++] = '\0';
        memcpy(big + n, svc, sl); n += sl;
        hash = po_murmur3_128(big, n, 0);
        Safefree(big);
    }

    /* The first twelve digits of the high half, decimal, as the Perl took
     * them. */
    {
        char d[24];
        size_t dn = 0;
        po_u64 v = hash.hi;
        if (!v) d[dn++] = '0';
        else { char w[24]; size_t z = 0;
               while (v) { w[z++] = (char)('0' + (int)(v % 10)); v /= 10; }
               while (z) d[dn++] = w[--z]; }
        if (dn > 12) dn = 12;
        {
            size_t tn = tl < sizeof(idb) - 14 ? (size_t)tl : sizeof(idb) - 14;
            memcpy(idb, t, tn); k = (int)tn;
            idb[k++] = '.';
            memcpy(idb + k, d, dn); k += (int)dn;
        }
    }
    return newSVpvn(idb, (STRLEN)k);
}

static int povw_record_matches_c(pTHX_ SV *rec, SV *id) {
    STRLEN il = 0, tl = 0;
    const char *ip, *tp;
    HV *h;
    SV **f;
    const char *dot;
    SV *mine;
    int eq;

    if (!SvOK(id)) return 0;
    if (!SvROK(rec) || SvTYPE(SvRV(rec)) != SVt_PVHV) return 0;
    ip = SvPV(id, il);
    h = (HV *)SvRV(rec);
    f = hv_fetchs(h, "t", 0);
    if (!f || !SvOK(*f)) return 0;
    tp = SvPV(*f, tl);

    /* THE TIMESTAMP FIRST. It is the cheap half of the comparison and it
     * rejects almost everything, so the hash is only computed for a row that
     * could actually be the one. */
    dot = (const char *)memchr(ip, '.', (size_t)il);
    if (!dot) return 0;
    if ((size_t)(dot - ip) != (size_t)tl
        || memcmp(ip, tp, (size_t)tl) != 0) return 0;

    mine = povw_record_id_sv(aTHX_ rec);
    eq = sv_eq(mine, id) ? 1 : 0;
    SvREFCNT_dec(mine);
    return eq;
}

/* The chart box. The same two numbers the pages report as `width` and
 * `height`, so a caller reading one and drawing with the other cannot
 * disagree. */
#define POVW_CHART_W 720
#define POVW_CHART_H 220

/* The `d` attribute of a polyline, as C.
 *
 * The formatting is po_svg.h's, which is hand-rolled for the reason stated
 * there: `%f` in a Perl-flavoured formatter reads an NV, and a path attribute
 * containing `1e-05` is not a path - the chart silently does not draw, on one
 * platform, with no error. */
static SV *povw_path_sv(pTHX_ const double *xs, const double *ys, size_t n) {
    SV *out = newSVpvs("");
    size_t i;
    for (i = 0; i < n; i++) {
        char xb[32], yb[32];
        size_t xn, yn;
        /* M for the first point, then a space and an L for each one after it -
         * the shape a path parser expects and the shape the Perl produced. */
        if (i) sv_catpvs(out, " L");
        else   sv_catpvs(out, "M");
        xn = po_fmt(xs[i], xb);
        yn = po_fmt(ys[i], yb);
        sv_catpvn(out, xb, xn);
        sv_catpvs(out, ",");
        sv_catpvn(out, yb, yn);
    }
    return out;
}

/* sprintf('%.Nf'), spelled so the formatter reads the type it is given: a
 * Perl-flavoured %f takes an NV, and passing a plain double to one is
 * undefined on the quadmath and long-double perls. */
static SV *povw_fixed(pTHX_ double v, int places) {
    switch (places) {
        case 0:  return newSVpvf("%.0" NVff, (NV)v);
        case 1:  return newSVpvf("%.1" NVff, (NV)v);
        case 4:  return newSVpvf("%.4" NVff, (NV)v);
        default: return newSVpvf("%" NVff, (NV)v);
    }
}

/* A symbol back as an SV, for the output. */
static SV *po_sym_sv(pTHX_ const po_intern *t, uint32_t id) {
    uint32_t len = 0;
    const char *p = po_intern_get(t, id, &len);
    return p ? newSVpvn(p, len) : newSVpvs("unknown");
}

/* Every log in a store directory, gathered into one span set. */
static void po_gather_dir(pTHX_ const char *dir, po_span_gather *g,
                          int have_from, po_u64 from,
                          int have_to, po_u64 to) {
    po_dir d;
    const char *name;

    if (!po_opendir(&d, dir)) return;
    while ((name = po_readdir(&d))) {
        size_t nl = strlen(name);
        char path[PO_PATHMAX];
        size_t blen = 0;
        char *bytes;

        if (!(nl > 4 && (memcmp(name + nl - 4, ".seg", 4) == 0
                      || memcmp(name + nl - 4, ".wal", 4) == 0))) continue;
        if (!po_path_join(path, sizeof(path), dir, name)) continue;
        bytes = po_slurp(path, &blen);
        if (!bytes) continue;
        po_gather_wal(g, bytes, blen, have_from, from, have_to, to);
        free(bytes);
    }
    po_closedir(&d);
}

/* One edge into the merge table, keyed on the pair of NAMES.
 *
 * A sidecar holds strings and a live log holds symbols from a table private
 * to it, so the names are the only thing the two sources agree on. */
static void po_edge_merge(pTHX_ HV *edges, const char *caller, size_t cl,
                          const char *callee, size_t el,
                          po_u64 count, po_u64 errs, po_u64 dur_max) {
    char key[600];
    size_t kn = 0;
    SV **slot;
    HV *e;

    if (!cl) { caller = "*"; cl = 1; }
    if (!el) { callee = "unknown"; el = 7; }
    if (cl + el + 1 >= sizeof(key)) return;
    memcpy(key, caller, cl); kn = cl;
    key[kn++] = '\0';
    memcpy(key + kn, callee, el); kn += el;

    slot = hv_fetch(edges, key, (I32)kn, 1);
    if (!slot) return;
    if (!SvOK(*slot) || !SvROK(*slot)) {
        e = newHV();
        hv_stores(e, "caller",  newSVpvn(caller, cl));
        hv_stores(e, "callee",  newSVpvn(callee, el));
        hv_stores(e, "count",   newSVuv(0));
        hv_stores(e, "errors",  newSVuv(0));
        hv_stores(e, "dur_max", newSVuv(0));
        sv_setsv(*slot, sv_2mortal(newRV_noinc((SV *)e)));
    }
    e = (HV *)SvRV(*slot);
    {
        SV **c = hv_fetchs(e, "count", 0);
        SV **r = hv_fetchs(e, "errors", 0);
        SV **m = hv_fetchs(e, "dur_max", 0);
        po_u64 cv = 0, rv = 0, mv = 0;
        if (c) (void)po_sv_to_u64(aTHX_ *c, &cv);
        if (r) (void)po_sv_to_u64(aTHX_ *r, &rv);
        if (m) (void)po_sv_to_u64(aTHX_ *m, &mv);
        if (c) sv_setsv(*c, sv_2mortal(po_u64_to_sv(cv + count)));
        if (r) sv_setsv(*r, sv_2mortal(po_u64_to_sv(rv + errs)));
        /* dur_max is a MAXIMUM, not a sum: adding two maxima is a number that
         * describes nothing. */
        if (m && dur_max > mv) sv_setsv(*m, sv_2mortal(po_u64_to_sv(dur_max)));
    }
}

/* Just the SERVICE COUNTS from a sidecar.
 *
 * A per-record tally merges correctly file by file; an EDGE does not, because
 * a graph derived from one file can only see the parents that are in it. So
 * the counts come from the summary and the edges are built from the spans
 * themselves - see post_graph. */
static void po_graph_merge_services(pTHX_ const char *idx, HV *svc) {
    size_t len = 0;
    char *buf = po_slurp(idx, &len);
    char *p, *end;

    if (!buf) return;
    p = buf; end = buf + len;
    while (p < end) {
        char *nl = memchr(p, '\n', (size_t)(end - p));
        char *line = p;
        size_t ll = nl ? (size_t)(nl - p) : (size_t)(end - p);
        char *f[8];
        size_t fl[8];
        int nf = 0;
        size_t i, start = 0;

        p = nl ? nl + 1 : end;
        if (!ll) continue;
        for (i = 0; i <= ll && nf < 8; i++)
            if (i == ll || line[i] == '\t') {
                f[nf] = line + start; fl[nf] = i - start; nf++; start = i + 1;
            }
        if (nf < 3) continue;
        if (fl[0] == 3 && memcmp(f[0], "svc", 3) == 0) {
            char k[512];
            size_t kn = po_idx_unesc(f[1], fl[1], k, sizeof(k));
            SV **slot = hv_fetch(svc, k, (I32)kn, 1);
            if (slot) sv_setiv(*slot, (SvOK(*slot) ? SvIV(*slot) : 0)
                                    + (IV)atol(f[2]));
        }
    }
    free(buf);
}

/* A live log's edges, from the graph just built over its spans. */
/* `svc` may be NULL. The service counts are per-RECORD - a log line counts
 * too - so they come from the sidecar or from a record walk, never from the
 * span set: counting them here as well as there is how `shop` reported three
 * records when it had two. */
static void po_graph_merge_live(pTHX_ const po_sgraph *sg,
                                const po_span_gather *g, HV *edges, HV *svc) {
    uint32_t i;
    for (i = 0; i < sg->n; i++) {
        uint32_t cl = 0, el = 0;
        const char *cp = (sg->e[i].caller == PO_SVC_UNKNOWN)
            ? NULL : po_intern_get(&g->sym, sg->e[i].caller, &cl);
        const char *ep = po_intern_get(&g->sym, sg->e[i].callee, &el);
        po_edge_merge(aTHX_ edges, cp ? cp : "*", cp ? cl : 1,
                      ep ? ep : "unknown", ep ? el : 7,
                      sg->e[i].count, sg->e[i].errors, sg->e[i].dur_max);
    }
    if (!svc) return;
    for (i = 0; i < g->w.n; i++) {
        uint32_t sl = 0;
        const char *sp = po_intern_get(&g->sym, g->w.s[i].service_sym, &sl);
        SV **slot;
        if (!sp) continue;
        slot = hv_fetch(svc, sp, (I32)sl, 1);
        if (slot) sv_setiv(*slot, (SvOK(*slot) ? SvIV(*slot) : 0) + 1);
    }
}

/* The store's own directory, from the object.
 *
 * `dir/tenant/wal`, built in C so the methods below can be methods rather
 * than Perl wrappers that exist only to compute a path and call through. */
static size_t po_store_waldir(pTHX_ SV *self, char *out, size_t cap) {
    HV *h;
    SV **f;
    const char *dir, *tenant = "default";
    STRLEN dl = 0, tl = 7;
    char base[PO_PATHMAX];

    if (!SvROK(self) || SvTYPE(SvRV(self)) != SVt_PVHV) return 0;
    h = (HV *)SvRV(self);
    f = hv_fetchs(h, "dir", 0);
    if (!f || !SvOK(*f)) return 0;
    dir = SvPV(*f, dl);
    if (!dl) return 0;

    f = hv_fetchs(h, "tenant", 0);
    if (f && SvOK(*f)) { tenant = SvPV(*f, tl); if (!tl) { tenant = "default"; tl = 7; } }

    {
        char t[PO_TENANT_MAX + 1];
        if (tl > PO_TENANT_MAX) return 0;
        memcpy(t, tenant, tl); t[tl] = '\0';
        if (!po_path_join(base, sizeof(base), dir, t)) return 0;
    }
    return po_path_join(out, cap, base, "wal");
}

/* Two small helpers the page builders share.
 *
 * HERE rather than in the .xs file: a C declaration sitting between two XSUBs
 * is mangled by xsubpp, and the symptom is not a compile error - it is the
 * XSUB after it silently not being registered, so a method that plainly
 * exists in the source cannot be found at run time. This dist has now paid
 * for that three times. */
static void povw_set_count(pTHX_ HV *out, const char *key, HV *src,
                           const char *from) {
    SV **f = hv_fetch(src, from, (I32)strlen(from), 0);
    char buf[64];
    STRLEN l = 0;
    const char *p = (f && SvOK(*f)) ? SvPV(*f, l) : "0";
    size_t n;
    if (!f || !SvOK(*f)) l = 1;
    n = po_fmt_count(p, (size_t)l, buf, sizeof(buf));
    hv_store(out, key, (I32)strlen(key), newSVpvn(buf, n), 0);
}

static void povw_set_iv(pTHX_ HV *out, const char *key, HV *src,
                        const char *from) {
    SV **f = hv_fetch(src, from, (I32)strlen(from), 0);
    hv_store(out, key, (I32)strlen(key),
             newSViv(f && SvOK(*f) ? SvIV(*f) : 0), 0);
}

/* The variables every page that reads a window shares: the range control and
 * the bounds. In Observe.xs for the reason above - a declaration between two
 * XSUBs silently unregisters the next one. */
/* The range control's own variables, for a caller that already knows which
 * range it is in. Split out because the trace pages resolve the window once
 * and then hand it to whichever of the two of them is going to answer. */
static void povw_range_vars(pTHX_ HV *v, SV *req, SV *range) {
    int n, i;
    /* dSP HERE, unlike inside a PPCODE body where xsubpp has already
     * declared it and a second one shadows the real thing. */
    dSP;

    ENTER; SAVETMPS; PUSHMARK(SP);
    XPUSHs(req);
    XPUSHs(sv_2mortal(newSVsv(range)));
    PUTBACK;
    n = call_pv("Punk::Observe::View::range_vars", G_ARRAY);
    SPAGAIN;
    {
        SV **got;
        Newx(got, n ? n : 1, SV *);
        for (i = n - 1; i >= 0; i--) got[i] = SvREFCNT_inc(POPs);
        PUTBACK;
        for (i = 0; i + 1 < n; i += 2) {
            STRLEN kl;
            const char *kp = SvPV(got[i], kl);
            hv_store(v, kp, (I32)kl, newSVsv(got[i + 1]), 0);
        }
        for (i = 0; i < n; i++) SvREFCNT_dec(got[i]);
        Safefree(got);
    }
    FREETMPS; LEAVE;
    SPAGAIN;
}

/* The window a page reads, and everything the range control needs to draw
 * itself for it. Returns the range name; the caller owns it. */
static SV *povw_window_range(pTHX_ SV *req, SV **from, SV **to) {
    int n;
    SV *range = NULL;
    dSP;

    ENTER; SAVETMPS; PUSHMARK(SP);
    XPUSHs(req);
    PUTBACK;
    n = call_pv("Punk::Observe::View::window", G_ARRAY);
    SPAGAIN;
    if (n >= 3) {
        range = SvREFCNT_inc(POPs);
        *to   = SvREFCNT_inc(POPs);
        *from = SvREFCNT_inc(POPs);
    }
    else { *from = newSV(0); *to = newSV(0); range = newSVpvs("1h"); }
    PUTBACK;
    FREETMPS; LEAVE;
    SPAGAIN;
    return range;
}

static void povw_window_vars(pTHX_ HV *v, SV *req, SV **from, SV **to) {
    int n, i;
    SV *range = NULL;
    /* dSP HERE, unlike inside a PPCODE body where xsubpp has already
     * declared it and a second one shadows the real thing. */
    dSP;

    ENTER; SAVETMPS; PUSHMARK(SP);
    XPUSHs(req);
    PUTBACK;
    n = call_pv("Punk::Observe::View::window", G_ARRAY);
    SPAGAIN;
    if (n >= 3) {
        range = SvREFCNT_inc(POPs);
        *to   = SvREFCNT_inc(POPs);
        *from = SvREFCNT_inc(POPs);
    }
    else { *from = newSV(0); *to = newSV(0); range = newSVpvs("1h"); }
    PUTBACK;
    FREETMPS; LEAVE;
    SPAGAIN;

    hv_stores(v, "from", newSVsv(*from));
    hv_stores(v, "to",   newSVsv(*to));

    ENTER; SAVETMPS; PUSHMARK(SP);
    XPUSHs(req);
    XPUSHs(sv_2mortal(newSVsv(range)));
    PUTBACK;
    n = call_pv("Punk::Observe::View::range_vars", G_ARRAY);
    SPAGAIN;
    {
        SV **got;
        Newx(got, n ? n : 1, SV *);
        for (i = n - 1; i >= 0; i--) got[i] = SvREFCNT_inc(POPs);
        PUTBACK;
        for (i = 0; i + 1 < n; i += 2) {
            STRLEN kl;
            const char *kp = SvPV(got[i], kl);
            hv_store(v, kp, (I32)kl, newSVsv(got[i + 1]), 0);
        }
        for (i = 0; i < n; i++) SvREFCNT_dec(got[i]);
        Safefree(got);
    }
    FREETMPS; LEAVE;
    SPAGAIN;
    SvREFCNT_dec(range);
}


/* Some of the static helpers above are used only by later phases. Silence the
 * unused warnings without hiding a real one by taking their addresses once. */
static void po_keep_alive(void) {
#ifdef PO_HAVE_BUS
    /* The rest of the bus. Subscriptions and the waker belong to the mount -
     * a subscription made anywhere but boot or on_worker_start lands in one
     * worker - so they are referenced here rather than left to warn. */
    (void)hm_bus_wakers_init; (void)hm_bus_waker_take; (void)hm_bus_waker_fd;
    (void)hm_bus_waker_drained; (void)hm_bus_group_gaps; (void)hm_bus_published;
    (void)hm_bus_subscribe; (void)hm_bus_unsubscribe; (void)hm_bus_dispatch;
#endif
    (void)po_le32; (void)po_tick_ns;
    (void)po_pbr_done; (void)po_pbr_float;
    (void)po_pb_packed_begin; (void)po_pb_packed_varint; (void)po_pb_packed_double;
    (void)po_store_path; (void)po_block_start; (void)po_duration;
    (void)po_wal_replay_buf; (void)po_write_all;
    (void)po_hash32; (void)po_seg_overlaps; (void)po_shared_record;
    (void)po_intern_get; (void)po_write_all_fd;
    (void)po_bw_put1; (void)po_chunk_full;
    (void)po_labelset_add; (void)po_blockdir_init; (void)po_blockdir_free;
    (void)po_blockdir_add; (void)po_bloom_test; (void)po_block_full;
    (void)po_seg_may_match; (void)po_sgraph_add_trace;
    (void)po_has_trace_key; (void)po_column_ok;
    (void)po_expr_selective; (void)po_cmp_str;
    (void)po_al_state_of;   /* the question a UI asks; the routes are 15b */
    /* Reading the key FILE (hashes, never tokens) and binding the rate window
     * to the shared arena both belong to the mount's boot path, which lands
     * with the routes in 15b. Referenced here rather than left to warn. */
    (void)po_keyring_add_hash; (void)po_shared_rate;
    (void)po_retain_account_mapped; (void)po_tier_span;
    (void)po_seg_region; (void)po_buf_free;
    (void)po_fmt_i; (void)po_svg_s; (void)po_nice_num;
}

/* Render one record for the tests. The ingest path in phase 3 never does this
 * - it writes the record array straight to the WAL - so this exists purely so
 * that t/0003-otlp-in.t can assert field by field from Perl.
 *
 * Nanosecond fields go through po_u64_to_sv, which is a UV where that is
 * lossless and a decimal string where it is not. Never SvIV. */
static SV *po_rec_hv(pTHX_ const po_rec *rec, const po_arena *ar) {
    HV *h = newHV();
    hv_stores(h, "kind",     newSVuv((UV)rec->kind));
    hv_stores(h, "t",        po_u64_to_sv(rec->t_unix_nano));
    hv_stores(h, "duration", po_u64_to_sv(rec->dur_nano));
    hv_stores(h, "severity", newSVuv((UV)rec->severity));
    hv_stores(h, "flags",    newSVuv((UV)rec->flags));
    hv_stores(h, "span_kind", newSVuv((UV)po_rec_span_kind(rec)));
    hv_stores(h, "status",    newSVuv((UV)po_rec_status(rec)));
    hv_stores(h, "trace_hi",  po_u64_to_sv(rec->trace_id_hi));
    hv_stores(h, "trace_lo",  po_u64_to_sv(rec->trace_id_lo));
    hv_stores(h, "span_id",   po_u64_to_sv(rec->span_id));
    hv_stores(h, "parent_id", po_u64_to_sv(rec->parent_span_id));

    if (rec->flags & PO_F_VALUE_IS_INT) {
        po_u64 iv;
        memcpy(&iv, &rec->value, 8);
        hv_stores(h, "value", po_u64_to_sv(iv));
        hv_stores(h, "value_is_int", newSViv(1));
    }
    else {
        hv_stores(h, "value", newSVnv((NV)rec->value));
        hv_stores(h, "value_is_int", newSViv(0));
    }

    if (rec->body_len)
        hv_stores(h, "body", newSVpvn(ar->base + rec->body_off, rec->body_len));
    else
        hv_stores(h, "body", newSVpvs(""));

    /* Decode the sorted attribute block back into a hash, so the tests can
     * assert content, and into an ordered list, so they can assert that the
     * ORDER is canonical - which is what phase 4's content-derived series id
     * depends on. */
    {
        HV *at = newHV();
        AV *keys = newAV();
        if (rec->attr_len) {
            const unsigned char *p = (const unsigned char *)ar->base + rec->attr_off;
            const unsigned char *e = p + rec->attr_len;
            po_u64 n = 0; int sh = 0;
            while (p < e) { unsigned char c = *p++; n |= (po_u64)(c & 0x7F) << sh;
                            if (!(c & 0x80)) break; sh += 7; }
            while (n-- && p < e) {
                po_u64 kl = 0; unsigned char tag; SV *val = NULL;
                sh = 0;
                while (p < e) { unsigned char c = *p++; kl |= (po_u64)(c & 0x7F) << sh;
                                if (!(c & 0x80)) break; sh += 7; }
                if ((po_u64)(e - p) < kl) break;
                { const char *kp = (const char *)p; size_t klen = (size_t)kl;
                  p += kl;
                  if (p >= e) break;
                  tag = *p++;
                  switch (tag) {
                    case PO_AV_STRING: case PO_AV_BYTES: case PO_AV_NESTED: {
                        po_u64 vl = 0; sh = 0;
                        while (p < e) { unsigned char c = *p++;
                                        vl |= (po_u64)(c & 0x7F) << sh;
                                        if (!(c & 0x80)) break; sh += 7; }
                        if ((po_u64)(e - p) < vl) { p = e; break; }
                        val = newSVpvn((const char *)p, (STRLEN)vl);
                        p += vl;
                        break;
                    }
                    case PO_AV_DOUBLE: {
                        po_u64 bits; double d;
                        if ((size_t)(e - p) < 8) { p = e; break; }
                        memcpy(&bits, p, 8); p += 8;
                        bits = po_le64(bits); memcpy(&d, &bits, 8);
                        val = newSVnv((NV)d);
                        break;
                    }
                    default: {
                        po_u64 v;
                        if ((size_t)(e - p) < 8) { p = e; break; }
                        memcpy(&v, p, 8); p += 8;
                        v = po_le64(v);
                        /* An INT is two's complement, because OTLP declares
                         * the attribute int64. A bool is 0 or 1 and unsigned
                         * either way. Rendering an int unsigned turns -1 into
                         * 18446744073709551615, which sorts above every
                         * positive value a query could compare it with. */
                        val = (tag == PO_AV_INT) ? po_i64_to_sv(v)
                                                 : po_u64_to_sv(v);
                        break;
                    }
                  }
                  if (val) {
                      hv_store(at, kp, (I32)klen, val, 0);
                      av_push(keys, newSVpvn(kp, klen));
                  }
                }
            }
        }
        hv_stores(h, "attrs",      newRV_noinc((SV *)at));
        hv_stores(h, "attr_order", newRV_noinc((SV *)keys));
    }
    return newRV_noinc((SV *)h);
}

/* Sorting a run of records by time, newest first. A pair rather than two
 * parallel arrays so qsort can move both together. */
typedef struct { po_u64 key; SV *sv; } po_sortpair;

static int po_sortpair_desc(const void *a, const void *b) {
    po_u64 x = ((const po_sortpair *)a)->key;
    po_u64 y = ((const po_sortpair *)b)->key;
    /* Subtraction would wrap: these are nanosecond instants, and the
     * difference between two of them does not fit an int. */
    return x < y ? 1 : (x > y ? -1 : 0);
}

/* A record in the shape the EXECUTOR reads, built directly rather than by
 * rewriting the record hash in Perl afterwards.
 *
 * The two shapes differ in exactly two places and both are load-bearing: the
 * kind is a name rather than a number, and `service` is lifted out of the
 * attributes because every query filters on it and no query should have to
 * know it lives there.
 *
 * Doing it here rather than in a Perl map saves one sub call and one hash
 * copy per record - which on a half-million-row answer is the difference
 * between the scan and everything else. */
static SV *po_row_hv(pTHX_ const po_rec *rec, const po_arena *ar) {
    SV *rv = po_rec_hv(aTHX_ rec, ar);
    HV *h = (HV *)SvRV(rv);
    const char *svc = NULL;
    size_t svc_len = 0;
    const char *kind;

    switch (rec->kind) {
        case PO_METRIC: kind = "metric"; break;
        case PO_SPAN:   kind = "span";   break;
        default:        kind = "log";    break;
    }
    hv_stores(h, "kind", newSVpv(kind, 0));

    po_rec_service(rec, ar, &svc, &svc_len);
    hv_stores(h, "service", (svc && svc_len) ? newSVpvn(svc, svc_len)
                                             : newSVpvs("unknown"));
    return rv;
}

/* The scan across every segment, shared by `records` and `rows`.
 *
 * A function rather than one XSUB calling the other: a call_method back into
 * Perl to reach the same C is a stack frame, a mortal stack and two argument
 * copies to arrive where the caller already was. */
static void po_records_run(pTHX_ SV *self, po_u64 from, int have_from,
                           po_u64 to, int have_to, int kind, po_u64 limit,
                           int as_rows, po_u64 trace_hi, po_u64 trace_lo,
                           int have_trace, AV *out, HV *meta) {
    char dir[PO_PATHMAX];
    po_dir d;
    const char *name;
    AV *names = newAV();
    SSize_t i, n;
    IV scanned = 0, skipped = 0, files = 0, degraded = 0;
    po_sortpair *all = NULL;
    IV nall = 0, call = 0;
        if (!po_store_waldir(aTHX_ self, dir, sizeof(dir))) goto done;
        if (!po_opendir(&d, dir)) goto done;
        while ((name = po_readdir(&d))) {
            size_t nl = strlen(name);
            if (nl > 4 && (memcmp(name + nl - 4, ".seg", 4) == 0
                        || memcmp(name + nl - 4, ".wal", 4) == 0))
                av_push(names, newSVpv(name, 0));
        }
        po_closedir(&d);
        sortsv(AvARRAY(names), (SSize_t)(av_len(names) + 1), Perl_sv_cmp);
        n = av_len(names) + 1;

        for (i = 0; i < n; i++) {
            SV **e = av_fetch(names, i, 0);
            const char *np;
            STRLEN nl;
            char path[PO_PATHMAX];
            char *bytes;
            size_t blen = 0;
            po_wal_replay rp;
            size_t off = 0;

            if (!e) continue;
            np = SvPV(*e, nl);
            if (!po_path_join(path, sizeof(path), dir, np)) continue;

            /* THE CHEAP SKIP FIRST, from the sidecar rather than the log. */
            if (nl > 4 && memcmp(np + nl - 4, ".seg", 4) == 0
                && (have_from || have_to)) {
                char idx[PO_PATHMAX];
                size_t pl = strlen(path);
                po_u64 ix_min = 0, ix_max = 0;
                int seen = 0;
                memcpy(idx, path, pl + 1);
                memcpy(idx + pl - 4, ".idx", 5);
                if (po_index_span(idx, &ix_min, &ix_max, &seen) && seen) {
                    if (have_from && ix_max < from) { skipped++; continue; }
                    if (have_to   && ix_min > to)   { skipped++; continue; }
                }
            }

            bytes = po_slurp(path, &blen);
            if (!bytes || !blen) { free(bytes); continue; }
            files++;

            po_wal_replay_buf(bytes, blen, &rp, NULL, NULL);
            /* A log this build cannot read is REPORTED, never guessed at, and
             * it is not fatal: the other segments still answer and the answer
             * says it is short. */
            if (rp.stopped_reason == PO_REPLAY_VERSION) degraded++;

            for (;;) {
                uint32_t magic, frame_len, n_recs, arena_len;
                uint16_t version, flags;
                const char *h;
                const po_rec *recs;
                po_arena view;
                size_t j;

                if (blen - off < PO_WAL_HDR) break;
                h = bytes + off;
                memcpy(&magic, h, 4); magic = po_le32(magic);
                if (magic != PO_WAL_MAGIC) break;
                memcpy(&frame_len, h + 4, 4);  frame_len = po_le32(frame_len);
                memcpy(&n_recs,    h + 8, 4);  n_recs    = po_le32(n_recs);
                memcpy(&arena_len, h + 12, 4); arena_len = po_le32(arena_len);
                flags   = (uint16_t)((unsigned char)h[36] | ((unsigned char)h[37] << 8));
                version = (uint16_t)((unsigned char)h[38] | ((unsigned char)h[39] << 8));
                if (version != PO_WAL_VERSION) break;
                if (flags & PO_WAL_F_SEALED) break;
                if (blen - off - PO_WAL_HDR < (size_t)frame_len) break;
                if (off + PO_WAL_HDR + frame_len > rp.bytes_ok) break;

                recs = (const po_rec *)(h + PO_WAL_HDR);
                view.base = (char *)(h + PO_WAL_HDR + (size_t)n_recs * sizeof(po_rec));
                view.len  = (size_t)arena_len;
                view.cap  = (size_t)arena_len;

                for (j = 0; j < n_recs; j++) {
                    const po_rec *r = &recs[j];
                    scanned++;
                    if (have_from && r->t_unix_nano < from) continue;
                    if (have_to   && r->t_unix_nano > to)   continue;
                    if (kind && r->kind != (uint8_t)kind)   continue;
                    /* THE CROSS-SIGNAL FILTER. A record's trace id is the
                     * only thing that ties a log line to the request that
                     * produced it, and comparing two integers here is what
                     * keeps "the logs for this trace" a scan rather than a
                     * second pass in Perl over everything the window held. */
                    if (have_trace && (r->trace_id_hi != trace_hi
                                    || r->trace_id_lo != trace_lo)) continue;

                    if (nall == call) {
                        IV want = call ? call * 2 : 256;
                        Renew(all, want, po_sortpair);
                        call = want;
                    }
                    all[nall].key = r->t_unix_nano;
                    all[nall].sv  = as_rows ? po_row_hv(aTHX_ r, &view)
                                            : po_rec_hv(aTHX_ r, &view);
                    nall++;
                }
                off += PO_WAL_HDR + frame_len;
            }
            free(bytes);
        }
        SvREFCNT_dec((SV *)names);

        /* Newest first. qsort rather than the reverse the single-segment scan
         * can use, because across segments the runs interleave. */
        if (nall > 1) qsort(all, (size_t)nall, sizeof(po_sortpair), po_sortpair_desc);

        for (i = 0; i < nall; i++) {
            if ((po_u64)i < limit) av_push(out, all[i].sv);
            else SvREFCNT_dec(all[i].sv);
        }
        hv_stores(meta, "truncated", newSViv((po_u64)nall > limit ? 1 : 0));
        Safefree(all);

    done:
        hv_stores(meta, "scanned",  newSViv(scanned));
        hv_stores(meta, "skipped",  newSViv(skipped));
        hv_stores(meta, "files",    newSViv(files));
        hv_stores(meta, "degraded", newSViv(degraded));
        if (!hv_exists(meta, "truncated", 9))
            hv_stores(meta, "truncated", newSViv(0));
        return;
}




/* The inverse of po_rec_hv: one record read back out of a Perl hash, with its
 * variable-length bytes appended to `ar`.
 *
 * THE FIELD LIST HERE IS THE WHOLE POINT. Writing only t, kind and body -
 * which is what the WAL surface did until the store had a reader - loses
 * severity, the trace and span ids, the duration, the metric value and every
 * attribute, and loses them SILENTLY: the append succeeds, the replay
 * succeeds, and the records come back with zeros in the fields a query
 * filters on. The two functions are inverses or the log is lossy, so a field
 * added to one belongs in the other on the same commit.
 *
 * Returns 0 only when the arena refuses, which is a 4GB batch. */
static int po_rec_from_hv(pTHX_ HV *h, po_rec *rec, po_arena *ar) {
    SV **f;
    po_u64 u = 0;
    unsigned kind = 0, status = 0;

    po_rec_zero(rec);

    if ((f = hv_fetchs(h, "t", 0)) && po_sv_to_u64(aTHX_ *f, &u)) rec->t_unix_nano = u;
    if ((f = hv_fetchs(h, "kind", 0)))     rec->kind = (uint8_t)SvUV(*f);
    if ((f = hv_fetchs(h, "duration", 0)) && po_sv_to_u64(aTHX_ *f, &u))
        rec->dur_nano = u;
    if ((f = hv_fetchs(h, "severity", 0))) rec->severity = (uint16_t)SvUV(*f);
    if ((f = hv_fetchs(h, "flags", 0)))    rec->flags    = (uint16_t)SvUV(*f);
    if ((f = hv_fetchs(h, "series", 0)) && po_sv_to_u64(aTHX_ *f, &u)) rec->series = u;
    if ((f = hv_fetchs(h, "trace_hi", 0)) && po_sv_to_u64(aTHX_ *f, &u))
        rec->trace_id_hi = u;
    if ((f = hv_fetchs(h, "trace_lo", 0)) && po_sv_to_u64(aTHX_ *f, &u))
        rec->trace_id_lo = u;
    if ((f = hv_fetchs(h, "span_id", 0)) && po_sv_to_u64(aTHX_ *f, &u))
        rec->span_id = u;
    if ((f = hv_fetchs(h, "parent_id", 0)) && po_sv_to_u64(aTHX_ *f, &u))
        rec->parent_span_id = u;

    if ((f = hv_fetchs(h, "span_kind", 0))) kind   = (unsigned)SvUV(*f);
    if ((f = hv_fetchs(h, "status", 0)))    status = (unsigned)SvUV(*f);
    po_rec_set_aux(rec, kind, status);

    /* A metric's value is a BIT PATTERN when the point is an integer, so it
     * goes back through the same memcpy it came out through. SvNV on a
     * decimal string that happens to hold 2^63 would round it. */
    if ((f = hv_fetchs(h, "value", 0))) {
        if (rec->flags & PO_F_VALUE_IS_INT) {
            po_u64 iv = 0;
            (void)po_sv_to_u64(aTHX_ *f, &iv);
            memcpy(&rec->value, &iv, 8);
        }
        else rec->value = (double)SvNV(*f);
    }

    if ((f = hv_fetchs(h, "body", 0)) && SvOK(*f)) {
        STRLEN bl;
        const char *bp = SvPV(*f, bl);
        if (bl) {
            uint32_t off = po_arena_put(ar, bp, (size_t)bl);
            if (off == PO_ARENA_ERR) return 0;
            rec->body_off = off;
            rec->body_len = (uint32_t)bl;
        }
    }

    /* The attribute block, re-encoded through po_attrs_encode so the ORDER on
     * disk is canonical however the hash happened to iterate. The content-
     * derived series id in phase 4 depends on that order, so a block written
     * in hash order would give the same labels two different series ids. */
    if ((f = hv_fetchs(h, "attrs", 0)) && SvROK(*f)
        && SvTYPE(SvRV(*f)) == SVt_PVHV) {
        HV *a = (HV *)SvRV(*f);
        HE *he;
        po_attrs at;
        po_attrs_init(&at);
        hv_iterinit(a);
        while ((he = hv_iternext(a))) {
            I32 klen;
            char *k = hv_iterkey(he, &klen);
            SV *v = hv_iterval(a, he);
            po_attr *slot;
            if (klen <= 0) continue;
            slot = po_attrs_push(&at, k, (size_t)klen);
            if (!slot) continue;
            /* The TYPE is preserved, not flattened to a string. A numeric
             * attribute that came back as a string would compare as one, and
             * `where http.response.status_code >= 500` would then be a string
             * comparison that puts 99 above 500. */
            if (SvPOK(v)) {
                STRLEN vl;
                slot->tag  = PO_AV_STRING;
                slot->sp   = (const uint8_t *)SvPV(v, vl);
                slot->slen = (size_t)vl;
            }
            else if (SvIOK(v)) {
                slot->tag = PO_AV_INT;
                /* SvUV WHERE THE SV SAYS UNSIGNED, SvIV OTHERWISE.
                 *
                 * On a 32-bit-IV perl anything above 2^31-1 is stored as a UV,
                 * and SvIV of one of those comes back NEGATIVE - so 2^31 was
                 * written as two's-complement -2147483648 and read back as
                 * 18446744071562067968. The value survived every round trip
                 * intact; it was simply the wrong number, which is the worst
                 * kind of surviving. */
                slot->u = SvIsUV(v) ? (po_u64)SvUV(v) : (po_u64)SvIV(v);
            }
            else if (SvNOK(v)) {
                slot->tag = PO_AV_DOUBLE;
                slot->d   = (double)SvNV(v);
            }
            else {
                STRLEN vl;
                slot->tag  = PO_AV_STRING;
                slot->sp   = (const uint8_t *)SvPV(v, vl);
                slot->slen = (size_t)vl;
            }
        }
        if (at.n) {
            uint32_t alen = 0;
            uint32_t off = po_attrs_encode(&at, ar, &alen);
            if (off == PO_ARENA_ERR) return 0;
            rec->attr_off = off;
            rec->attr_len = alen;
        }
    }
    return 1;
}

/* Load span specs from Perl. Lives here rather than between XSUBs, because
 * xsubpp treats a bare function declaration in an .xs fragment as something
 * to parse rather than pass through. */
static int pot_load(pTHX_ SV *specs, po_span_w *w) {
    AV *av;
    SSize_t i, n;
    if (!SvROK(specs) || SvTYPE(SvRV(specs)) != SVt_PVAV) return 0;
    av = (AV *)SvRV(specs);
    n = av_len(av) + 1;
    for (i = 0; i < n; i++) {
        SV **e = av_fetch(av, i, 0);
        HV *h; SV **f;
        po_span sp;
        po_u64 endv = 0;
        if (!e || !SvROK(*e)) continue;
        h = (HV *)SvRV(*e);
        memset(&sp, 0, sizeof(sp));
        if ((f = hv_fetchs(h, "trace_hi", 0))) (void)po_sv_to_u64(aTHX_ *f, &sp.trace_hi);
        if ((f = hv_fetchs(h, "trace_lo", 0))) (void)po_sv_to_u64(aTHX_ *f, &sp.trace_lo);
        if ((f = hv_fetchs(h, "span_id", 0)))  (void)po_sv_to_u64(aTHX_ *f, &sp.span_id);
        if ((f = hv_fetchs(h, "parent", 0)))   (void)po_sv_to_u64(aTHX_ *f, &sp.parent_span_id);
        if ((f = hv_fetchs(h, "start", 0)))    (void)po_sv_to_u64(aTHX_ *f, &sp.start_ns);
        if ((f = hv_fetchs(h, "end", 0)))      (void)po_sv_to_u64(aTHX_ *f, &endv);
        if ((f = hv_fetchs(h, "service", 0)))  sp.service_sym = (uint32_t)SvUV(*f);
        if ((f = hv_fetchs(h, "name", 0)))     sp.name_sym    = (uint32_t)SvUV(*f);
        if ((f = hv_fetchs(h, "kind", 0)))     sp.kind        = (uint8_t)SvUV(*f);
        if ((f = hv_fetchs(h, "status", 0)))   sp.status      = (uint8_t)SvUV(*f);

        /* end < start means the clock stepped; clamp and flag, exactly as
         * phase 0's rule requires. In a u64 the subtraction is ~1.8e19. */
        if (endv >= sp.start_ns) sp.dur_ns = endv - sp.start_ns;
        else { sp.dur_ns = 0; sp.flags |= PO_SP_CLAMPED; }
        if (sp.status == PO_ST_ERROR) sp.flags |= PO_SP_ERROR;

        if (!po_span_add(w, &sp)) return 0;
    }
    return 1;
}


/* Render an expression node for the tests. Canonical and parenthesised, so a
 * precedence assertion reads as a string comparison rather than a tree walk. */
static const char *poq_agg_name(int a) {
    switch (a) {
        case PO_AGG_COUNT: return "count";
        case PO_AGG_SUM:   return "sum";
        case PO_AGG_AVG:   return "avg";
        case PO_AGG_MIN:   return "min";
        case PO_AGG_MAX:   return "max";
        case PO_AGG_P50:   return "p50";
        case PO_AGG_P90:   return "p90";
        case PO_AGG_P95:   return "p95";
        case PO_AGG_P99:   return "p99";
        case PO_AGG_DISTINCT: return "distinct";
        default: return "?";
    }
}

static const char *poq_op_name(int op) {
    switch (op) {
        case PO_OP_EQ: return "=";   case PO_OP_NE: return "!=";
        case PO_OP_LT: return "<";   case PO_OP_LE: return "<=";
        case PO_OP_GT: return ">";   case PO_OP_GE: return ">=";
        case PO_OP_MATCH: return "=~"; case PO_OP_NMATCH: return "!~";
        default: return "?";
    }
}

static void poq_expr_str(pTHX_ const po_expr *e, SV *out) {
    if (!e) return;
    switch (e->kind) {
        case PO_E_AND:
            sv_catpvs(out, "(");
            poq_expr_str(aTHX_ e->a, out);
            sv_catpvs(out, " and ");
            poq_expr_str(aTHX_ e->b, out);
            sv_catpvs(out, ")");
            break;
        case PO_E_OR:
            sv_catpvs(out, "(");
            poq_expr_str(aTHX_ e->a, out);
            sv_catpvs(out, " or ");
            poq_expr_str(aTHX_ e->b, out);
            sv_catpvs(out, ")");
            break;
        case PO_E_NOT:
            sv_catpvs(out, "(not ");
            poq_expr_str(aTHX_ e->a, out);
            sv_catpvs(out, ")");
            break;
        case PO_E_CMP:
            sv_catpvn(out, e->field, e->field_len);
            sv_catpvs(out, " ");
            sv_catpv(out, poq_op_name(e->op));
            sv_catpvs(out, " ");
            switch (e->vkind) {
                case PO_V_STRING:
                    sv_catpvs(out, "\"");
                    sv_catpvn(out, e->sval, e->sval_len);
                    sv_catpvs(out, "\"");
                    break;
                case PO_V_DURATION: {
                    SV *d = po_u64_to_sv(e->uval);
                    sv_catsv(out, d);
                    sv_catpvs(out, "ns");
                    SvREFCNT_dec(d);
                    break;
                }
                case PO_V_SEVERITY: {
                    SV *d = po_u64_to_sv(e->uval);
                    sv_catpvs(out, "sev:");
                    sv_catsv(out, d);
                    SvREFCNT_dec(d);
                    break;
                }
                default: {
                    SV *d = newSVnv((NV)e->nval);
                    sv_catsv(out, d);
                    SvREFCNT_dec(d);
                    break;
                }
            }
            break;
        default: break;
    }
}

static SV *poq_expr_sv(pTHX_ const po_expr *e) {
    SV *out = newSVpvs("");
    poq_expr_str(aTHX_ e, out);
    return out;
}


/* The log volume histogram, asked for from Perl.
 *
 * The figure itself is built in Punk::Observe::Plot, and called rather than
 * reimplemented here: it runs a second query, picks a bucket width from the
 * window and names the severity bands, none of which is faster in C and all
 * of which would then exist twice.
 *
 * The window comes back out of the page hash rather than being passed in.
 * povw_window_vars has already put it there for the template, and the
 * caller's own references are released before the shape of the answer is
 * known.
 *
 * G_EVAL because this is an ADORNMENT. A page whose chart could not be built
 * still has its table, and a store that refused the extra query - too many
 * buckets, most likely - must not take the screen down with it.
 */
static void povw_add_figure(pTHX_ HV *v, const char *fn, SV *store,
                            const char *q, STRLEN ql, const char *key) {
    SV **fromp = hv_fetchs(v, "from", 0);
    SV **top   = hv_fetchs(v, "to", 0);
    SV *out = NULL;
    int n;
    dSP;

    /* An UNDEF endpoint is passed on rather than treated as absent. `all` is
     * a real range with no bounds, and the figure works out its own span. */
    ENTER; SAVETMPS; PUSHMARK(SP);
    XPUSHs(store);
    XPUSHs(sv_2mortal(newSVpvn(q, ql)));
    XPUSHs(fromp ? sv_2mortal(newSVsv(*fromp)) : &PL_sv_undef);
    XPUSHs(top   ? sv_2mortal(newSVsv(*top))   : &PL_sv_undef);
    PUTBACK;
    n = call_pv(fn, G_SCALAR | G_EVAL);
    SPAGAIN;
    if (n) {
        SV *r = POPs;
        if (!SvTRUE(ERRSV) && SvOK(r) && SvCUR(r)) out = newSVsv(r);
    }
    PUTBACK;
    FREETMPS; LEAVE;
    if (out) hv_store(v, key, (I32)strlen(key), out, 0);
}

/* The same thing for a figure built from one structure rather than from a
 * query: the caller has the data already and only needs it drawn. */
static void povw_add_figure_sv(pTHX_ HV *v, const char *fn, SV *arg,
                               const char *key) {
    SV *out = NULL;
    int n;
    dSP;

    if (!arg || !SvOK(arg)) return;

    ENTER; SAVETMPS; PUSHMARK(SP);
    XPUSHs(arg);
    PUTBACK;
    n = call_pv(fn, G_SCALAR | G_EVAL);
    SPAGAIN;
    if (n) {
        SV *r = POPs;
        if (!SvTRUE(ERRSV) && SvOK(r) && SvCUR(r)) out = newSVsv(r);
    }
    PUTBACK;
    FREETMPS; LEAVE;

    if (out) hv_store(v, key, (I32)strlen(key), out, 0);
}

/* Hand the page's variables to Perl and let it fill in several at once.
 *
 * The single-value helpers above return one string for one key, which is all
 * a figure needs. A shape that contributes a figure AND the table under it
 * would need two calls returning two types, so the hash goes across instead
 * and the Perl side sets what it likes. */
static void povw_fill_vars(pTHX_ HV *v, const char *fn, SV *arg) {
    dSP;
    if (!arg || !SvOK(arg)) return;

    ENTER; SAVETMPS; PUSHMARK(SP);
    XPUSHs(sv_2mortal(newRV_inc((SV *)v)));
    XPUSHs(arg);
    PUTBACK;
    (void)call_pv(fn, G_VOID | G_DISCARD | G_EVAL);
    SPAGAIN;
    FREETMPS; LEAVE;
}

/* A BUCKETED RESULT IS RESHAPED ONCE, HERE, AT THE BOUNDARY.
 *
 * The executor treats the bucket as the first component of the group key,
 * which is what lets every aggregate - percentiles included - compose with it
 * without knowing it exists. What a caller wants back is the other shape: one
 * entry per series, each carrying its points in time order.
 *
 * So the flat groups are split at the '\x1e' the key builder put in, sorted by
 * series and then by bucket, and walked once. Sorting rather than hashing
 * because the points have to come out in time order anyway - a chart handed
 * unordered points draws a line that goes backwards - and a sort gives that
 * and the grouping together. */
typedef struct {
    const char *skey; size_t sklen;   /* the `by` part, borrowed from the group */
    po_u64      idx;                  /* which bucket */
    double      value;
    po_u64      count;
} po_bpoint;

static int po_bpoint_cmp(const void *va, const void *vb) {
    const po_bpoint *a = (const po_bpoint *)va, *b = (const po_bpoint *)vb;
    size_t n = a->sklen < b->sklen ? a->sklen : b->sklen;
    int c = n ? memcmp(a->skey, b->skey, n) : 0;
    if (c) return c;
    if (a->sklen != b->sklen) return a->sklen < b->sklen ? -1 : 1;
    if (a->idx  != b->idx)    return a->idx  <  b->idx  ? -1 : 1;
    return 0;
}

static SV *po_buckets_sv(pTHX_ const po_result *res) {
    AV *series = newAV();
    po_bpoint *pt;
    uint32_t i, n = res->ng;

    if (!n) return newRV_noinc((SV *)series);
    pt = (po_bpoint *)malloc((size_t)n * sizeof(po_bpoint));
    if (!pt) return newRV_noinc((SV *)series);

    for (i = 0; i < n; i++) {
        const char *k = res->g[i].key;
        size_t kl = res->g[i].key_len, j = 0;
        po_u64 idx = 0;
        /* The digits up to the separator. A key with no separator cannot
         * happen on a bucketed result, and is treated as bucket 0 of an
         * unnamed series rather than read past its end. */
        while (j < kl && k[j] >= '0' && k[j] <= '9')
            idx = idx * 10 + (po_u64)(k[j++] - '0');
        if (j < kl && k[j] == '\x1e') j++;
        pt[i].skey  = k + j;
        pt[i].sklen = kl - j;
        pt[i].idx   = idx;
        pt[i].value = res->g[i].value;
        pt[i].count = res->g[i].count;
    }
    qsort(pt, n, sizeof(po_bpoint), po_bpoint_cmp);

    i = 0;
    while (i < n) {
        HV *h = newHV();
        AV *points = newAV();
        uint32_t j = i;
        hv_stores(h, "key", newSVpvn(pt[i].skey, pt[i].sklen));
        while (j < n && pt[j].sklen == pt[i].sklen
               && (pt[j].sklen == 0
                   || memcmp(pt[j].skey, pt[i].skey, pt[j].sklen) == 0)) {
            AV *p = newAV();
            /* The instant, not the index: a caller should never have to
             * multiply by a width it was told separately to know when a
             * point happened. */
            av_push(p, po_u64_to_sv(pt[j].idx * res->bucket_ns));
            av_push(p, newSVnv((NV)pt[j].value));
            av_push(p, po_u64_to_sv(pt[j].count));
            av_push(points, newRV_noinc((SV *)p));
            j++;
        }
        hv_stores(h, "points", newRV_noinc((SV *)points));
        av_push(series, newRV_noinc((SV *)h));
        i = j;
    }

    free(pt);
    return newRV_noinc((SV *)series);
}

/* Load rows from Perl into po_row.
 *
 * The strings BORROW from the SVs, so the SVs must outlive the query - which
 * is why `keep` holds a reference to every one for the duration. Copying
 * every body would make a scan over a million rows a million allocations, and
 * borrowing is exactly what the segment-backed scan will do. */
static IV poe_load_rows(pTHX_ SV *rows, po_row **out, SV ***keep) {
    AV *av;
    SSize_t i, n;
    po_row *rv;
    SV **kp;

    if (!SvROK(rows) || SvTYPE(SvRV(rows)) != SVt_PVAV) return -1;
    av = (AV *)SvRV(rows);
    n = av_len(av) + 1;
    Newxz(rv, n ? n : 1, po_row);
    Newxz(kp, n ? n : 1, SV *);

    for (i = 0; i < n; i++) {
        SV **e = av_fetch(av, i, 0);
        HV *h; SV **f;
        po_row *r = &rv[i];
        if (!e || !SvROK(*e)) continue;
        h = (HV *)SvRV(*e);
        kp[i] = *e;

        r->kind = PO_LOG;
        if ((f = hv_fetchs(h, "kind", 0))) {
            STRLEN kl; const char *k = SvPV(*f, kl);
            if      (kl == 6 && memcmp(k, "metric", 6) == 0) r->kind = PO_METRIC;
            else if (kl == 4 && memcmp(k, "span", 4) == 0)   r->kind = PO_SPAN;
            else r->kind = PO_LOG;
        }
        if ((f = hv_fetchs(h, "t", 0)))        (void)po_sv_to_u64(aTHX_ *f, &r->t);
        if ((f = hv_fetchs(h, "duration", 0))) (void)po_sv_to_u64(aTHX_ *f, &r->duration);
        if ((f = hv_fetchs(h, "trace_hi", 0))) (void)po_sv_to_u64(aTHX_ *f, &r->trace_hi);
        if ((f = hv_fetchs(h, "trace_lo", 0))) (void)po_sv_to_u64(aTHX_ *f, &r->trace_lo);
        if ((f = hv_fetchs(h, "span_id", 0)))  (void)po_sv_to_u64(aTHX_ *f, &r->span_id);
        if ((f = hv_fetchs(h, "severity", 0))) r->severity = (uint16_t)SvUV(*f);
        if ((f = hv_fetchs(h, "status", 0)))   r->status = (uint8_t)SvUV(*f);
        /* THE ROW'S `kind` AND THE QUERY'S `kind` ARE DIFFERENT THINGS.
         *
         * The row hash uses `kind` for which SIGNAL this is - metric, log,
         * span - and `span_kind` for OTLP's server/client/internal. The query
         * language's `kind` column is the second one, declared for the trace
         * and span sources.
         *
         * This loader read the first and never the second, so span_kind was
         * zero on every row and `where kind == 3` matched nothing at all -
         * silently, because a column with no value compares false rather
         * than complaining. */
        if ((f = hv_fetchs(h, "span_kind", 0)))
            r->span_kind = (uint8_t)SvUV(*f);
        if ((f = hv_fetchs(h, "value", 0)))    r->value = SvNV(*f);
        if ((f = hv_fetchs(h, "body", 0)))     r->body = SvPV(*f, r->body_len);
        if ((f = hv_fetchs(h, "service", 0)))  r->service = SvPV(*f, r->service_len);
        if ((f = hv_fetchs(h, "attrs", 0)) && SvROK(*f)
            && SvTYPE(SvRV(*f)) == SVt_PVHV) {
            HV *a = (HV *)SvRV(*f);
            HE *he;
            hv_iterinit(a);
            while ((he = hv_iternext(a)) && r->nattr < PO_ROW_ATTRS) {
                I32 klen;
                char *k = hv_iterkey(he, &klen);
                SV *v = hv_iterval(a, he);
                r->attr[r->nattr].key = k;
                r->attr[r->nattr].key_len = (size_t)klen;
                r->attr[r->nattr].val = SvPV(v, r->attr[r->nattr].val_len);
                r->nattr++;
            }
        }
    }
    *out = rv;
    *keep = kp;
    return n;
}

/* ---- charting a row set --------------------------------------------------
 *
 * Two screens draw the same rows two ways - an SVG path server-side and a
 * plotly figure client-side - and both begin by splitting the rows into one
 * series per service and putting each series in time order. That grouping is
 * shared here because the two used to disagree about it: whichever one was
 * edited last decided which rows were a series and which were dropped, and a
 * chart that draws a different set of points from the table beside it is
 * worse than a chart that fails. */
typedef struct {
    SV *name;       /* the series name, owned here */
    AV *pts;        /* the rows, owned here, in time order */
} povw_series;

static void povw_series_free(pTHX_ povw_series *g, SSize_t n) {
    SSize_t i;
    for (i = 0; i < n; i++) {
        SvREFCNT_dec(g[i].name);
        SvREFCNT_dec((SV *)g[i].pts);
    }
    Safefree(g);
}

/* The timestamp of a row, as bytes. Rows carry it as a decimal string
 * precisely because it does not fit a double. */
static const char *povw_row_t(pTHX_ SV *rowref, STRLEN *len) {
    SV **t;
    if (!rowref || !SvROK(rowref) || SvTYPE(SvRV(rowref)) != SVt_PVHV) {
        *len = 0;
        return "";
    }
    t = hv_fetchs((HV *)SvRV(rowref), "t", 0);
    if (!t || !SvOK(*t)) { *len = 0; return ""; }
    return SvPV(*t, *len);
}

/* HOW MANY LOG LINES ONE SCREEN IS.
 *
 * Enough to scroll through and to search with the browser's own find, and
 * small enough that the page is a page. The reader narrows the window or the
 * query to see further back, and the partial-result banner says so. */
#define POVW_LOG_PAGE 500

/* The numeric value of a row, for deciding which points a chart can drop. */
static double povw_row_value(pTHX_ SV *rowref) {
    SV **v;
    if (!rowref || !SvROK(rowref) || SvTYPE(SvRV(rowref)) != SVt_PVHV) return 0;
    v = hv_fetchs((HV *)SvRV(rowref), "value", 0);
    return (v && SvOK(*v)) ? SvNV(*v) : 0;
}

/* HOW MANY POINTS A LINE IS WORTH DRAWING WITH.
 *
 * The chart is 720 pixels wide. A line through 152,000 points renders at most
 * 720 columns of them, so the other 151,000 cost a three-megabyte page and a
 * browser that stops responding while plotly lays out SVG it will then draw
 * on top of itself.
 *
 * Comfortably above the pixel count, so the decimation below is never visible
 * and never has to be reasoned about at the drawing end. */
#define POVW_PLOT_MAX 2000

/* WHICH points, and the answer is not "every eightieth one".
 *
 * Taking every nth sample drops whichever spike falls between two of them, so
 * the chart that exists to show a spike is the one that hides it. This keeps
 * the MINIMUM AND MAXIMUM of each bucket instead, which reproduces the
 * envelope of the full series exactly - the line covers the same vertical
 * extent it would have covered, drawn from a fraction of the points - and
 * the two ends, so it still spans the window it claims to.
 *
 * Fills `keep` with indices in increasing order and returns how many. */
static SSize_t povw_decimate(pTHX_ AV *pts, SSize_t cnt, SSize_t *keep) {
    SSize_t nb = POVW_PLOT_MAX / 2, b, n = 0;

    for (b = 0; b < nb; b++) {
        SSize_t lo = (SSize_t)((double)b * (double)cnt / (double)nb);
        SSize_t hi = (SSize_t)((double)(b + 1) * (double)cnt / (double)nb);
        SSize_t x, imin, imax;
        double vmin, vmax;
        SV **e;

        if (hi > cnt) hi = cnt;
        if (lo >= hi) continue;

        e = av_fetch(pts, lo, 0);
        imin = imax = lo;
        vmin = vmax = e ? povw_row_value(aTHX_ *e) : 0;
        for (x = lo + 1; x < hi; x++) {
            double vv;
            e = av_fetch(pts, x, 0);
            vv = e ? povw_row_value(aTHX_ *e) : 0;
            if (vv < vmin) { vmin = vv; imin = x; }
            if (vv > vmax) { vmax = vv; imax = x; }
        }
        /* In index order, so x stays monotonic and the line does not double
         * back on itself. */
        if (imin < imax) { keep[n++] = imin; keep[n++] = imax; }
        else if (imax < imin) { keep[n++] = imax; keep[n++] = imin; }
        else keep[n++] = imin;
    }

    /* The first and last sample, so the line starts and ends where the data
     * does rather than at whichever extreme the end buckets happened to hold. */
    if (n && keep[0] != 0) {
        SSize_t x;
        for (x = n; x > 0; x--) keep[x] = keep[x - 1];
        keep[0] = 0;
        n++;
    }
    if (n && keep[n - 1] != cnt - 1) keep[n++] = cnt - 1;
    return n;
}

/* ONE POINT, WITH ITS TIMESTAMP ALREADY IN HAND.
 *
 * povw_row_t is a hash lookup. Calling it from inside a comparison made the
 * cost of ORDERING a series a multiple of the cost of reading it, and on a
 * metric with a hundred thousand points that multiple is the whole request.
 * Fetched once per row here, the sort touches no hash at all. */
typedef struct { SV *sv; const char *t; STRLEN tl; } povw_pt;

/* A bottom-up merge, for the same reason po_row.h uses one: the rows arrive
 * from the store in an order that has nothing to do with the key, and an
 * insertion sort is quadratic on exactly that. It was quadratic here, over
 * 152,000 points, with two hash lookups per comparison - so the metrics
 * screen did not render slowly, it never returned, and it held the worker at
 * a hundred per cent while not returning.
 *
 * O(n log n) whatever the input looks like, and unlike quicksort there is no
 * arrangement of the data that degrades it. */
static void povw_pts_merge(povw_pt *src, povw_pt *dst,
                           SSize_t lo, SSize_t mid, SSize_t hi) {
    SSize_t i = lo, j = mid, k = lo;
    while (i < mid && j < hi) {
        /* `< 0` rather than `<= 0`: equal instants keep the order they
         * arrived in, so two runs of one query draw the same line. */
        dst[k++] = po_ns_cmp_str(src[j].t, (size_t)src[j].tl,
                                 src[i].t, (size_t)src[i].tl, NULL) < 0
                 ? src[j++] : src[i++];
    }
    while (i < mid) dst[k++] = src[i++];
    while (j < hi)  dst[k++] = src[j++];
}

static void povw_pts_sort(povw_pt *a, povw_pt *buf, SSize_t n) {
    povw_pt *src = a, *dst = buf;
    SSize_t width;
    for (width = 1; width < n; width *= 2) {
        SSize_t lo;
        for (lo = 0; lo < n; lo += 2 * width) {
            SSize_t mid = lo + width < n ? lo + width : n;
            SSize_t hi  = lo + 2 * width < n ? lo + 2 * width : n;
            povw_pts_merge(src, dst, lo, mid, hi);
        }
        { povw_pt *t = src; src = dst; dst = t; }
    }
    if (src != a) Copy(src, a, n, povw_pt);
}

/* Split rows into series and order each one. Returns the count and fills
 * *out; the caller frees with povw_series_free. */
static SSize_t povw_series_split(pTHX_ AV *rows, povw_series **out) {
    SSize_t n = rows ? av_len(rows) + 1 : 0;
    SSize_t i, ng = 0;
    povw_series *g;

    Newx(g, n ? n : 1, povw_series);

    for (i = 0; i < n; i++) {
        SV **e = av_fetch(rows, i, 0);
        HV *row;
        SV **v, **s;
        const char *key = "value";
        STRLEN klen = 5;
        SSize_t j;

        if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
        row = (HV *)SvRV(*e);
        /* A ROW WITH NO VALUE IS NOT A GAP IN A LINE, it is a row of a
         * different shape that happened to come back in the same list. */
        v = hv_fetchs(row, "value", 0);
        if (!v || !SvOK(*v)) continue;
        s = hv_fetchs(row, "service", 0);
        if (s && SvOK(*s) && SvCUR(*s)) key = SvPV(*s, klen);

        for (j = 0; j < ng; j++) {
            STRLEN gl;
            const char *gp = SvPV(g[j].name, gl);
            if (gl == klen && memcmp(gp, key, klen) == 0) break;
        }
        if (j == ng) {
            g[ng].name = newSVpvn(key, klen);
            g[ng].pts  = newAV();
            ng++;
        }
        av_push(g[j].pts, SvREFCNT_inc(*e));
    }

    /* The series in name order, so the legend and the colour a series gets
     * do not move between two requests that returned the same data. */
    for (i = 1; i < ng; i++) {
        povw_series k = g[i];
        SSize_t j;
        STRLEN kl;
        const char *kp = SvPV(k.name, kl);
        for (j = i - 1; j >= 0; j--) {
            STRLEN jl;
            const char *jp = SvPV(g[j].name, jl);
            size_t m = jl < kl ? jl : kl;
            int c = m ? memcmp(jp, kp, m) : 0;
            if (!c) c = jl == kl ? 0 : (jl < kl ? -1 : 1);
            if (c <= 0) break;
            g[j + 1] = g[j];
        }
        g[j + 1] = k;
    }

    /* And the points inside each series in time order. Compared as STRINGS by
     * width then value, not numerically: a nanosecond instant past 2^53 does
     * not survive the conversion, and two points a microsecond apart would
     * sort as equal. */
    for (i = 0; i < ng; i++) {
        SSize_t cnt = av_len(g[i].pts) + 1;
        /* THE RAW SLOTS, not av_store: av_store frees whatever occupied the
         * slot, so shifting elements along with it drops a reference on every
         * row it passes over and the array is full of freed SVs by the time
         * the sort finishes. Moving the pointers changes no refcount at all,
         * which is exactly what a permutation should do. */
        SV **arr = AvARRAY(g[i].pts);
        povw_pt *pt, *buf;
        SSize_t a;

        if (cnt < 2) continue;
        Newx(pt,  cnt, povw_pt);
        Newx(buf, cnt, povw_pt);
        for (a = 0; a < cnt; a++) {
            pt[a].sv = arr[a];
            pt[a].t  = povw_row_t(aTHX_ arr[a], &pt[a].tl);
        }
        povw_pts_sort(pt, buf, cnt);
        for (a = 0; a < cnt; a++) arr[a] = pt[a].sv;
        Safefree(buf);
        Safefree(pt);
    }

    *out = g;
    return ng;
}

/* A trace identifier, in whichever spelling arrived.
 *
 * The links carry hex; a bookmark from before, or a decimal pair somebody
 * built by hand, still resolves. Returns 0 when the text is not an identifier
 * at all - which is the signal to treat it as a search term instead. */
static int povw_trace_id_c(pTHX_ SV *text, po_u64 *hi_out, po_u64 *lo_out) {
    STRLEN len, i, start = 0, end;
    const char *p;
    po_u64 hi = 0, lo = 0;

    if (!text || !SvOK(text)) return 0;
    p = SvPV(text, len);

    /* Leading and trailing space, because a paste brings it along. */
    while (start < len && (p[start] == ' ' || p[start] == '\t')) start++;
    end = len;
    while (end > start && (p[end - 1] == ' ' || p[end - 1] == '\t')) end--;
    p += start;
    len = end - start;
    if (!len) return 0;

    /* 32 hex characters: the wire form. */
    if (len == 32) {
        for (i = 0; i < 32; i++) {
            int d;
            char c = p[i];
            if      (c >= '0' && c <= '9') d = c - '0';
            else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
            else return 0;
            if (i < 16) hi = (hi << 4) | (po_u64)d;
            else        lo = (lo << 4) | (po_u64)d;
        }
        /* An all-zero id is invalid and OTLP says so; it is also what a
         * truncated paste looks like. */
        if (!hi && !lo) return 0;
        *hi_out = hi; *lo_out = lo;
        return 1;
    }

    /* `<hi>-<lo>`, both decimal: the form this UI's own links carry. */
    {
        STRLEN dash = 0;
        int found = 0;
        SV *a, *b;
        for (i = 0; i < len; i++) if (p[i] == '-') { dash = i; found = 1; break; }
        if (!found || !dash || dash + 1 >= len) return 0;
        for (i = 0; i < len; i++)
            if (i != dash && (p[i] < '0' || p[i] > '9')) return 0;
        a = sv_2mortal(newSVpvn(p, dash));
        b = sv_2mortal(newSVpvn(p + dash + 1, len - dash - 1));
        if (!po_sv_to_u64(aTHX_ a, &hi)) return 0;
        if (!po_sv_to_u64(aTHX_ b, &lo)) return 0;
        if (!hi && !lo) return 0;
        *hi_out = hi; *lo_out = lo;
        return 1;
    }
}

/* The single-trace page, reached from the trace list page when what arrived
 * turns out to be an identifier. Through Perl rather than as a direct C call
 * because the two are separate XSUBs and the dispatch is one call per page
 * render, against a store read that is orders of magnitude dearer. */
static SV *povw_trace_one_sv(pTHX_ SV *class, SV *store, SV *req,
                             SV *from, SV *to, SV *range) {
    SV *out;
    int n;
    dSP;

    ENTER; SAVETMPS; PUSHMARK(SP);
    XPUSHs(class);
    XPUSHs(store);
    XPUSHs(req);
    XPUSHs(sv_2mortal(newSVsv(from)));
    XPUSHs(sv_2mortal(newSVsv(to)));
    XPUSHs(sv_2mortal(newSVsv(range)));
    PUTBACK;
    n = call_pv("Punk::Observe::View::_trace_one", G_SCALAR);
    SPAGAIN;
    out = n ? SvREFCNT_inc(POPs) : newRV_noinc((SV *)newHV());
    PUTBACK;
    FREETMPS; LEAVE;
    return out;
}

/* The span id of a span's parent, or 0 when it has none. */
static SV *povw_parent_id_sv(pTHX_ SV *tree, SV *span) {
    HV *t, *s;
    SV **f;
    IV i;
    AV *spans;
    SV **p;

    if (!SvROK(tree) || !SvROK(span)) return newSViv(0);
    t = (HV *)SvRV(tree);
    s = (HV *)SvRV(span);

    f = hv_fetchs(s, "parent", 0);
    if (!f || !SvOK(*f)) return newSViv(0);
    i = SvIV(*f);
    /* -1 is a ROOT, not an error: a span with no parent in this trace is the
     * top of it. */
    if (i < 0) return newSViv(0);

    f = hv_fetchs(t, "spans", 0);
    if (!f || !SvROK(*f) || SvTYPE(SvRV(*f)) != SVt_PVAV) return newSViv(0);
    spans = (AV *)SvRV(*f);
    p = av_fetch(spans, (SSize_t)i, 0);
    if (!p || !SvROK(*p)) return newSViv(0);

    f = hv_fetchs((HV *)SvRV(*p), "span_id", 0);
    return (f && SvOK(*f)) ? newSVsv(*f) : newSViv(0);
}

/* Two questions the metrics page asks of the query TEXT.
 *
 * Written out rather than left as regular expressions because they decide
 * something a chart is wrong about if it is wrong: whether an absent bucket
 * is a zero or a gap. `\b` is perl's - [A-Za-z0-9_] on either side - and `$`
 * matches at the end or before a single trailing newline, as it does without
 * /m. The only backtracking either needs is the optional `count`, and it is
 * tried present-first, which is what a greedy `?` does. */
static int povw_word_at(const char *q, size_t n, size_t i,
                        const char *w, size_t wn) {
    if (i + wn > n) return 0;
    if (memcmp(q + i, w, wn) != 0) return 0;
    if (i && isWORDCHAR_A((U8)q[i - 1])) return 0;
    return 1;
}

/* /\brate\s*\(/ */
static int povw_q_rate(const char *q, size_t n) {
    size_t i;
    for (i = 0; i < n; i++) {
        size_t j;
        if (!povw_word_at(q, n, i, "rate", 4)) continue;
        j = i + 4;
        while (j < n && isSPACE((U8)q[j])) j++;
        if (j < n && q[j] == '(') return 1;
    }
    return 0;
}

/* /\bbucket\s*\([^)]*\)\s*(?:count)?\s*(?:by|$)/ */
static int povw_q_bucket(const char *q, size_t n) {
    size_t i;
    for (i = 0; i < n; i++) {
        size_t j;
        int attempt;
        if (!povw_word_at(q, n, i, "bucket", 6)) continue;
        j = i + 6;
        while (j < n && isSPACE((U8)q[j])) j++;
        if (j >= n || q[j] != '(') continue;
        j++;
        while (j < n && q[j] != ')') j++;
        if (j >= n) continue;               /* never closed */
        j++;
        for (attempt = 0; attempt < 2; attempt++) {
            size_t k = j;
            while (k < n && isSPACE((U8)q[k])) k++;
            if (attempt == 0) {
                if (!(k + 5 <= n && memcmp(q + k, "count", 5) == 0)) continue;
                k += 5;
                while (k < n && isSPACE((U8)q[k])) k++;
            }
            if (k + 2 <= n && memcmp(q + k, "by", 2) == 0) return 1;
            if (k == n) return 1;
            if (k + 1 == n && q[k] == '\n') return 1;
        }
    }
    return 0;
}

/* A figure through Plot, encoded. Both halves are Perl, and calling them
 * separately from three places was three chances to encode one and forget the
 * other. */
static SV *povw_plot_encode(pTHX_ const char *fn, SV **args, int nargs) {
    SV *fig = NULL, *enc = NULL;
    int n, k;
    dSP;

    ENTER; SAVETMPS; PUSHMARK(SP);
    for (k = 0; k < nargs; k++) XPUSHs(args[k]);
    PUTBACK;
    n = call_pv(fn, G_SCALAR);
    SPAGAIN;
    fig = n ? SvREFCNT_inc(POPs) : NULL;
    PUTBACK;
    FREETMPS; LEAVE;

    ENTER; SAVETMPS; PUSHMARK(SP);
    XPUSHs(sv_2mortal(fig ? newSVsv(fig) : newSV(0)));
    PUTBACK;
    n = call_pv("Punk::Observe::Plot::encode", G_SCALAR);
    SPAGAIN;
    enc = n ? SvREFCNT_inc(POPs) : NULL;
    PUTBACK;
    FREETMPS; LEAVE;
    if (fig) SvREFCNT_dec(fig);
    return enc;
}

/* A value as `0 + $x` would have made it.
 *
 * NOT newSVnv: perl's own addition asks SvIV_please of both operands first,
 * so an NV that happens to be integral comes back an IV, and the JSON says
 * -2 where a plain NV would say -2.0. A chart library reading one of those as
 * a category and the other as a number is a real failure mode, and the
 * difference is invisible on the screen that produced it. */
static SV *povw_num(pTHX_ SV *v) {
    if (!v || !SvOK(v)) return newSViv(0);
    SvIV_please_nomg(v);
    if (SvIOK(v)) return SvIsUV(v) ? newSVuv(SvUV(v)) : newSViv(SvIV(v));
    return newSVnv(SvNV(v));
}

/* Does this row carry a trace to jump to? */
static int povw_row_has_trace(pTHX_ SV *rowref) {
    HV *row;
    SV **hi, **lo;
    if (!SvROK(rowref) || SvTYPE(SvRV(rowref)) != SVt_PVHV) return 0;
    row = (HV *)SvRV(rowref);
    hi = hv_fetchs(row, "trace_hi", 0);
    lo = hv_fetchs(row, "trace_lo", 0);
    return ((hi && SvTRUE(*hi)) || (lo && SvTRUE(*lo))) ? 1 : 0;
}

/* Milliseconds since the epoch, for a chart axis.
 *
 * Milliseconds fit a double with room to spare - 1.8e12 against a 9e15
 * ceiling - so the axis is exact to the millisecond, which is finer than any
 * screen can resolve. What is NOT done is arithmetic on the nanoseconds
 * first: dividing by a million before the conversion rounds the value in the
 * digits a chart is drawn from. So the last six digits are DROPPED, as
 * characters, and what is left is converted once. */
static SV *povw_plot_ms(pTHX_ SV *ns_sv) {
    STRLEN len;
    const char *p;
    char buf[32];
    size_t n = 0, i;
    po_u64 v = 0;

    if (!ns_sv || !SvOK(ns_sv)) return newSViv(0);
    p = SvPV(ns_sv, len);
    for (i = 0; i < (size_t)len && n < sizeof(buf); i++)
        if (p[i] >= '0' && p[i] <= '9') buf[n++] = p[i];
    if (n <= 6) return newSViv(0);
    n -= 6;
    for (i = 0; i < n; i++) v = v * 10 + (po_u64)(buf[i] - '0');
    /* An IV where it fits, as perl's own numification would have given, so
     * the JSON says 1787000000000 rather than 1.787e+12. */
    if (v <= (po_u64)IV_MAX) return newSViv((IV)v);
    return newSVnv((NV)v);
}

MODULE = Punk::Observe   PACKAGE = Punk::Observe

BOOT:
    po_keep_alive();

INCLUDE: xs/contracts.xs

INCLUDE: xs/decode.xs

INCLUDE: xs/wal.xs

INCLUDE: xs/ingest.xs

INCLUDE: xs/segment.xs

INCLUDE: xs/metrics.xs

INCLUDE: xs/logs.xs

INCLUDE: xs/traces.xs

INCLUDE: xs/query.xs

INCLUDE: xs/exec.xs

INCLUDE: xs/retain.xs

INCLUDE: xs/segio.xs

INCLUDE: xs/svg.xs

INCLUDE: xs/scan.xs

INCLUDE: xs/live.xs

INCLUDE: xs/alert.xs

INCLUDE: xs/tenant.xs

INCLUDE: xs/store.xs

INCLUDE: xs/view.xs

INCLUDE: xs/plot.xs
