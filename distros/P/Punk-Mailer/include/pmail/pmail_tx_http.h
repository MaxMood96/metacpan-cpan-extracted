#ifndef PMAIL_TX_HTTP_H
#define PMAIL_TX_HTTP_H

/* pmail_tx_http.h - the HTTP provider seam, and Resend on it.
 *
 * A provider is a C vtable: a name, a URL, how it authenticates, the JSON
 * it wants, and where its id and its error text live in what it answers.
 * The request itself, the response-to-Result mapping and the attachment
 * cap are shared, so a second provider is the vtable and nothing else.
 *
 * The request goes through Fetch's C ABI (request + a map callback) and
 * the body through File::Raw::JSON's encoder. The answer is NOT decoded
 * as JSON: two string fields are read out of it with a scanner that
 * cannot croak, because a provider answering with something that is not
 * JSON has to become a `failed` Result, never an exception from a decoder. */

typedef struct pmail_provider pmail_provider;
struct pmail_provider {
    const char *name;                                   /* "resend" */
    const char *url;                                    /* the default endpoint */
    void (*auth)(pTHX_ HV *self, AV *hdrs);            /* push name, value pairs */
    SV  *(*payload)(pTHX_ HV *self, HV *spec, pmail_msg *m, SV **refusal);
    const char *id_field;                               /* in a 2xx answer */
    const char *error_field;                            /* in a 4xx/5xx answer */
};

static const char *const PMAIL_HTTP_OPTS[] = {
    "api_key", "timeout", "max_attachment", "url",
};

#define PMAIL_HTTP_TIMEOUT 10.0
#define PMAIL_HTTP_MAX_ATT (8 * 1024 * 1024)

/* ---- a string field out of a JSON text, without a decoder ------------ */

static void pmail_json_unescape_u(pTHX_ SV *out, const char *h)
{
    UV cp = 0;
    int i;
    for (i = 0; i < 4; i++) {
        char c = h[i];
        cp <<= 4;
        if (c >= '0' && c <= '9') cp |= (UV)(c - '0');
        else if (c >= 'a' && c <= 'f') cp |= (UV)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') cp |= (UV)(c - 'A' + 10);
        else { sv_catpvs(out, "?"); return; }
    }
    if (cp >= 0xD800 && cp <= 0xDFFF) { sv_catpvs(out, "?"); return; }   /* a surrogate half */
    {
        U8 buf[UTF8_MAXBYTES + 1];
        U8 *e = uvchr_to_utf8(buf, cp);
        sv_catpvn(out, (const char *)buf, (STRLEN)(e - buf));
    }
}

/* the first "key": "value" in the text, unescaped into a new UTF-8 SV;
 * NULL when absent or not a string */
static SV *pmail_json_field(pTHX_ const char *p, STRLEN n, const char *key)
{
    size_t kl = strlen(key);
    const char *end = p + n, *q = p;
    while (q < end) {
        const char *hit = (const char *)memchr(q, '"', (size_t)(end - q));
        const char *v;
        if (!hit) return NULL;
        q = hit + 1;
        if ((size_t)(end - hit) <= kl + 1 || memcmp(hit + 1, key, kl) != 0
            || hit[kl + 1] != '"') continue;
        v = hit + kl + 2;
        while (v < end && (*v == ' ' || *v == '\t' || *v == '\r' || *v == '\n')) v++;
        if (v >= end || *v != ':') continue;
        v++;
        while (v < end && (*v == ' ' || *v == '\t' || *v == '\r' || *v == '\n')) v++;
        if (v >= end || *v != '"') return NULL;
        v++;
        {
            SV *out = newSVpvs("");
            SvUTF8_on(out);
            while (v < end && *v != '"') {
                if (*v == '\\' && v + 1 < end) {
                    v++;
                    switch (*v) {
                    case 'n': sv_catpvs(out, "\n"); break;
                    case 't': sv_catpvs(out, "\t"); break;
                    case 'r': sv_catpvs(out, "\r"); break;
                    case 'b': sv_catpvs(out, "\b"); break;
                    case 'f': sv_catpvs(out, "\f"); break;
                    case 'u':
                        if (v + 4 < end) { pmail_json_unescape_u(aTHX_ out, v + 1); v += 4; }
                        break;
                    default:  sv_catpvn(out, v, 1); break;
                    }
                }
                else sv_catpvn(out, v, 1);
                v++;
            }
            return out;
        }
    }
    return NULL;
}

/* ---- the request ----------------------------------------------------- */

typedef struct { int ok; int status; SV *body; SV *err; } pmail_http_answer;

/* the map callback: whatever happened, the future resolves to a hashref
 * describing it, so ->get never throws */
static SV *pmail_http_map(pTHX_ int ok, int status, AV *headers, SV *body, SV *err, void *ud)
{
    HV *h = newHV();
    (void)headers; (void)ud;
    (void)hv_stores(h, "ok", newSViv(ok));
    (void)hv_stores(h, "status", newSViv(status));
    (void)hv_stores(h, "body", body ? newSVsv(body) : newSVpvs(""));
    (void)hv_stores(h, "err", err ? newSVsv(err) : newSV(0));
    return newRV_noinc((SV *)h);
}

/* one Fetch agent per transport per process: a forked worker inherits the
 * parent's hash but must not reuse its sockets */
static SV *pmail_http_ua(pTHX_ HV *self)
{
    SV *ua = pmail_hv_get(aTHX_ self, "ua");
    SV *pid = pmail_hv_get(aTHX_ self, "ua_pid");
    if (ua && pid && SvIV(pid) == (IV)getpid()) return ua;
    if (!PM_FETCH)
        croak("Punk::Mailer: the HTTP transports need Fetch with a C ABI of "
              "version 2 or newer (the running Fetch offered %" IVdf ")", PM_FETCH_SEEN);
    ua = PM_FETCH->ua_new(aTHX_ NULL, 0);
    (void)hv_stores(self, "ua", ua);
    (void)hv_stores(self, "ua_pid", newSViv((IV)getpid()));
    return ua;
}

/* POST json to url with the provider's headers; fills the answer */
static void pmail_http_post(pTHX_ HV *self, const pmail_provider *pv, const char *url,
                            SV *json, NV timeout, pmail_http_answer *ans)
{
    SV *ua = pmail_http_ua(aTHX_ self);
    AV *hav = (AV *)sv_2mortal((SV *)newAV());
    fetch_hdr *hdrs;
    SSize_t n, i;
    STRLEN bl; const char *bp = SvPV_const(json, bl);
    SV *future, *got = NULL;

    av_push(hav, newSVpvs("Content-Type")); av_push(hav, newSVpvs("application/json"));
    av_push(hav, newSVpvs("Accept"));       av_push(hav, newSVpvs("application/json"));
    pv->auth(aTHX_ self, hav);
    n = av_len(hav) + 1;
    Newxz(hdrs, n / 2 + 1, fetch_hdr);
    SAVEFREEPV(hdrs);
    for (i = 0; i + 1 < n; i += 2) {
        SV **k = av_fetch(hav, i, 0), **v = av_fetch(hav, i + 1, 0);
        hdrs[i / 2].name = SvPV_const(*k, hdrs[i / 2].nlen);
        hdrs[i / 2].val  = SvPV_const(*v, hdrs[i / 2].vlen);
    }

    future = PM_FETCH->request(aTHX_ ua, "POST", url, hdrs, (int)(n / 2), bp, bl,
                               (double)timeout, 0, pmail_http_map, NULL);
    sv_2mortal(future);
    {
        dSP;
        int count;
        ENTER; SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(future);
        PUTBACK;
        count = call_method("get", G_SCALAR | G_EVAL);
        SPAGAIN;
        if (SvTRUE(ERRSV)) {
            if (count > 0) (void)POPs;
            ans->ok = 0; ans->status = 0; ans->body = NULL;
            ans->err = newSVsv(ERRSV);
        }
        else if (count > 0) {
            got = POPs;
            SvREFCNT_inc_simple_void_NN(got);
        }
        PUTBACK;
        FREETMPS; LEAVE;
    }
    if (got) {
        sv_2mortal(got);
        if (SvROK(got) && SvTYPE(SvRV(got)) == SVt_PVHV) {
            HV *h = (HV *)SvRV(got);
            SV *ok = pmail_hv_get(aTHX_ h, "ok"), *st = pmail_hv_get(aTHX_ h, "status");
            SV *body = pmail_hv_get(aTHX_ h, "body"), *err = pmail_hv_get(aTHX_ h, "err");
            ans->ok = ok ? (int)SvIV(ok) : 0;
            ans->status = st ? (int)SvIV(st) : 0;
            ans->body = body ? newSVsv(body) : NULL;
            ans->err = err ? newSVsv(err) : NULL;
        }
        else {
            ans->ok = 0; ans->status = 0; ans->body = NULL;
            ans->err = newSVpvs("the request resolved to something unexpected");
        }
    }
    if (ans->body) sv_2mortal(ans->body);
    if (ans->err) sv_2mortal(ans->err);
}

/* the answer as a Result: 2xx accepted, 429 and 5xx deferred, any other
 * 4xx rejected, no answer at all failed */
static SV *pmail_http_result(pTHX_ const pmail_provider *pv, const pmail_http_answer *ans)
{
    if (!ans->ok) {
        SV *why = ans->err ? ans->err : NULL;
        return pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, pv->name, NULL,
                                 "%s unreachable: %s", pv->name,
                                 why ? SvPV_nolen(why) : "no response");
    }
    {
        STRLEN bl = 0;
        const char *bp = ans->body ? SvPV_const(ans->body, bl) : "";
        if (ans->status >= 200 && ans->status < 300) {
            SV *id = pmail_json_field(aTHX_ bp, bl, pv->id_field);
            SV *r;
            if (id) sv_2mortal(id);
            r = pmail_result_newf(aTHX_ PMAIL_ST_ACCEPTED, ans->status, NULL, pv->name, id,
                                  "%s accepted the message", pv->name);
            return r;
        }
        else {
            SV *msg = pmail_json_field(aTHX_ bp, bl, pv->error_field);
            const char *status = (ans->status == 429 || ans->status >= 500)
                               ? PMAIL_ST_DEFERRED : PMAIL_ST_REJECTED;
            /* sv_catsv rather than a %s format: the provider's text is a
             * UTF-8 character string and must stay one */
            SV *text = sv_2mortal(newSVpvf("%s answered %d: ", pv->name, ans->status));
            if (msg) { sv_2mortal(msg); sv_catsv(text, msg); }
            else sv_catpvn(text, bp, bl > 200 ? 200 : bl);
            return pmail_result_new(aTHX_ status, ans->status, NULL, text, NULL, pv->name);
        }
    }
}

/* ---- shared constructor and deliver ------------------------------------ */

static SV *pmail_http_new(pTHX_ const char *class, SV *opts_sv, const pmail_provider *pv)
{
    SV *what = sv_2mortal(newSVpvf("the %s transport", pv->name));
    HV *opts = pmail_opts_hv(aTHX_ opts_sv, SvPV_nolen(what));
    HV *self = newHV();
    SV *key, *url;
    NV timeout, maxatt;
    pmail_opts_check(aTHX_ SvPV_nolen(what), opts, PMAIL_HTTP_OPTS, 4);
    key = pmail_opt_str(aTHX_ opts, "api_key", SvPV_nolen(what), 1);
    if (SvCUR(key) == 0) croak("Punk::Mailer: %s needs a non-empty 'api_key'",
                               SvPV_nolen(what));
    url = pmail_opt_str(aTHX_ opts, "url", SvPV_nolen(what), 0);
    timeout = pmail_opt_nv(aTHX_ opts, "timeout", PMAIL_HTTP_TIMEOUT, SvPV_nolen(what));
    maxatt = pmail_opt_nv(aTHX_ opts, "max_attachment", (NV)PMAIL_HTTP_MAX_ATT,
                          SvPV_nolen(what));
    if (timeout <= 0) croak("Punk::Mailer: %s needs a positive 'timeout'", SvPV_nolen(what));
    if (!PM_FRJ)
        croak("Punk::Mailer: %s needs File::Raw::JSON with a C ABI of version %d or newer",
              SvPV_nolen(what), FRJ_ABI_VERSION);
    (void)pmail_http_ua(aTHX_ self);     /* Fetch is checked now, not at the first send */
    (void)hv_stores(self, "api_key", key);
    (void)hv_stores(self, "url", url ? url : newSVpv(pv->url, 0));
    (void)hv_stores(self, "timeout", newSVnv(timeout));
    (void)hv_stores(self, "max_attachment", newSVnv(maxatt));
    (void)hv_stores(self, "provider", newSVpv(pv->name, 0));
    return pmail_bless(aTHX_ self, class);
}

static SV *pmail_http_deliver(pTHX_ SV *self_sv, SV *spec_sv, const pmail_provider *pv)
{
    HV *self = pmail_self(aTHX_ self_sv, "deliver");
    HV *spec = pmail_spec_hv(aTHX_ spec_sv, "deliver");
    pmail_msg m;
    SV *payload, *json, *refusal = NULL, *result;
    pmail_http_answer ans;
    NV timeout;

    pmail_msg_read(aTHX_ spec, &m);
    payload = pv->payload(aTHX_ self, spec, &m, &refusal);
    if (refusal) {
        sv_2mortal(refusal);
        return pmail_result_new(aTHX_ PMAIL_ST_REJECTED, 0, NULL, refusal, NULL, pv->name);
    }
    sv_2mortal(payload);
    json = sv_2mortal(PM_FRJ->encode(aTHX_ payload, NULL));
    timeout = SvNV(pmail_hv_get(aTHX_ self, "timeout"));
    memset(&ans, 0, sizeof ans);
    pmail_http_post(aTHX_ self, pv, SvPV_nolen(pmail_hv_get(aTHX_ self, "url")),
                    json, timeout, &ans);
    result = pmail_http_result(aTHX_ pv, &ans);
    return result;
}

/* ---- Resend -------------------------------------------------------------- */

static void pmail_resend_auth(pTHX_ HV *self, AV *hdrs)
{
    SV *key = pmail_hv_get(aTHX_ self, "api_key");
    SV *v = newSVpvs("Bearer ");
    sv_catsv(v, key);
    av_push(hdrs, newSVpvs("Authorization"));
    av_push(hdrs, v);
}

/* a string in the payload is a character string: frj encodes it as UTF-8 */
static SV *pmail_json_str(pTHX_ SV *sv)
{
    STRLEN n; const char *p = SvPVutf8(sv, n);
    SV *out = newSVpvn(p, n);
    SvUTF8_on(out);
    return out;
}

/* Resend's JSON: from, to[], cc[], bcc[], reply_to[], subject, text, html,
 * headers{}, attachments[{ filename, content (base64), content_type }]. An
 * attachment is read whole here - the API wants one base64 string - which
 * is the one place a path attachment is held in memory, so it is capped. */
static SV *pmail_resend_payload(pTHX_ HV *self, HV *spec, pmail_msg *m, SV **refusal)
{
    HV *h = newHV();
    SV *ref = newRV_noinc((SV *)h);
    NV maxatt = SvNV(pmail_hv_get(aTHX_ self, "max_attachment"));
    AV *fromp = (AV *)SvRV(*av_fetch(m->from, 0, 0));
    int i;

    (void)spec;
    (void)hv_stores(h, "from", pmail_addr_plain(aTHX_ *av_fetch(fromp, 0, 0),
                                                *av_fetch(fromp, 1, 0)));
    if (av_len(m->to) >= 0)
        (void)hv_stores(h, "to", newRV_noinc((SV *)pmail_addr_plain_list(aTHX_ m->to)));
    if (av_len(m->cc) >= 0)
        (void)hv_stores(h, "cc", newRV_noinc((SV *)pmail_addr_plain_list(aTHX_ m->cc)));
    if (av_len(m->bcc) >= 0)
        (void)hv_stores(h, "bcc", newRV_noinc((SV *)pmail_addr_plain_list(aTHX_ m->bcc)));
    if (av_len(m->reply_to) >= 0)
        (void)hv_stores(h, "reply_to",
                        newRV_noinc((SV *)pmail_addr_plain_list(aTHX_ m->reply_to)));
    (void)hv_stores(h, "subject", pmail_json_str(aTHX_ m->subject));
    if (m->text) (void)hv_stores(h, "text", pmail_json_str(aTHX_ m->text));
    if (m->html) (void)hv_stores(h, "html", pmail_json_str(aTHX_ m->html));
    if (m->headers) {
        HV *hh = newHV();
        HE *he;
        hv_iterinit(m->headers);
        while ((he = hv_iternext(m->headers)))
            (void)hv_store_ent(hh, hv_iterkeysv(he), pmail_json_str(aTHX_ HeVAL(he)), 0);
        (void)hv_stores(h, "headers", newRV_noinc((SV *)hh));
    }
    if (m->natts) {
        AV *atts = newAV();
        (void)hv_stores(h, "attachments", newRV_noinc((SV *)atts));
        for (i = 0; i < m->natts; i++) {
            pmail_att *a = &m->atts[i];
            HV *one = newHV();
            SV *content;
            av_push(atts, newRV_noinc((SV *)one));
            (void)hv_stores(one, "filename", pmail_json_str(aTHX_ a->filename));
            if (a->type) (void)hv_stores(one, "content_type", pmail_json_str(aTHX_ a->type));
            if (a->kind == PMAIL_ATT_CONTENT) {
                STRLEN n; const char *p = SvPV_const(a->src, n);
                if ((NV)n > maxatt) {
                    *refusal = newSVpvf("attachment '%s' is %lu bytes, over the %s "
                                        "transport's max_attachment of %.0" NVff,
                                        SvPV_nolen(a->filename), (unsigned long)n,
                                        "resend", maxatt);
                    SvREFCNT_dec(ref);
                    return NULL;
                }
                content = pmail_b64_plain_sv(aTHX_ (const unsigned char *)p, n);
            }
            else {
                const char *path = SvPV_nolen(a->src);
                struct stat st;
                int fd;
                SV *raw;
                if (stat(path, &st) != 0) {
                    *refusal = newSVpvf("cannot read attachment '%s': %s", path,
                                        strerror(errno));
                    SvREFCNT_dec(ref);
                    return NULL;
                }
                if ((NV)st.st_size > maxatt) {
                    *refusal = newSVpvf("attachment '%s' is %llu bytes, over the resend "
                                        "transport's max_attachment of %.0" NVff,
                                        SvPV_nolen(a->filename),
                                        (unsigned long long)st.st_size, maxatt);
                    SvREFCNT_dec(ref);
                    return NULL;
                }
                fd = open(path, O_RDONLY);
                if (fd < 0) {
                    *refusal = newSVpvf("cannot open attachment '%s': %s", path,
                                        strerror(errno));
                    SvREFCNT_dec(ref);
                    return NULL;
                }
                raw = sv_2mortal(newSV((STRLEN)st.st_size + 1));
                SvPOK_on(raw);
                {
                    STRLEN got = 0;
                    for (;;) {
                        ssize_t r = read(fd, SvPVX(raw) + got, (size_t)st.st_size - got);
                        if (r < 0 && errno == EINTR) continue;
                        if (r <= 0) break;
                        got += (STRLEN)r;
                        if (got >= (STRLEN)st.st_size) break;
                    }
                    close(fd);
                    SvCUR_set(raw, got);
                }
                content = pmail_b64_plain_sv(aTHX_ (const unsigned char *)SvPVX(raw),
                                             SvCUR(raw));
            }
            (void)hv_stores(one, "content", content);
        }
    }
    return ref;
}

static const pmail_provider PMAIL_RESEND = {
    "resend",
    "https://api.resend.com/emails",
    pmail_resend_auth,
    pmail_resend_payload,
    "id",
    "message",
};

#endif /* PMAIL_TX_HTTP_H */
