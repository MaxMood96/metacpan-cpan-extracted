#ifndef PMAIL_MIME_H
#define PMAIL_MIME_H

/* pmail_mime.h - the builder.
 *
 * Reads the message hashref into a struct (every string checked, every
 * address parsed, every unknown key refused), decides the structure and
 * each part's encoding, and writes the bytes through a sink. Nothing is
 * held: a path attachment is read in chunks as it is encoded. */

#define PMAIL_ATT_PATH    0
#define PMAIL_ATT_CONTENT 1

typedef struct {
    int kind;
    SV *src;            /* the path, or the bytes */
    SV *filename;
    SV *type;
} pmail_att;

typedef struct {
    AV *from, *to, *cc, *bcc, *reply_to;    /* lists of [display, addr] */
    SV *subject, *text, *html, *message_id, *msgid_domain;
    HV *headers;                            /* the caller's extra headers */
    pmail_att *atts;
    int natts;
    time_t date;
    SV *forced_boundary;                    /* tests only: _boundary */
} pmail_msg;

/* ---- reading the spec ------------------------------------------------- */

static const char *const PMAIL_SPEC_KEYS[] = {
    "from", "to", "cc", "bcc", "reply_to", "subject", "text", "html",
    "headers", "attachments", "message_id", "message_id_domain", "date",
    "_boundary",
};

/* headers the builder writes itself, and will not take from `headers` */
static const char *const PMAIL_RESERVED[] = {
    "date", "message-id", "mime-version", "content-type",
    "content-transfer-encoding", "content-disposition", "from", "to", "cc",
    "bcc", "subject", "reply-to", "sender", "return-path",
};

/* ASCII case-insensitive equality over n bytes - header names are ASCII
 * by definition, so no locale and no Perl API need be involved */
static int pmail_ieq(const char *a, const char *b, STRLEN n)
{
    STRLEN i;
    for (i = 0; i < n; i++) {
        unsigned char x = (unsigned char)a[i], y = (unsigned char)b[i];
        if (x >= 'A' && x <= 'Z') x += 32;
        if (y >= 'A' && y <= 'Z') y += 32;
        if (x != y) return 0;
    }
    return 1;
}

static int pmail_str_in(const char *p, STRLEN n, const char *const *list, size_t count,
                        int fold)
{
    size_t i;
    for (i = 0; i < count; i++) {
        if (strlen(list[i]) != n) continue;
        if (fold ? pmail_ieq(p, list[i], n) : (memcmp(p, list[i], n) == 0))
            return 1;
    }
    return 0;
}

static SV *pmail_spec_get(pTHX_ HV *spec, const char *key)
{
    SV **p = hv_fetch(spec, key, (I32)strlen(key), 0);
    return (p && *p && SvOK(*p)) ? *p : NULL;
}

/* a string value, checked for header safety, as a new UTF-8 SV */
static SV *pmail_spec_string(pTHX_ HV *spec, const char *key, int required)
{
    SV *v = pmail_spec_get(aTHX_ spec, key);
    STRLEN n;
    const char *p;
    SV *out;
    if (!v) {
        if (required) croak("Punk::Mailer: the message needs a '%s'", key);
        return NULL;
    }
    if (SvROK(v)) croak("Punk::Mailer: '%s' must be a string", key);
    p = pmail_sv_utf8(aTHX_ v, &n);
    out = newSVpvn(p, n);
    SvUTF8_on(out);
    return out;
}

static void pmail_att_from_hv(pTHX_ HV *h, pmail_att *a, int idx)
{
    static const char *const ok[] = { "path", "content", "filename", "type",
                                      "cid", "disposition" };
    HE *he;
    SV *path, *content, *filename, *type;
    hv_iterinit(h);
    while ((he = hv_iternext(h))) {
        STRLEN kl;
        const char *k = HePV(he, kl);
        if (!pmail_str_in(k, kl, ok, 6, 0))
            croak("Punk::Mailer: attachment %d has an unknown key '%.*s'",
                  idx, (int)kl, k);
        if ((kl == 3 && memEQ(k, "cid", 3)) || (kl == 11 && memEQ(k, "disposition", 11)))
            croak("Punk::Mailer: attachment %d: '%.*s' is reserved and not "
                  "supported in this version", idx, (int)kl, k);
    }
    path     = pmail_spec_get(aTHX_ h, "path");
    content  = pmail_spec_get(aTHX_ h, "content");
    filename = pmail_spec_get(aTHX_ h, "filename");
    type     = pmail_spec_get(aTHX_ h, "type");
    if ((path && content) || (!path && !content))
        croak("Punk::Mailer: attachment %d needs exactly one of 'path' and "
              "'content'", idx);
    if (!filename) croak("Punk::Mailer: attachment %d needs a 'filename'", idx);
    a->kind = path ? PMAIL_ATT_PATH : PMAIL_ATT_CONTENT;
    a->src = path ? path : content;
    a->filename = filename;
    a->type = type;
}

/* an object with path/filename/type methods - a Punk::Upload, or anything
 * shaped like one; `path` undef means the bytes are in `content` */
static SV *pmail_call0(pTHX_ SV *obj, const char *method)
{
    dSP;
    SV *ret = NULL;
    int count;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(obj);
    PUTBACK;
    count = call_method(method, G_SCALAR);
    SPAGAIN;
    if (count > 0) { ret = POPs; if (SvOK(ret)) ret = newSVsv(ret); else ret = NULL; }
    PUTBACK;
    FREETMPS; LEAVE;
    if (ret) sv_2mortal(ret);
    return ret;
}

static void pmail_att_from_obj(pTHX_ SV *obj, pmail_att *a, int idx)
{
    SV *path, *filename, *type;
    HV *stash = SvSTASH(SvRV(obj));
    if (!gv_fetchmethod_autoload(stash, "path", 0)
        || !gv_fetchmethod_autoload(stash, "filename", 0))
        croak("Punk::Mailer: attachment %d is an object without path and "
              "filename methods", idx);
    path = pmail_call0(aTHX_ obj, "path");
    filename = pmail_call0(aTHX_ obj, "filename");
    type = gv_fetchmethod_autoload(stash, "type", 0) ? pmail_call0(aTHX_ obj, "type")
                                                    : NULL;
    if (!filename) croak("Punk::Mailer: attachment %d has no filename", idx);
    if (path) { a->kind = PMAIL_ATT_PATH; a->src = path; }
    else {
        SV *content = pmail_call0(aTHX_ obj, "content");
        if (!content) croak("Punk::Mailer: attachment %d has neither a path "
                            "nor content", idx);
        a->kind = PMAIL_ATT_CONTENT; a->src = content;
    }
    a->filename = filename;
    a->type = type;
}

static void pmail_msg_read(pTHX_ HV *spec, pmail_msg *m)
{
    HE *he;
    SV *v;

    memset(m, 0, sizeof *m);

    hv_iterinit(spec);
    while ((he = hv_iternext(spec))) {
        STRLEN kl;
        const char *k = HePV(he, kl);
        if (!pmail_str_in(k, kl, PMAIL_SPEC_KEYS,
                          sizeof PMAIL_SPEC_KEYS / sizeof *PMAIL_SPEC_KEYS, 0))
            croak("Punk::Mailer: unknown message key '%.*s'", (int)kl, k);
    }

    m->from = (AV *)sv_2mortal((SV *)newAV());
    m->to = (AV *)sv_2mortal((SV *)newAV());
    m->cc = (AV *)sv_2mortal((SV *)newAV());
    m->bcc = (AV *)sv_2mortal((SV *)newAV());
    m->reply_to = (AV *)sv_2mortal((SV *)newAV());

    pmail_addr_list(aTHX_ "from", pmail_spec_get(aTHX_ spec, "from"), m->from);
    if (av_len(m->from) + 1 != 1)
        croak("Punk::Mailer: the message needs exactly one 'from'");
    pmail_addr_list(aTHX_ "to", pmail_spec_get(aTHX_ spec, "to"), m->to);
    pmail_addr_list(aTHX_ "cc", pmail_spec_get(aTHX_ spec, "cc"), m->cc);
    pmail_addr_list(aTHX_ "bcc", pmail_spec_get(aTHX_ spec, "bcc"), m->bcc);
    pmail_addr_list(aTHX_ "reply_to", pmail_spec_get(aTHX_ spec, "reply_to"),
                    m->reply_to);
    if (av_len(m->to) < 0 && av_len(m->cc) < 0 && av_len(m->bcc) < 0)
        croak("Punk::Mailer: the message needs a recipient in 'to', 'cc' or 'bcc'");

    m->subject = sv_2mortal(pmail_spec_string(aTHX_ spec, "subject", 1));
    {
        STRLEN n; const char *p = SvPV_const(m->subject, n);
        pmail_hdr_assert_clean(aTHX_ "subject", p, n);
    }
    m->text = pmail_spec_string(aTHX_ spec, "text", 0);
    if (m->text) sv_2mortal(m->text);
    m->html = pmail_spec_string(aTHX_ spec, "html", 0);
    if (m->html) sv_2mortal(m->html);
    if (!m->text && !m->html)
        croak("Punk::Mailer: the message needs a 'text' or an 'html' body");

    m->message_id = pmail_spec_string(aTHX_ spec, "message_id", 0);
    if (m->message_id) {
        STRLEN n; const char *p = SvPV_const(m->message_id, n);
        sv_2mortal(m->message_id);
        pmail_hdr_assert_clean(aTHX_ "message_id", p, n);
        if (n < 3 || p[0] != '<' || p[n - 1] != '>' || !memchr(p, '@', n))
            croak("Punk::Mailer: message_id must look like <id@domain>");
    }
    m->msgid_domain = pmail_spec_string(aTHX_ spec, "message_id_domain", 0);
    if (m->msgid_domain) {
        STRLEN n; const char *p = SvPV_const(m->msgid_domain, n);
        sv_2mortal(m->msgid_domain);
        pmail_hdr_assert_clean(aTHX_ "message_id_domain", p, n);
    }
    m->forced_boundary = pmail_spec_string(aTHX_ spec, "_boundary", 0);
    if (m->forced_boundary) sv_2mortal(m->forced_boundary);

    v = pmail_spec_get(aTHX_ spec, "date");
    m->date = v ? (time_t)SvNV(v) : time(NULL);

    v = pmail_spec_get(aTHX_ spec, "headers");
    if (v) {
        if (!SvROK(v) || SvTYPE(SvRV(v)) != SVt_PVHV)
            croak("Punk::Mailer: 'headers' must be a hashref");
        m->headers = (HV *)SvRV(v);
        hv_iterinit(m->headers);
        while ((he = hv_iternext(m->headers))) {
            STRLEN kl, vl;
            const char *k = HePV(he, kl);
            SV *hv_ = HeVAL(he);
            const char *hp;
            if (!pmail_hdr_name_ok(k, kl))
                croak("Punk::Mailer: '%.*s' is not a header name", (int)kl, k);
            if (pmail_str_in(k, kl, PMAIL_RESERVED,
                             sizeof PMAIL_RESERVED / sizeof *PMAIL_RESERVED, 1))
                croak("Punk::Mailer: header '%.*s' is generated by the builder "
                      "and cannot be supplied", (int)kl, k);
            if (!hv_ || !SvOK(hv_) || SvROK(hv_))
                croak("Punk::Mailer: header '%.*s' must be a string", (int)kl, k);
            hp = pmail_sv_utf8(aTHX_ hv_, &vl);
            pmail_hdr_assert_clean(aTHX_ k, hp, vl);
        }
    }

    v = pmail_spec_get(aTHX_ spec, "attachments");
    if (v) {
        AV *list;
        SSize_t i, n;
        if (!SvROK(v) || SvTYPE(SvRV(v)) != SVt_PVAV)
            croak("Punk::Mailer: 'attachments' must be an arrayref");
        list = (AV *)SvRV(v);
        n = av_len(list) + 1;
        if (n) {
            Newxz(m->atts, n, pmail_att);
            SAVEFREEPV(m->atts);
            m->natts = (int)n;
        }
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(list, i, 0);
            pmail_att *a = &m->atts[i];
            STRLEN fl;
            const char *fp;
            if (!e || !*e || !SvROK(*e))
                croak("Punk::Mailer: attachment %d must be a hashref or an object",
                      (int)i);
            if (sv_isobject(*e)) pmail_att_from_obj(aTHX_ *e, a, (int)i);
            else if (SvTYPE(SvRV(*e)) == SVt_PVHV)
                pmail_att_from_hv(aTHX_ (HV *)SvRV(*e), a, (int)i);
            else croak("Punk::Mailer: attachment %d must be a hashref or an object",
                       (int)i);
            fp = pmail_sv_utf8(aTHX_ a->filename, &fl);
            pmail_hdr_assert_clean(aTHX_ "attachment filename", fp, fl);
            if (fl == 0) croak("Punk::Mailer: attachment %d has an empty filename",
                               (int)i);
            if (a->type) {
                STRLEN tl; const char *tp = SvPV_const(a->type, tl);
                pmail_hdr_assert_clean(aTHX_ "attachment type", tp, tl);
            }
        }
    }
}

/* ---- the envelope ------------------------------------------------------ */

static void pmail_env_push(pTHX_ AV *to, AV *list)
{
    SSize_t i, n = av_len(list) + 1;
    for (i = 0; i < n; i++) {
        AV *pair = (AV *)SvRV(*av_fetch(list, i, 0));
        SV *addr = *av_fetch(pair, 1, 0);
        SSize_t j, m = av_len(to) + 1;
        int seen = 0;
        for (j = 0; j < m; j++)
            if (sv_eq(*av_fetch(to, j, 0), addr)) { seen = 1; break; }
        if (!seen) av_push(to, newSVsv(addr));
    }
}

static HV *pmail_envelope(pTHX_ HV *spec)
{
    pmail_msg m;
    HV *env = newHV();
    AV *to = newAV();
    AV *fp;
    pmail_msg_read(aTHX_ spec, &m);
    fp = (AV *)SvRV(*av_fetch(m.from, 0, 0));
    (void)hv_stores(env, "from", newSVsv(*av_fetch(fp, 1, 0)));
    pmail_env_push(aTHX_ to, m.to);
    pmail_env_push(aTHX_ to, m.cc);
    pmail_env_push(aTHX_ to, m.bcc);
    (void)hv_stores(env, "to", newRV_noinc((SV *)to));
    return env;
}

/* ---- writing ------------------------------------------------------------ */

#define PMAIL_7BIT   0
#define PMAIL_QP     1
#define PMAIL_BASE64 2

static int pmail_sink_sv_put(pTHX_ pmail_sink *s, SV *sv)
{
    STRLEN n; const char *p = SvPV_const(sv, n);
    return pmail_put(s, p, n);
}

/* which encoding a text part gets, from one scan of it - and never 7bit
 * for a body that contains the boundary, which is the one place 7bit text
 * could break the structure */
static int pmail_text_mode(const char *p, STRLEN n, const char *b1, const char *b2)
{
    pmail_text_scan sc;
    pmail_scan_text((const unsigned char *)p, n, &sc);
    if (!sc.has_8bit && !sc.has_nul && sc.longest_line <= PMAIL_MAX_LINE) {
        if (b1 && n >= strlen(b1) && strstr(p, b1)) return PMAIL_QP;
        if (b2 && n >= strlen(b2) && strstr(p, b2)) return PMAIL_QP;
        return PMAIL_7BIT;
    }
    if (sc.has_nul) return PMAIL_BASE64;
    return (sc.printable * 3 >= n * 2) ? PMAIL_QP : PMAIL_BASE64;
}

/* bare LF and bare CR become CRLF; CRLF stays */
static void pmail_normalise_crlf(pTHX_ SV *out, const char *p, STRLEN n)
{
    STRLEN i, start = 0;
    for (i = 0; i < n; i++) {
        if (p[i] == '\r') {
            sv_catpvn(out, p + start, i - start);
            sv_catpvs(out, PMAIL_CRLF);
            if (i + 1 < n && p[i + 1] == '\n') i++;
            start = i + 1;
        }
        else if (p[i] == '\n') {
            sv_catpvn(out, p + start, i - start);
            sv_catpvs(out, PMAIL_CRLF);
            start = i + 1;
        }
    }
    sv_catpvn(out, p + start, n - start);
}

static int pmail_write_text_part(pTHX_ pmail_sink *s, SV *body, const char *ctype,
                                 const char *b1, const char *b2, int toplevel)
{
    STRLEN n; const char *p = SvPV_const(body, n);
    int mode = pmail_text_mode(p, n, b1, b2);
    SV *hdr = sv_2mortal(newSVpvs(""));
    sv_catpvf(hdr, "Content-Type: %s; charset=utf-8" PMAIL_CRLF
                   "Content-Transfer-Encoding: %s" PMAIL_CRLF PMAIL_CRLF,
              ctype, mode == PMAIL_7BIT ? "7bit"
                   : mode == PMAIL_QP   ? "quoted-printable" : "base64");
    (void)toplevel;
    if (pmail_sink_sv_put(aTHX_ s, hdr) != 0) return -1;
    if (mode == PMAIL_BASE64) {
        pmail_b64_st st;
        pmail_b64_init(&st, 1);
        if (pmail_b64_update(&st, (const unsigned char *)p, n, s) != 0) return -1;
        return pmail_b64_final(&st, s);
    }
    else {
        SV *norm = sv_2mortal(newSVpvs(""));
        STRLEN nn; const char *np;
        pmail_normalise_crlf(aTHX_ norm, p, n);
        np = SvPV_const(norm, nn);
        if (mode == PMAIL_QP) return pmail_qp_encode((const unsigned char *)np, nn, s);
        return pmail_put(s, np, nn);
    }
}

/* The CRLF before a boundary line belongs to the boundary (RFC 2046
 * 5.1.1), so a part's own trailing line break would be eaten by a reader
 * if the boundary followed it directly. Every boundary after the first
 * is therefore preceded by its own CRLF, and a part's bytes are exactly
 * what was given. The top-level single-part message has no boundary and
 * ends with its body as it is. */
static int pmail_put_boundary(pTHX_ pmail_sink *s, SV *line, int first)
{
    if (!first && PMAIL_PUTS(s, PMAIL_CRLF) != 0) return -1;
    return pmail_sink_sv_put(aTHX_ s, line);
}

/* Content-Type and Content-Disposition for an attachment. The filename is
 * a quoted-string when it is ASCII, and an RFC 2231 filename* when it is
 * not, with an ASCII stand-in beside it for readers that predate 2231. */
static void pmail_att_headers(pTHX_ SV *out, const pmail_att *a)
{
    STRLEN fl, i;
    const char *fp = pmail_sv_utf8(aTHX_ a->filename, &fl);
    SV *quoted = sv_2mortal(newSVpvs("\""));
    SV *ext = NULL;
    int ascii = pmail_is_ascii(fp, fl);
    for (i = 0; i < fl; i++) {
        unsigned char c = (unsigned char)fp[i];
        if (c >= 0xC0) { sv_catpvs(quoted, "_"); continue; }   /* one per character */
        if (c >= 0x80) continue;                               /* a continuation byte */
        if (c == '"' || c == '\\') sv_catpvs(quoted, "\\");
        sv_catpvn(quoted, fp + i, 1);
    }
    sv_catpvs(quoted, "\"");
    if (!ascii) {
        ext = sv_2mortal(newSVpvs("UTF-8''"));
        for (i = 0; i < fl; i++) {
            unsigned char c = (unsigned char)fp[i];
            if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
                || (c >= '0' && c <= '9') || c == '.' || c == '-' || c == '_')
                sv_catpvn(ext, fp + i, 1);
            else sv_catpvf(ext, "%%%c%c", PMAIL_HEX[c >> 4], PMAIL_HEX[c & 15]);
        }
    }
    sv_catpvs(out, "Content-Type: ");
    if (a->type) sv_catsv(out, a->type); else sv_catpvs(out, "application/octet-stream");
    sv_catpvs(out, ";" PMAIL_CRLF " name=");
    sv_catsv(out, quoted);
    if (ext) { sv_catpvs(out, ";" PMAIL_CRLF " name*="); sv_catsv(out, ext); }
    sv_catpvs(out, PMAIL_CRLF "Content-Disposition: attachment;" PMAIL_CRLF " filename=");
    sv_catsv(out, quoted);
    if (ext) { sv_catpvs(out, ";" PMAIL_CRLF " filename*="); sv_catsv(out, ext); }
    sv_catpvs(out, PMAIL_CRLF "Content-Transfer-Encoding: base64" PMAIL_CRLF PMAIL_CRLF);
}

/* 1024 x 57 input bytes: every chunk encodes to whole 76-column lines */
#define PMAIL_ATT_CHUNK 58368

static void pmail_close_fd(pTHX_ void *p) { close((int)PTR2IV(p)); }

/* Sizing mode: the SMTP transport announces the message size before a
 * byte of it is sent (SIZE=), and the size of a path attachment is known
 * from stat and arithmetic without reading the file. When this is set the
 * builder writes the encoded length of a path attachment into the sink as
 * a count with no bytes behind it - only the counting sink, which reads
 * nothing, is ever paired with it. */
static int PMAIL_SIZING = 0;

static int pmail_write_attachment(pTHX_ pmail_sink *s, const pmail_att *a)
{
    SV *hdr = sv_2mortal(newSVpvs(""));
    pmail_b64_st st;
    pmail_att_headers(aTHX_ hdr, a);
    if (pmail_sink_sv_put(aTHX_ s, hdr) != 0) return -1;
    if (PMAIL_SIZING && a->kind == PMAIL_ATT_PATH) {
        const char *path = SvPV_nolen(a->src);
        struct stat stt;
        pmail_u64 enc;
        if (stat(path, &stt) != 0)
            croak("Punk::Mailer: cannot stat attachment '%s': %s", path, strerror(errno));
        enc = pmail_b64_wrapped_len((pmail_u64)stt.st_size);
        while (enc) {
            size_t step = enc > ((pmail_u64)1 << 30) ? ((size_t)1 << 30) : (size_t)enc;
            if (s->write(s, NULL, step) != 0) return -1;
            enc -= step;
        }
        return 0;
    }
    pmail_b64_init(&st, 1);
    if (a->kind == PMAIL_ATT_CONTENT) {
        STRLEN n; const char *p = SvPV_const(a->src, n);
        if (pmail_b64_update(&st, (const unsigned char *)p, n, s) != 0) return -1;
    }
    else {
        STRLEN pl; const char *path = SvPV_const(a->src, pl);
        int fd = open(path, O_RDONLY);
        unsigned char *buf;
        if (fd < 0)
            croak("Punk::Mailer: cannot open attachment '%s': %s", path,
                  strerror(errno));
        ENTER;
        SAVEDESTRUCTOR_X(pmail_close_fd, INT2PTR(void *, (IV)fd));
        Newx(buf, PMAIL_ATT_CHUNK, unsigned char);
        SAVEFREEPV(buf);
        for (;;) {
            ssize_t r = read(fd, buf, PMAIL_ATT_CHUNK);
            if (r < 0) {
                if (errno == EINTR) continue;
                croak("Punk::Mailer: cannot read attachment '%s': %s", path,
                      strerror(errno));
            }
            if (r == 0) break;
            if (pmail_b64_update(&st, buf, (size_t)r, s) != 0) { LEAVE; return -1; }
        }
        LEAVE;
    }
    return pmail_b64_final(&st, s);
}

static void pmail_boundary(pTHX_ char *out, size_t size, SV *forced, int which)
{
    char token[25];
    if (forced) {
        STRLEN n; const char *p = SvPV_const(forced, n);
        snprintf(out, size, "%.*s%s", (int)n, p, which ? "-2" : "");
        return;
    }
    if (pmail_random_token(token, 24) != 0)
        croak("Punk::Mailer: no entropy available for a MIME boundary");
    snprintf(out, size, "=_pm_%s", token);
}

static int pmail_build(pTHX_ HV *spec, pmail_sink *s)
{
    pmail_msg m;
    SV *hdr = sv_2mortal(newSVpvs(""));
    SV *val;
    char date[64];
    char b1[40] = "", b2[40] = "";
    int alt, mixed;
    HE *he;

    pmail_msg_read(aTHX_ spec, &m);
    alt = (m.text && m.html);
    mixed = (m.natts > 0);
    if (mixed) pmail_boundary(aTHX_ b1, sizeof b1, m.forced_boundary, 0);
    if (alt) pmail_boundary(aTHX_ b2, sizeof b2, m.forced_boundary, mixed ? 1 : 0);

    /* the address headers */
    val = sv_2mortal(pmail_addr_header_value(aTHX_ m.from));
    pmail_hdr_fold_sv(aTHX_ hdr, "From", val);
    if (av_len(m.to) >= 0) {
        val = sv_2mortal(pmail_addr_header_value(aTHX_ m.to));
        pmail_hdr_fold_sv(aTHX_ hdr, "To", val);
    }
    if (av_len(m.cc) >= 0) {
        val = sv_2mortal(pmail_addr_header_value(aTHX_ m.cc));
        pmail_hdr_fold_sv(aTHX_ hdr, "Cc", val);
    }
    if (av_len(m.reply_to) >= 0) {
        val = sv_2mortal(pmail_addr_header_value(aTHX_ m.reply_to));
        pmail_hdr_fold_sv(aTHX_ hdr, "Reply-To", val);
    }
    {
        STRLEN n; const char *p = SvPV_const(m.subject, n);
        val = sv_2mortal(newSVpvs(""));
        pmail_hdr_unstructured(aTHX_ val, p, n);
        pmail_hdr_fold_sv(aTHX_ hdr, "Subject", val);
    }
    pmail_hdr_date(date, sizeof date, m.date);
    sv_catpvf(hdr, "Date: %s" PMAIL_CRLF, date);
    if (m.message_id) {
        sv_catpvs(hdr, "Message-ID: "); sv_catsv(hdr, m.message_id);
        sv_catpvs(hdr, PMAIL_CRLF);
    }
    else {
        STRLEN dl; const char *dp;
        SV *mid;
        if (m.msgid_domain) dp = SvPV_const(m.msgid_domain, dl);
        else {
            AV *pair = (AV *)SvRV(*av_fetch(m.from, 0, 0));
            STRLEN al; const char *ap = SvPV_const(*av_fetch(pair, 1, 0), al);
            const char *at = (const char *)memchr(ap, '@', al);
            dp = at + 1; dl = al - (STRLEN)(at + 1 - ap);
        }
        mid = sv_2mortal(pmail_hdr_message_id(aTHX_ dp, dl, m.date));
        sv_catpvs(hdr, "Message-ID: "); sv_catsv(hdr, mid); sv_catpvs(hdr, PMAIL_CRLF);
    }
    sv_catpvs(hdr, "MIME-Version: 1.0" PMAIL_CRLF);

    /* the caller's headers, in a deterministic order */
    if (m.headers) {
        AV *names = (AV *)sv_2mortal((SV *)newAV());
        SSize_t i, n;
        hv_iterinit(m.headers);
        while ((he = hv_iternext(m.headers))) av_push(names, newSVsv(hv_iterkeysv(he)));
        sortsv(AvARRAY(names), av_len(names) + 1, Perl_sv_cmp);
        n = av_len(names) + 1;
        for (i = 0; i < n; i++) {
            SV *name = *av_fetch(names, i, 0);
            STRLEN nl, vl;
            const char *np = SvPV_const(name, nl);
            SV **vp = hv_fetch(m.headers, np, (I32)nl, 0);
            const char *v = pmail_sv_utf8(aTHX_ *vp, &vl);
            val = sv_2mortal(newSVpvs(""));
            pmail_hdr_unstructured(aTHX_ val, v, vl);
            {
                STRLEN xl; const char *xp = SvPV_const(val, xl);
                pmail_hdr_fold(aTHX_ hdr, np, nl, xp, xl);
            }
        }
    }

    if (mixed)
        sv_catpvf(hdr, "Content-Type: multipart/mixed; boundary=\"%s\"" PMAIL_CRLF
                       PMAIL_CRLF, b1);
    else if (alt)
        sv_catpvf(hdr, "Content-Type: multipart/alternative; boundary=\"%s\""
                       PMAIL_CRLF PMAIL_CRLF, b2);
    if (pmail_sink_sv_put(aTHX_ s, hdr) != 0) return -1;

    /* the body */
    {
        SV *open1 = sv_2mortal(newSVpvf("--%s" PMAIL_CRLF, b1));
        SV *open2 = sv_2mortal(newSVpvf("--%s" PMAIL_CRLF, b2));
        const char *bb1 = mixed ? b1 : NULL, *bb2 = alt ? b2 : NULL;

        if (mixed && pmail_put_boundary(aTHX_ s, open1, 1) != 0) return -1;
        if (alt) {
            if (mixed) {
                SV *inner = sv_2mortal(newSVpvf(
                    "Content-Type: multipart/alternative; boundary=\"%s\""
                    PMAIL_CRLF PMAIL_CRLF, b2));
                if (pmail_sink_sv_put(aTHX_ s, inner) != 0) return -1;
            }
            if (pmail_put_boundary(aTHX_ s, open2, 1) != 0) return -1;
            if (pmail_write_text_part(aTHX_ s, m.text, "text/plain", bb1, bb2, 0) != 0)
                return -1;
            if (pmail_put_boundary(aTHX_ s, open2, 0) != 0) return -1;
            if (pmail_write_text_part(aTHX_ s, m.html, "text/html", bb1, bb2, 0) != 0)
                return -1;
            {
                SV *close2 = sv_2mortal(newSVpvf("--%s--" PMAIL_CRLF, b2));
                if (pmail_put_boundary(aTHX_ s, close2, 0) != 0) return -1;
            }
        }
        else {
            SV *body = m.text ? m.text : m.html;
            const char *ct = m.text ? "text/plain" : "text/html";
            if (pmail_write_text_part(aTHX_ s, body, ct, bb1, NULL, !mixed) != 0)
                return -1;
        }
        if (mixed) {
            int i;
            for (i = 0; i < m.natts; i++) {
                if (pmail_put_boundary(aTHX_ s, open1, 0) != 0) return -1;
                if (pmail_write_attachment(aTHX_ s, &m.atts[i]) != 0) return -1;
            }
            {
                SV *close1 = sv_2mortal(newSVpvf("--%s--" PMAIL_CRLF, b1));
                if (pmail_put_boundary(aTHX_ s, close1, 0) != 0) return -1;
            }
        }
    }
    return 0;
}

#endif /* PMAIL_MIME_H */
