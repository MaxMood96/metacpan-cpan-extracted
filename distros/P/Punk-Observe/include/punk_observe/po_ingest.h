/* po_ingest.h - the OTLP receiver.
 *
 * The whole PSGI path: route, authenticate, read, bound, decompress, decode,
 * store, answer. It is one code path for all three transports, because the
 * three differ only in how bytes become records and sharing everything after
 * that is what keeps them from drifting into three behaviours.
 *
 * Three things reach back into Perl, and only three: the tenant resolver, the
 * store callback and - on the JSON path - the parse. Everything else, down to
 * the response bytes, is here. The parse stays in Perl on purpose: JSON is the
 * debuggable transport and protobuf is the production one, so a second JSON
 * parser to save allocations on a path nobody benchmarks is the wrong trade.
 * The WALK of what it returns is C, so nothing is allocated per record.
 *
 * Perl headers must be included before this file.
 */
#ifndef PO_INGEST_H
#define PO_INGEST_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_otlp_in.h"
#include "punk_observe/po_json_in.h"

#ifdef PO_HAVE_ZLIB
#  include <zlib.h>
#endif

/* Perl 5.15 added XS_INTERNAL. Before it, XS() carried __declspec(dllexport)
 * on Windows, which cannot be combined with `static`, so the prototype is
 * spelled out rather than borrowed. */
#ifndef XS_INTERNAL
#  define XS_INTERNAL(name) static void name(pTHX_ CV *cv)
#endif

#define PO_SIG_NONE     0
#define PO_SIG_TRACES   1
#define PO_SIG_METRICS  2
#define PO_SIG_LOGS     3

#define PO_ENC_NONE     0
#define PO_ENC_PROTOBUF 1
#define PO_ENC_JSON     2

#define PO_CE_NONE      0
#define PO_CE_GZIP      1
#define PO_CE_DEFLATE   2

/* Decompressed-size ceiling as a multiple of the compressed body. A 40KB body
 * that inflates to 4GB is a denial of service with no exploit needed, so the
 * limit applies to the DECOMPRESSED size and not only to what arrived. */
#define PO_MAX_RATIO 20

/* The largest body this perl can address. max_body is clamped to it, so that
 * CONTENT_LENGTH is checked against a number the buffer about to be filled can
 * actually hold: on a 32-bit perl STRLEN is four bytes, and a max_body set
 * above that would let a length truncate on the way in and overrun what was
 * allocated for it. */
#define PO_BODY_MAX ((po_u64)(STRLEN)~(STRLEN)0 - 1)

typedef struct {
    po_u64 max_body;
    po_u64 max_ratio;
    po_u64 max_records;      /* 0 = uncapped */
    SV    *auth;             /* coderef: $env -> tenant id or undef, or NULL */
    SV    *on_batch;         /* coderef: (tenant, signal, buf, enc, out)     */
} po_ingest;

/* --- the routing table ---------------------------------------------------- */

static int po_signal_of(const char *p, size_t len) {
    if (len == 10 && memcmp(p, "/v1/traces",  10) == 0) return PO_SIG_TRACES;
    if (len == 11 && memcmp(p, "/v1/metrics", 11) == 0) return PO_SIG_METRICS;
    if (len ==  8 && memcmp(p, "/v1/logs",     8) == 0) return PO_SIG_LOGS;
    return PO_SIG_NONE;
}

static const char *po_signal_name(int sig) {
    switch (sig) {
        case PO_SIG_TRACES:  return "traces";
        case PO_SIG_METRICS: return "metrics";
        default:             return "logs";
    }
}

/* The field a rejected count is reported under, per signal. */
static const char *po_rejected_field(int sig) {
    switch (sig) {
        case PO_SIG_TRACES:  return "rejectedSpans";
        case PO_SIG_METRICS: return "rejectedDataPoints";
        default:             return "rejectedLogRecords";
    }
}

/* Normalise a Content-Type: lowercase, and cut at the first parameter along
 * with the whitespace before it. Everything else is left alone, so a leading
 * space is still a mismatch - a header with one is malformed, and quietly
 * accepting it here would mean two receivers disagreeing about what is valid.
 *
 * Returns the length written; the buffer is always NUL-terminated. */
static size_t po_ctype_norm(const char *p, size_t len, char *out, size_t cap) {
    size_t n, i;

    /* The cut is found in the INPUT, not while filling the output. Bounding
     * the search by the buffer would let a long parameter list push the
     * semicolon out of reach and turn a perfectly good application/json into
     * a 415. */
    for (i = 0; i < len && p[i] != ';'; i++) ;
    while (i && (p[i-1] == ' ' || p[i-1] == '\t')) i--;

    if (i > cap - 1) i = cap - 1;      /* longer than any type we serve */
    for (n = 0; n < i; n++) {
        char c = p[n];
        out[n] = (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
    }
    out[n] = '\0';
    return n;
}

static int po_enc_of(const char *p, size_t len) {
    if (len == 22 && memcmp(p, "application/x-protobuf", 22) == 0) return PO_ENC_PROTOBUF;
    if (len == 16 && memcmp(p, "application/json",      16) == 0) return PO_ENC_JSON;
    return PO_ENC_NONE;
}

static int po_ce_of(const char *p, size_t len) {
    size_t i;
    char b[16];
    if (len >= sizeof(b)) return PO_CE_NONE;
    for (i = 0; i < len; i++) {
        char c = p[i];
        b[i] = (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
    }
    if (len == 4 && memcmp(b, "gzip",    4) == 0) return PO_CE_GZIP;
    if (len == 7 && memcmp(b, "deflate", 7) == 0) return PO_CE_DEFLATE;
    return PO_CE_NONE;
}

/* --- decompression -------------------------------------------------------- */

#ifdef PO_HAVE_ZLIB
/* Inflate with a hard ceiling, refusing the moment it is crossed rather than
 * after. That ordering is the whole point: a forty-kilobyte body expanding to
 * gigabytes must be stopped while it is expanding, and any interface that can
 * be asked to produce an unbounded amount in one call cannot do that.
 *
 * windowBits selects the framing, and the two HTTP encodings are not the same
 * stream: 15+16 is gzip only, 15 is the zlib wrapper that `deflate` means.
 * Neither is 15+32, which auto-detects - a body labelled gzip that is really
 * zlib is a mislabelled encoding, and saying so beats guessing.
 *
 * There is no transparent fallback. Passing non-compressed data through, which
 * is what the Perl decompressors do by default, would accept a body whose gzip
 * framing is subtly wrong and then report it as a malformed OTLP payload -
 * losing the actual cause on the way.
 */
static int po_inflate_bounded(const char *src, size_t srclen, int gzip,
                              size_t max, char **out, size_t *outlen) {
    z_stream z;
    char *buf = NULL;
    size_t cap = 0, len = 0;
    int rc;

    /* avail_in is a uInt. A compressed body over 4GB is not a request anyone
     * is making, and refusing it is a 413, which is the truthful answer. */
    if (srclen > (size_t)0xFFFFFFFFUL) return 0;

    memset(&z, 0, sizeof(z));
    if (inflateInit2(&z, gzip ? 15 + 16 : 15) != Z_OK) return 0;
    z.next_in  = (Bytef *)(void *)src;
    z.avail_in = (uInt)srclen;

    for (;;) {
        size_t room;
        if (len == cap) {
            size_t ncap;
            char *nb;
            if (len > max) goto fail;          /* the ceiling, crossed */
            ncap = cap ? cap * 2 : 65536;
            /* One byte past the ceiling is enough to notice the overrun. */
            if (ncap > max + 1) ncap = max + 1;
            if (ncap <= cap) goto fail;        /* cannot grow: at the ceiling */
            nb = (char *)realloc(buf, ncap);
            if (!nb) goto fail;
            buf = nb; cap = ncap;
        }
        room = cap - len;
        if (room > (size_t)0x40000000UL) room = (size_t)0x40000000UL;
        z.next_out  = (Bytef *)(buf + len);
        z.avail_out = (uInt)room;
        rc = inflate(&z, Z_NO_FLUSH);
        len += room - (size_t)z.avail_out;
        if (rc == Z_STREAM_END) break;
        if (rc != Z_OK) goto fail;
        if (len > max) goto fail;
        /* Room left and nothing left to feed it: the stream stops mid-member.
         * The Perl decompressor hands back what it got so far, which arrives
         * later as a malformed OTLP payload with the real cause thrown away. */
        if (z.avail_in == 0 && z.avail_out != 0) goto fail;
    }

    inflateEnd(&z);
    if (!buf) { buf = (char *)malloc(1); if (!buf) return 0; }
    *out = buf; *outlen = len;
    return 1;

fail:
    inflateEnd(&z);
    free(buf);
    return 0;
}
#endif /* PO_HAVE_ZLIB */

/* --- the partial-success body --------------------------------------------- */

/* ExportTraceServiceResponse { partial_success = 1 }
 * ExportTracePartialSuccess  { rejected_* = 1, error_message = 2 }
 *
 * Tiny, and on the response path rather than the hot one, but it has to be
 * exactly right: this is the channel that says "I kept 9,600 of these and
 * rejected 400", and Punk::OpenTelemetry's exporter reads it. `out` needs 80
 * bytes; the message is truncated to 40 so the inner length stays one byte. */
static size_t po_partial_success_pb(char *out, po_u64 rej,
                                    const char *msg, size_t mlen) {
    char inner[64];
    size_t n = 0, o = 0;

    if (mlen > 40) mlen = 40;

    if (rej) {                                  /* field 1, varint */
        po_u64 v = rej;
        inner[n++] = (char)0x08;
        do { unsigned char c = (unsigned char)(v & 0x7F); v >>= 7;
             if (v) c |= 0x80;
             inner[n++] = (char)c; } while (v);
    }
    if (msg && mlen) {                          /* field 2, length-delimited */
        inner[n++] = (char)0x12;
        inner[n++] = (char)mlen;
        memcpy(inner + n, msg, mlen); n += mlen;
    }

    out[o++] = (char)0x0A;                      /* field 1, length-delimited */
    out[o++] = (char)n;
    memcpy(out + o, inner, n); o += n;
    return o;
}

/* --- the response --------------------------------------------------------- */

static SV *po_psgi_res(pTHX_ int status, const char *ctype, SV *body,
                       const char *xk, SV *xv) {
    AV *hdr = newAV();
    AV *bod = newAV();
    AV *res = newAV();
    STRLEN blen;

    (void)SvPV(body, blen);
    av_push(hdr, newSVpvs("Content-Type"));
    av_push(hdr, newSVpv(ctype, 0));
    av_push(hdr, newSVpvs("Content-Length"));
    av_push(hdr, newSVuv((UV)blen));
    if (xk) { av_push(hdr, newSVpv(xk, 0)); av_push(hdr, xv); }

    av_push(bod, body);
    av_push(res, newSViv((IV)status));
    av_push(res, newRV_noinc((SV *)hdr));
    av_push(res, newRV_noinc((SV *)bod));
    return newRV_noinc((SV *)res);
}

/* The status codes are a data-retention decision rather than a formality: an
 * OTLP client retries 429/502/503/504 and DROPS everything else, so getting
 * them backwards means either losing telemetry or being retried forever. */
static SV *po_err(pTHX_ int status, const char *msg, const char *xk, SV *xv) {
    SV *body = newSVpv(msg, 0);
    sv_catpvs(body, "\n");
    return po_psgi_res(aTHX_ status, "text/plain", body, xk, xv);
}

/* Strip perl's " at FILE line N." from a die message, so what reaches the
 * client is the reason and not this file's line numbering. */
static SV *po_trim_die(pTHX_ SV *err) {
    STRLEN len;
    const char *p;
    const char *end;
    const char *q;

    p = SvPV(err, len);
    end = p + len;

    while (end > p && isSPACE(end[-1])) end--;
    if (end > p && end[-1] == '.') end--;

    q = end;
    while (q > p && q[-1] >= '0' && q[-1] <= '9') q--;
    if (q < end) {                                   /* there was a number */
        const char *r = q;
        while (r > p && isSPACE(r[-1])) r--;
        if (r - p >= 4 && memcmp(r - 4, "line", 4) == 0) {
            r -= 4;
            while (r > p && isSPACE(r[-1])) r--;
            while (r > p && !isSPACE(r[-1])) r--;     /* \S+, the file name */
            while (r > p && isSPACE(r[-1])) r--;
            if (r - p >= 2 && memcmp(r - 2, "at", 2) == 0) {
                r -= 2;
                while (r > p && isSPACE(r[-1])) r--;
                end = r;
            }
        }
    }
    return newSVpvn(p, (STRLEN)(end - p));
}

/* --- the body ------------------------------------------------------------- */

/* Returns 1 with *out set, or 0 with *why set (413) or *why NULL (400).
 *
 * The limit is enforced BEFORE the read completes, not after. A hundred
 * megabytes decoded into an arena and then measured is a memory exhaustion
 * with extra steps. */
static int po_read_body(pTHX_ po_ingest *ing, HV *env, SV **out, SV **why) {
    SV **e;
    SV *fh;
    po_u64 len = 0;
    STRLEN got = 0;
    SV *buf;
    int ce;

    *out = NULL; *why = NULL;

    e = hv_fetchs(env, "CONTENT_LENGTH", 0);
    if (!e || !SvOK(*e)) return 0;
    (void)po_sv_to_u64(aTHX_ *e, &len);

    if (len > ing->max_body) {
        *why = newSVpvs("body exceeds max_body (");
        sv_catsv(*why, sv_2mortal(po_u64_to_sv(ing->max_body)));
        sv_catpvs(*why, ")");
        return 0;
    }

    e = hv_fetchs(env, "psgi.input", 0);
    if (!e || !SvOK(*e)) return 0;
    fh = *e;

    buf = newSV(len ? (STRLEN)len + 1 : 1);
    sv_setpvs(buf, "");

    /* An unblessed handle is read through PerlIO directly - Hyperman's
     * psgi.input is exactly that, a :scalar or temp-file handle. An OBJECT
     * keeps its method call, because a server that wraps the body in a class
     * of its own may mean something by `read` that PerlIO does not. */
    if (!sv_isobject(fh)) {
        IO *io = NULL;
        SV *rv = SvROK(fh) ? SvRV(fh) : fh;
        if (SvTYPE(rv) == SVt_PVGV)      io = GvIO((GV *)rv);
        else if (SvTYPE(rv) == SVt_PVIO) io = (IO *)rv;
        if (io && IoIFP(io)) {
            SvGROW(buf, (STRLEN)len + 1);
            while (got < (STRLEN)len) {
                SSize_t k = PerlIO_read(IoIFP(io), SvPVX(buf) + got,
                                        (STRLEN)len - got);
                if (k <= 0) break;
                got += (STRLEN)k;
            }
            SvCUR_set(buf, got);
            *SvEND(buf) = '\0';
            goto have_body;
        }
    }

    {   /* $fh->read(my $chunk, $n) - the same call the Perl made. */
        SV *chunk = newSV(0);
        while (got < (STRLEN)len) {
            STRLEN want = (STRLEN)len - got;
            SSize_t k;
            dSP;
            if (want > 65536) want = 65536;
            ENTER; SAVETMPS;
            PUSHMARK(SP);
            XPUSHs(fh);
            XPUSHs(chunk);
            XPUSHs(sv_2mortal(newSVuv((UV)want)));
            PUTBACK;
            call_method("read", G_SCALAR | G_EVAL);
            SPAGAIN;
            {
                SV *r = POPs;              /* never SvTRUE around a POP */
                k = SvOK(r) ? (SSize_t)SvIV(r) : 0;
            }
            PUTBACK;
            if (SvTRUE(ERRSV)) k = 0;
            FREETMPS; LEAVE;
            if (k <= 0) break;
            sv_catsv(buf, chunk);
            got += (STRLEN)k;
        }
        SvREFCNT_dec(chunk);
    }

have_body:
    e = hv_fetchs(env, "HTTP_CONTENT_ENCODING", 0);
    ce = PO_CE_NONE;
    if (e && SvOK(*e)) {
        STRLEN cl;
        const char *cp;
        cp = SvPV(*e, cl);
        ce = po_ce_of(cp, cl);
    }

    if (ce != PO_CE_NONE) {
        po_u64 max = ing->max_body;
        po_u64 room = (len && ing->max_ratio > PO_U64_MAX / len)
                    ? PO_U64_MAX : len * ing->max_ratio;
        if (room < max) max = room;
#ifdef PO_HAVE_ZLIB
        {
            STRLEN clen;
            const char *cp;
            char *raw = NULL;
            size_t rawlen = 0;
            cp = SvPV(buf, clen);
            if (!po_inflate_bounded(cp, (size_t)clen, ce == PO_CE_GZIP,
                                    (size_t)max, &raw, &rawlen)) {
                SvREFCNT_dec(buf);
                *why = newSVpvs("compressed body expands beyond the limit");
                return 0;
            }
            sv_setpvn(buf, raw, (STRLEN)rawlen);
            free(raw);
        }
#else
        /* No zlib at build time. The fallback is the core decompressors,
         * driven from the .pm, and it is the ONLY thing in this path that is
         * not C. It reads in bounded chunks for the same reason as above. */
        {
            dSP;
            SV *res;
            int ok;
            ENTER; SAVETMPS;
            PUSHMARK(SP);
            XPUSHs(buf);
            XPUSHs(sv_2mortal(newSVpv(ce == PO_CE_GZIP ? "gzip" : "deflate", 0)));
            XPUSHs(sv_2mortal(po_u64_to_sv(max)));
            PUTBACK;
            call_pv("Punk::Observe::Ingest::_inflate", G_SCALAR | G_EVAL);
            SPAGAIN;
            res = POPs;
            ok = SvOK(res) ? 1 : 0;
            if (ok) sv_setsv(buf, res);
            PUTBACK;
            if (SvTRUE(ERRSV)) ok = 0;
            FREETMPS; LEAVE;
            if (!ok) {
                SvREFCNT_dec(buf);
                *why = newSVpvs("compressed body expands beyond the limit");
                return 0;
            }
        }
#endif
    }

    *out = buf;
    return 1;
}

/* --- decoding ------------------------------------------------------------- */

/* Returns 1 on a decodable batch. *errmsg, when set, is the detail appended to
 * "malformed OTLP: "; the caller owns it. */
static int po_decode_body(pTHX_ SV *body, int sig, int enc, po_batch *b,
                          SV **errmsg) {
    *errmsg = NULL;

    if (enc == PO_ENC_PROTOBUF) {
        STRLEN len;
        const char *p;
        int ok;
        p = SvPV(body, len);
        switch (sig) {
            case PO_SIG_TRACES:  ok = po_otlp_traces(p, (size_t)len, b);  break;
            case PO_SIG_METRICS: ok = po_otlp_metrics(p, (size_t)len, b); break;
            default:             ok = po_otlp_logs(p, (size_t)len, b);    break;
        }
        return ok && !b->err;
    }

    {
        dSP;
        int count, rc = 0;
        SV *doc;
        ENTER; SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(body);
        PUTBACK;
        count = call_pv("File::Raw::JSON::file_json_decode", G_SCALAR | G_EVAL);
        SPAGAIN;
        doc = count ? POPs : &PL_sv_undef;
        PUTBACK;

        if (SvTRUE(ERRSV)) {
            *errmsg = po_trim_die(aTHX_ ERRSV);
        }
        else if (!SvROK(doc) || SvTYPE(SvRV(doc)) != SVt_PVHV) {
            *errmsg = newSVpvs("not a JSON object");
        }
        else {
            switch (sig) {
                case PO_SIG_TRACES:  po_json_traces(aTHX_ doc, b);  break;
                case PO_SIG_METRICS: po_json_metrics(aTHX_ doc, b); break;
                default:             po_json_logs(aTHX_ doc, b);    break;
            }
            rc = !b->err;
        }
        FREETMPS; LEAVE;
        return rc;
    }
}

/* --- the request ---------------------------------------------------------- */

static SV *po_ingest_call(pTHX_ po_ingest *ing, SV *envrv) {
    HV *env;
    SV **e;
    SV *tenant = NULL;
    SV *body = NULL;
    SV *why = NULL;
    SV *errmsg = NULL;
    po_batch b;
    int sig, enc;
    po_u64 n, rejected = 0;
    SV *res;

    if (!SvROK(envrv) || SvTYPE(SvRV(envrv)) != SVt_PVHV)
        croak("Punk::Observe::Ingest::call: the PSGI environment must be a hashref");
    env = (HV *)SvRV(envrv);

    e = hv_fetchs(env, "PATH_INFO", 0);
    {
        STRLEN l = 0;
        const char *p = "";
        if (e && SvOK(*e)) p = SvPV(*e, l);
        sig = po_signal_of(p, (size_t)l);
    }
    if (!sig) return po_err(aTHX_ 404, "not an OTLP endpoint", NULL, NULL);

    e = hv_fetchs(env, "REQUEST_METHOD", 0);
    {
        STRLEN l = 0;
        const char *p = "";
        if (e && SvOK(*e)) p = SvPV(*e, l);
        if (!(l == 4 && memcmp(p, "POST", 4) == 0))
            return po_err(aTHX_ 405, "POST only", NULL, NULL);
    }

    /* Auth first, so an unauthenticated caller cannot make the server spend
     * anything on decoding. The resolver returns a tenant id or undef; the
     * engine's default resolver is absent entirely, which is what makes "no
     * key on a private network" a supported configuration rather than a
     * hole. A resolver that dies is a 401, not a 500. */
    if (ing->auth) {
        dSP;
        int count;
        ENTER; SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(envrv);
        PUTBACK;
        count = call_sv(ing->auth, G_SCALAR | G_EVAL);
        SPAGAIN;
        {
            SV *r = count ? POPs : &PL_sv_undef;
            if (SvOK(r)) tenant = newSVsv(r);
        }
        PUTBACK;
        if (SvTRUE(ERRSV)) { SvREFCNT_dec(tenant); tenant = NULL; }
        FREETMPS; LEAVE;

        if (tenant) {
            STRLEN tl;
            (void)SvPV(tenant, tl);
            if (!tl) { SvREFCNT_dec(tenant); tenant = NULL; }
        }
        if (!tenant) return po_err(aTHX_ 401, "unauthorized", NULL, NULL);
    }
    else tenant = newSVpvs("default");

    {
        char ct[128];
        size_t ctlen = 0;
        e = hv_fetchs(env, "CONTENT_TYPE", 0);
        if (e && SvOK(*e)) {
            STRLEN l;
            const char *p;
            p = SvPV(*e, l);
            ctlen = po_ctype_norm(p, (size_t)l, ct, sizeof(ct));
        }
        else ct[0] = '\0';
        enc = po_enc_of(ct, ctlen);
        if (!enc) {
            SV *m = newSVpvs("unsupported content type '");
            sv_catpvn(m, ct, (STRLEN)ctlen);
            sv_catpvs(m, "'");
            SvREFCNT_dec(tenant);
            res = po_err(aTHX_ 415, SvPV_nolen(m), NULL, NULL);
            SvREFCNT_dec(m);
            return res;
        }
    }

    if (!po_read_body(aTHX_ ing, env, &body, &why)) {
        SvREFCNT_dec(tenant);
        if (why) {
            res = po_err(aTHX_ 413, SvPV_nolen(why), NULL, NULL);
            SvREFCNT_dec(why);
            return res;
        }
        return po_err(aTHX_ 400, "no body", NULL, NULL);
    }

    if (!po_batch_init(&b, enc == PO_ENC_PROTOBUF ? 64 : 16)) {
        SvREFCNT_dec(tenant); SvREFCNT_dec(body);
        croak("out of memory");
    }

    if (!po_decode_body(aTHX_ body, sig, enc, &b, &errmsg)) {
        SV *m = newSVpvs("malformed OTLP");
        if (errmsg) { sv_catpvs(m, ": "); sv_catsv(m, errmsg);
                      SvREFCNT_dec(errmsg); }
        po_batch_free(&b);
        SvREFCNT_dec(tenant); SvREFCNT_dec(body);
        res = po_err(aTHX_ 400, SvPV_nolen(m), NULL, NULL);
        SvREFCNT_dec(m);
        return res;
    }

    /* Over the per-batch record cap the excess is REJECTED and reported
     * through partial_success rather than refused with a 4xx. A 4xx makes the
     * exporter re-send the whole batch, forever, at exactly the moment the
     * server is already under pressure. */
    n = (po_u64)b.n;
    if (ing->max_records && n > ing->max_records) {
        rejected = n - ing->max_records;
        n = ing->max_records;
    }

    /* A batch that decodes to zero records is a 200 and no append. An empty
     * frame would carry a nonsense timestamp span, and a reader pruning on it
     * skips exactly the wrong frames. */
    if (n) {
        int stored = 1;
        if (ing->on_batch) {
            dSP;
            int count;
            HV *out = newHV();
            hv_stores(out, "ok",      newSViv(1));
            hv_stores(out, "records", po_u64_to_sv(n));
            hv_stores(out, "rejected", po_u64_to_sv(rejected));
            hv_stores(out, "dropped_bad_trace", newSViv((IV)b.dropped_bad_trace));
            hv_stores(out, "clamped_durations", newSViv((IV)b.clamped_durations));

            stored = 0;
            ENTER; SAVETMPS;
            PUSHMARK(SP);
            XPUSHs(tenant);
            XPUSHs(sv_2mortal(newSVpv(po_signal_name(sig), 0)));
            XPUSHs(body);
            XPUSHs(sv_2mortal(newSVpv(enc == PO_ENC_PROTOBUF ? "protobuf"
                                                             : "json", 0)));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)out)));
            PUTBACK;
            count = call_sv(ing->on_batch, G_SCALAR | G_EVAL);
            SPAGAIN;
            {
                SV *r = count ? POPs : &PL_sv_undef;
                stored = SvTRUE(r) ? 1 : 0;
            }
            PUTBACK;
            if (SvTRUE(ERRSV)) stored = 0;

            /* `out` IS BIDIRECTIONAL. The callback owns the store, so it is
             * the only party that knows how much of the batch the ingest rate
             * limit truncated - and a partial success has to name a number
             * that matches what was actually kept. Reading it back here is
             * what keeps the response honest about the write. */
            if (stored) {
                SV **rj = hv_fetchs(out, "rejected", 0);
                po_u64 back = 0;
                if (rj && SvOK(*rj) && po_sv_to_u64(aTHX_ *rj, &back)
                    && back > rejected) rejected = back;
            }
            FREETMPS; LEAVE;
        }
        if (!stored) {
            po_batch_free(&b);
            SvREFCNT_dec(tenant); SvREFCNT_dec(body);
            /* Retryable: the data is recoverable after a cleanup, and an OTLP
             * client backs off on 503 and drops on 500. */
            return po_err(aTHX_ 503, "store unavailable",
                          "Retry-After", newSViv(1));
        }
    }

    po_batch_free(&b);
    SvREFCNT_dec(tenant);
    SvREFCNT_dec(body);

    /* A full accept is an EMPTY 200, and it must only be sent when it is one. */
    if (!rejected)
        return po_psgi_res(aTHX_ 200,
                           enc == PO_ENC_PROTOBUF ? "application/x-protobuf"
                                                  : "application/json",
                           enc == PO_ENC_PROTOBUF ? newSVpvs("")
                                                  : newSVpvs("{}"),
                           NULL, NULL);

    {
        SV *msg = newSVpvs("rejected ");
        sv_catsv(msg, sv_2mortal(po_u64_to_sv(rejected)));
        sv_catpvs(msg, " over the per-batch limit");

        if (enc == PO_ENC_PROTOBUF) {
            char pb[80];
            STRLEN ml;
            const char *mp;
            size_t o;
            mp = SvPV(msg, ml);
            o = po_partial_success_pb(pb, rejected, mp, (size_t)ml);
            res = po_psgi_res(aTHX_ 200, "application/x-protobuf",
                              newSVpvn(pb, (STRLEN)o), NULL, NULL);
        }
        else {
            /* Emitted here rather than through an encoder. The shape is fixed
             * and the only variable parts are a decimal count and a message
             * this file wrote, so there is nothing to escape - and the key
             * order comes out stable instead of a hash's.
             *
             * Rule 3: a 64-bit count is a STRING in OTLP/JSON. */
            SV *j = newSVpvs("{\"partialSuccess\":{\"");
            sv_catpv(j, po_rejected_field(sig));
            sv_catpvs(j, "\":\"");
            sv_catsv(j, sv_2mortal(po_u64_to_sv(rejected)));
            sv_catpvs(j, "\",\"errorMessage\":\"");
            sv_catsv(j, msg);
            sv_catpvs(j, "\"}}");
            res = po_psgi_res(aTHX_ 200, "application/json", j, NULL, NULL);
        }
        SvREFCNT_dec(msg);
        return res;
    }
}

/* --- the object ----------------------------------------------------------- */

static po_ingest *po_ingest_new(void) {
    po_ingest *ing = (po_ingest *)malloc(sizeof(po_ingest));
    if (!ing) return NULL;
    memset(ing, 0, sizeof(*ing));
    ing->max_body    = (po_u64)16 * 1024 * 1024;
    if (ing->max_body > PO_BODY_MAX) ing->max_body = PO_BODY_MAX;
    ing->max_ratio   = PO_MAX_RATIO;
    ing->max_records = 0;
    return ing;
}

static void po_ingest_free(pTHX_ po_ingest *ing) {
    if (!ing) return;
    SvREFCNT_dec(ing->auth);
    SvREFCNT_dec(ing->on_batch);
    free(ing);
}

static po_ingest *po_ingest_of(pTHX_ SV *self, const char *who) {
    if (!SvROK(self) || !SvIOK(SvRV(self)) || !SvIVX(SvRV(self)))
        croak("%s: not a Punk::Observe::Ingest", who);
    return INT2PTR(po_ingest *, SvIVX(SvRV(self)));
}

/* to_app returns a real CV rather than a Perl closure, with the object hung
 * off it as ext magic: refcounted by perl, so the app holding the coderef is
 * what keeps the engine alive and nothing has to be freed by hand. */
static MGVTBL po_app_vtbl;      /* static: zeroed, and the right member count
                                 * whatever this perl's MGVTBL looks like */

XS_INTERNAL(po_ingest_app_xs);
XS_INTERNAL(po_ingest_app_xs) {
    dXSARGS;
    MAGIC *mg;
    po_ingest *ing;

    if (items != 1) croak("Usage: $app->($env)");
    mg = mg_find((SV *)cv, PERL_MAGIC_ext);
    if (!mg || !mg->mg_obj) croak("Punk::Observe::Ingest: app has no engine");
    ing = po_ingest_of(aTHX_ mg->mg_obj, "app");

    ST(0) = sv_2mortal(po_ingest_call(aTHX_ ing, ST(0)));
    XSRETURN(1);
}

#endif /* PO_INGEST_H */
