#ifndef PMAIL_TX_SMTP_H
#define PMAIL_TX_SMTP_H

#include <sys/socket.h>
#include <sys/time.h>
#include <signal.h>

/* pmail_tx_smtp.h - RFC 5321 over Fetch's raw tunnel.
 *
 * Plaintext, STARTTLS on 587, implicit TLS on 465; AUTH PLAIN and LOGIN;
 * SIZE; dot-stuffing; a socket timeout on every read and write. TLS comes
 * from Fetch's client SSL_CTX through the tunnel, so this dist links no
 * OpenSSL. Every outcome is a Result: a server's 4xx is deferred, its
 * 5xx rejected, a lost connection or a failed handshake failed - and the
 * phase it happened in is in the message, because "connection lost" on
 * its own is not something anybody can act on.
 *
 * Two rules the client holds that a lenient one does not:
 *   - STARTTLS is asked for only after the greeting, upgraded only on a
 *     220, and followed by a second EHLO whose answer REPLACES the first:
 *     the capabilities a server announced in plaintext are not trusted.
 *   - credentials are never sent over plaintext unless the transport was
 *     built with insecure_auth, which is checked at new, not at send. */

#define PMAIL_TLS_NONE     0
#define PMAIL_TLS_STARTTLS 1
#define PMAIL_TLS_IMPLICIT 2

static const char *const PMAIL_SMTP_OPTS[] = {
    "host", "port", "tls", "verify", "timeout", "username", "password",
    "insecure_auth", "name",
};

/* ---- the transport object ----------------------------------------------- */

static SV *pmail_smtp_new(pTHX_ const char *class, SV *opts_sv)
{
    HV *opts = pmail_opts_hv(aTHX_ opts_sv, "the smtp transport");
    HV *self = newHV();
    SV *host, *tls, *user, *pass, *name;
    NV port, timeout;
    int tlsmode, verify, insecure;
    SV *v;

    pmail_opts_check(aTHX_ "the smtp transport", opts, PMAIL_SMTP_OPTS,
                     sizeof PMAIL_SMTP_OPTS / sizeof *PMAIL_SMTP_OPTS);
    if (PM_FETCH_SEEN < 3)
        croak("Punk::Mailer: the smtp transport needs Fetch with a C ABI of version 3 "
              "or newer for STARTTLS (the running Fetch offered %" IVdf ")", PM_FETCH_SEEN);

    host = pmail_opt_str(aTHX_ opts, "host", "the smtp transport", 1);
    if (SvCUR(host) == 0) croak("Punk::Mailer: the smtp transport needs a non-empty 'host'");

    tls = pmail_opt_str(aTHX_ opts, "tls", "the smtp transport", 0);
    if (!tls) tlsmode = PMAIL_TLS_STARTTLS;
    else {
        const char *t = SvPV_nolen(tls);
        if (strEQ(t, "starttls")) tlsmode = PMAIL_TLS_STARTTLS;
        else if (strEQ(t, "implicit")) tlsmode = PMAIL_TLS_IMPLICIT;
        else if (strEQ(t, "none")) tlsmode = PMAIL_TLS_NONE;
        else croak("Punk::Mailer: the smtp transport's 'tls' is starttls, implicit or "
                   "none, not '%s'", t);
        SvREFCNT_dec(tls);
    }
    port = pmail_opt_nv(aTHX_ opts, "port",
                        tlsmode == PMAIL_TLS_STARTTLS ? 587 : tlsmode == PMAIL_TLS_IMPLICIT ? 465 : 25,
                        "the smtp transport");
    if (port < 1 || port > 65535 || port != (NV)(IV)port)
        croak("Punk::Mailer: the smtp transport's 'port' must be a port number");
    v = pmail_opt(aTHX_ opts, "verify");
    verify = v ? (SvTRUE(v) ? 1 : 0) : 1;
    timeout = pmail_opt_nv(aTHX_ opts, "timeout", 15.0, "the smtp transport");
    if (timeout <= 0) croak("Punk::Mailer: the smtp transport needs a positive 'timeout'");
    v = pmail_opt(aTHX_ opts, "insecure_auth");
    insecure = v ? (SvTRUE(v) ? 1 : 0) : 0;

    user = pmail_opt_str(aTHX_ opts, "username", "the smtp transport", 0);
    pass = pmail_opt_str(aTHX_ opts, "password", "the smtp transport", 0);
    if ((user && !pass) || (!user && pass))
        croak("Punk::Mailer: the smtp transport needs 'username' and 'password' "
              "together");
    if (user && tlsmode == PMAIL_TLS_NONE && !insecure)
        croak("Punk::Mailer: the smtp transport will not send a password over "
              "plaintext; use tls => 'starttls' or 'implicit', or say "
              "insecure_auth => 1 to mean it");
    name = pmail_opt_str(aTHX_ opts, "name", "the smtp transport", 0);
    if (name) {
        STRLEN nl; const char *np = SvPV_const(name, nl);
        pmail_hdr_assert_clean(aTHX_ "name", np, nl);
        if (nl == 0 || memchr(np, ' ', nl))
            croak("Punk::Mailer: the smtp transport's 'name' is a host name");
    }

    (void)hv_stores(self, "host", host);
    (void)hv_stores(self, "port", newSViv((IV)port));
    (void)hv_stores(self, "tls", newSVpv(tlsmode == PMAIL_TLS_STARTTLS ? "starttls"
                                        : tlsmode == PMAIL_TLS_IMPLICIT ? "implicit" : "none", 0));
    (void)hv_stores(self, "tlsmode", newSViv(tlsmode));
    (void)hv_stores(self, "verify", newSViv(verify));
    (void)hv_stores(self, "timeout", newSVnv(timeout));
    (void)hv_stores(self, "username", user ? user : newSV(0));
    (void)hv_stores(self, "password", pass ? pass : newSV(0));
    (void)hv_stores(self, "insecure_auth", newSViv(insecure));
    (void)hv_stores(self, "name", name ? name : newSV(0));
    return pmail_bless(aTHX_ self, class);
}

/* ---- the conversation ------------------------------------------------------ */

typedef struct {
    const fetch_abi *a;
    void *h;
    char buf[4096];
    size_t have;                /* bytes read but not yet consumed: the tail
                                 * of one read is the head of the next reply */
    int code;
    char enhanced[16];
    SV *text;                   /* the reply's lines joined with "\n", mortal */
    int cap_starttls, cap_plain, cap_login, cap_size;
    pmail_u64 size_limit;
    const char *phase;
    char last;                  /* the last byte written during DATA */
    struct sigaction old_pipe;  /* SIGPIPE is ignored for the conversation:
                                 * a server that closes mid-DATA must be a
                                 * failed Result, not a dead worker */
    int pipe_saved;
} pmail_smtp;

static void pmail_smtp_close(pTHX_ void *p)
{
    pmail_smtp *c = (pmail_smtp *)p;
    if (c->h) { c->a->tunnel_close(c->h); c->h = NULL; }
    if (c->pipe_saved) { sigaction(SIGPIPE, &c->old_pipe, NULL); c->pipe_saved = 0; }
}

/* one line, CRLF stripped: 0, -1 lost, -2 protocol (a line too long) */
static int pmail_smtp_readline(pmail_smtp *c, char *out, size_t size, size_t *len)
{
    for (;;) {
        char *nl = c->have ? (char *)memchr(c->buf, '\n', c->have) : NULL;
        if (nl) {
            size_t n = (size_t)(nl - c->buf), keep = c->have - (n + 1), cp = n;
            if (cp && c->buf[cp - 1] == '\r') cp--;
            if (cp >= size) return -2;
            memcpy(out, c->buf, cp); out[cp] = 0; *len = cp;
            memmove(c->buf, nl + 1, keep); c->have = keep;
            return 0;
        }
        if (c->have >= sizeof c->buf) return -2;
        {
            IV r = c->a->tunnel_read(c->h, c->buf + c->have, (IV)(sizeof c->buf - c->have));
            if (r <= 0) return -1;
            c->have += (size_t)r;
        }
    }
}

/* a whole reply, continuation lines included: 0, -1 lost, -2 protocol */
static int pmail_smtp_reply(pTHX_ pmail_smtp *c)
{
    char line[1024];
    size_t n;
    int first = 1;
    c->text = sv_2mortal(newSVpvs(""));
    c->enhanced[0] = 0;
    c->code = 0;
    for (;;) {
        int r = pmail_smtp_readline(c, line, sizeof line, &n);
        int code, more;
        const char *text;
        size_t tlen;
        if (r) return r;
        if (n < 3 || line[0] < '2' || line[0] > '5' || line[1] < '0' || line[1] > '9'
            || line[2] < '0' || line[2] > '9')
            return -2;
        code = (line[0] - '0') * 100 + (line[1] - '0') * 10 + (line[2] - '0');
        if (n > 3 && line[3] != '-' && line[3] != ' ') return -2;
        if (first) c->code = code;
        else if (code != c->code) return -2;
        more = (n > 3 && line[3] == '-');
        text = line + (n > 3 ? 4 : 3);
        tlen = n - (n > 3 ? 4 : 3);
        /* an enhanced status code leads the text of the first line when
         * its class digit matches the reply's */
        if (first && tlen >= 5 && text[0] == line[0] && text[1] == '.') {
            size_t i = 0;
            int dots = 0;
            while (i < tlen && i < 15 && ((text[i] >= '0' && text[i] <= '9') || text[i] == '.')) {
                if (text[i] == '.') dots++;
                i++;
            }
            if (dots == 2 && (i == tlen || text[i] == ' ')) {
                memcpy(c->enhanced, text, i); c->enhanced[i] = 0;
                text += i; tlen -= i;
                while (tlen && *text == ' ') { text++; tlen--; }
            }
        }
        if (!first) sv_catpvs(c->text, "\n");
        if (SvCUR(c->text) < 2048) sv_catpvn(c->text, text, tlen);
        first = 0;
        if (!more) return 0;
    }
}

static int pmail_smtp_send(pmail_smtp *c, const char *s, size_t n)
{
    return c->a->tunnel_write_all(c->h, s, (IV)n) == 0 ? 0 : -1;
}

static int pmail_smtp_sendf(pTHX_ pmail_smtp *c, const char *fmt, ...)
{
    SV *line = sv_2mortal(newSVpvs(""));
    va_list ap;
    va_start(ap, fmt);
    sv_vcatpvf(line, fmt, &ap);
    va_end(ap);
    sv_catpvs(line, PMAIL_CRLF);
    return pmail_smtp_send(c, SvPVX(line), SvCUR(line));
}

/* the EHLO answer: one keyword per line after the first */
static void pmail_smtp_caps(pTHX_ pmail_smtp *c)
{
    STRLEN n; const char *p = SvPV_const(c->text, n);
    const char *end = p + n;
    const char *line = (const char *)memchr(p, '\n', n);
    c->cap_starttls = c->cap_plain = c->cap_login = c->cap_size = 0;
    c->size_limit = 0;
    line = line ? line + 1 : end;
    while (line < end) {
        const char *eol = (const char *)memchr(line, '\n', (size_t)(end - line));
        size_t ll = eol ? (size_t)(eol - line) : (size_t)(end - line);
        if (ll >= 8 && pmail_ieq(line, "STARTTLS", 8) && (ll == 8 || line[8] == ' '))
            c->cap_starttls = 1;
        else if (ll >= 4 && pmail_ieq(line, "SIZE", 4) && (ll == 4 || line[4] == ' ')) {
            c->cap_size = 1;
            if (ll > 5) c->size_limit = (pmail_u64)strtoull(line + 5, NULL, 10);
        }
        else if (ll >= 4 && pmail_ieq(line, "AUTH", 4) && (ll == 4 || line[4] == ' ' || line[4] == '=')) {
            const char *q = line + 4, *qe = line + ll;
            while (q < qe) {
                const char *sp;
                while (q < qe && (*q == ' ' || *q == '=')) q++;
                sp = q;
                while (q < qe && *q != ' ') q++;
                if (q - sp == 5 && pmail_ieq(sp, "PLAIN", 5)) c->cap_plain = 1;
                if (q - sp == 5 && pmail_ieq(sp, "LOGIN", 5)) c->cap_login = 1;
            }
        }
        if (!eol) break;
        line = eol + 1;
    }
}

/* ---- Results -------------------------------------------------------------- */

static SV *pmail_smtp_lost(pTHX_ pmail_smtp *c, int r, SV *id)
{
    if (r == -2)
        return pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "smtp", id,
                                 "protocol error during %s: the server's reply could "
                                 "not be read as SMTP", c->phase);
    return pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "smtp", id,
                             "timeout or connection lost during %s", c->phase);
}

/* the server said no: 4xx deferred, 5xx rejected, anything else protocol */
static SV *pmail_smtp_refused(pTHX_ pmail_smtp *c, SV *id)
{
    const char *st = c->code >= 500 ? PMAIL_ST_REJECTED
                   : c->code >= 400 ? PMAIL_ST_DEFERRED : PMAIL_ST_FAILED;
    SV *text = sv_2mortal(newSVpvf("%s: %d ", c->phase, c->code));
    sv_catsv(text, c->text);
    return pmail_result_new(aTHX_ st, c->code, c->enhanced[0] ? c->enhanced : NULL,
                            text, id, "smtp");
}

/* the DATA stream: a sink onto the tunnel that remembers the last byte */
static int pmail_sink_smtp_write(pmail_sink *s, const char *p, size_t n)
{
    pmail_smtp *c = (pmail_smtp *)s->ud;
    if (n == 0) return 0;
    if (c->a->tunnel_write_all(c->h, p, (IV)n) != 0) return -1;
    c->last = p[n - 1];
    return 0;
}

#define PMAIL_SMTP_STEP(phase_name, expect)                                   \
    do {                                                                      \
        c.phase = (phase_name);                                               \
        r = pmail_smtp_reply(aTHX_ &c);                                       \
        if (r) { result = pmail_smtp_lost(aTHX_ &c, r, id); goto done; }      \
        if (!(expect)) { result = pmail_smtp_refused(aTHX_ &c, id); goto quit; } \
    } while (0)

static SV *pmail_smtp_deliver(pTHX_ SV *self_sv, SV *spec_sv, SV *env_sv)
{
    HV *self = pmail_self(aTHX_ self_sv, "deliver");
    HV *spec = pmail_spec_hv(aTHX_ spec_sv, "deliver");
    HV *env = pmail_spec_hv(aTHX_ env_sv, "deliver");
    const char *host = SvPV_nolen(pmail_hv_get(aTHX_ self, "host"));
    int port = (int)SvIV(pmail_hv_get(aTHX_ self, "port"));
    int tlsmode = (int)SvIV(pmail_hv_get(aTHX_ self, "tlsmode"));
    int verify = (int)SvIV(pmail_hv_get(aTHX_ self, "verify"));
    NV timeout = SvNV(pmail_hv_get(aTHX_ self, "timeout"));
    SV *user = pmail_hv_get(aTHX_ self, "username");
    SV *pass = pmail_hv_get(aTHX_ self, "password");
    SV *name = pmail_hv_get(aTHX_ self, "name");
    SV *from = pmail_env_from(aTHX_ env);
    AV *rcpts = pmail_env_to(aTHX_ env);
    SSize_t nr = av_len(rcpts) + 1, i;
    int *rcodes;
    SV **rtexts;
    int accepted_rcpts = 0, all_temp = 1;
    pmail_smtp c;
    pmail_u64 size;
    SV *id, *result = NULL;
    int r, tls_on = (tlsmode == PMAIL_TLS_IMPLICIT);

    memset(&c, 0, sizeof c);
    c.a = PM_FETCH;
    if (!c.a || PM_FETCH_SEEN < 3)
        croak("Punk::Mailer: the smtp transport needs Fetch with a C ABI of version 3 "
              "or newer");

    /* everything the message can be wrong about, before a socket exists */
    {
        pmail_msg m;
        ENTER;
        pmail_msg_read(aTHX_ spec, &m);
        LEAVE;
    }
    id = pmail_message_id_for(aTHX_ spec);
    size = pmail_build_size(aTHX_ spec);
    Newxz(rcodes, nr + 1, int);
    SAVEFREEPV(rcodes);
    Newxz(rtexts, nr + 1, SV *);
    SAVEFREEPV(rtexts);

    ENTER;
    SAVEDESTRUCTOR_X(pmail_smtp_close, &c);
    {
        struct sigaction ign;
        memset(&ign, 0, sizeof ign);
        ign.sa_handler = SIG_IGN;
        sigemptyset(&ign.sa_mask);
        if (sigaction(SIGPIPE, &ign, &c.old_pipe) == 0) c.pipe_saved = 1;
    }

    c.phase = "connect";
    c.h = c.a->tunnel_connect(host, port, tls_on, verify);
    if (!c.h) {
        result = pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "smtp", id,
                                   "cannot connect to %s:%d%s", host, port,
                                   tls_on ? " (or the TLS handshake failed)" : "");
        goto done;
    }
    {
        struct timeval tv;
        int fd = c.a->tunnel_fd(c.h);
        tv.tv_sec = (time_t)timeout;
        tv.tv_usec = (suseconds_t)((timeout - (NV)tv.tv_sec) * 1e6);
        (void)setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, (const void *)&tv, sizeof tv);
        (void)setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, (const void *)&tv, sizeof tv);
#ifdef SO_NOSIGPIPE
        {   int one = 1;
            (void)setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, (const void *)&one, sizeof one); }
#endif
    }

    PMAIL_SMTP_STEP("greeting", c.code == 220);

    /* EHLO, falling back to HELO for a server that predates ESMTP */
    {
        const char *ehlo_name;
        SV *tmp = NULL;
        if (name) ehlo_name = SvPV_nolen(name);
        else {
            STRLEN fl; const char *fp = SvPV_const(from, fl);
            const char *at = (const char *)memchr(fp, '@', fl);
            tmp = sv_2mortal(newSVpvn(at ? at + 1 : fp, at ? fl - (STRLEN)(at + 1 - fp) : fl));
            ehlo_name = SvPV_nolen(tmp);
        }
        c.phase = "ehlo";
        if (pmail_smtp_sendf(aTHX_ &c, "EHLO %s", ehlo_name) != 0) {
            result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done;
        }
        r = pmail_smtp_reply(aTHX_ &c);
        if (r) { result = pmail_smtp_lost(aTHX_ &c, r, id); goto done; }
        if (c.code == 500 || c.code == 502 || c.code == 504) {
            c.phase = "helo";
            if (pmail_smtp_sendf(aTHX_ &c, "HELO %s", ehlo_name) != 0) {
                result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done;
            }
            PMAIL_SMTP_STEP("helo", c.code == 250);
            c.cap_starttls = c.cap_plain = c.cap_login = c.cap_size = 0;
        }
        else if (c.code != 250) { result = pmail_smtp_refused(aTHX_ &c, id); goto quit; }
        else pmail_smtp_caps(aTHX_ &c);

        if (tlsmode == PMAIL_TLS_STARTTLS) {
            c.phase = "starttls";
            if (!c.cap_starttls) {
                result = pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "smtp", id,
                                           "%s:%d does not offer STARTTLS, and tls => "
                                           "'starttls' will not continue in plaintext",
                                           host, port);
                goto quit;
            }
            if (pmail_smtp_sendf(aTHX_ &c, "STARTTLS") != 0) {
                result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done;
            }
            PMAIL_SMTP_STEP("starttls", c.code == 220);
            c.have = 0;     /* nothing read in plaintext may follow the upgrade */
            if (c.a->tunnel_starttls(c.h, host, verify) != 0) {
                result = pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "smtp", id,
                                           "the TLS handshake with %s:%d failed%s", host, port,
                                           verify ? " (certificate or hostname verification)"
                                                  : "");
                goto done;
            }
            tls_on = 1;
            /* EHLO again: the capabilities announced before TLS are not trusted */
            c.phase = "ehlo";
            if (pmail_smtp_sendf(aTHX_ &c, "EHLO %s", ehlo_name) != 0) {
                result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done;
            }
            PMAIL_SMTP_STEP("ehlo", c.code == 250);
            pmail_smtp_caps(aTHX_ &c);
        }
    }

    /* AUTH, only with a username, and only over TLS unless insecure_auth
     * was said at new - the one place that check is made */
    if (user) {
        c.phase = "auth";
        if (!c.cap_plain && !c.cap_login) {
            result = pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "smtp", id,
                                       "%s:%d offers no AUTH mechanism this client speaks "
                                       "(PLAIN, LOGIN)", host, port);
            goto quit;
        }
        if (c.cap_plain) {
            STRLEN ul, pl;
            const char *up = SvPV_const(user, ul), *pp = SvPV_const(pass, pl);
            SV *raw = sv_2mortal(newSVpvs(""));
            SV *b64;
            sv_catpvn(raw, "\0", 1); sv_catpvn(raw, up, ul);
            sv_catpvn(raw, "\0", 1); sv_catpvn(raw, pp, pl);
            b64 = sv_2mortal(pmail_b64_plain_sv(aTHX_ (const unsigned char *)SvPVX(raw),
                                                SvCUR(raw)));
            if (pmail_smtp_sendf(aTHX_ &c, "AUTH PLAIN %s", SvPVX(b64)) != 0) {
                result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done;
            }
            PMAIL_SMTP_STEP("auth", c.code == 235);
        }
        else {
            STRLEN ul, pl;
            const char *up = SvPV_const(user, ul), *pp = SvPV_const(pass, pl);
            SV *bu = sv_2mortal(pmail_b64_plain_sv(aTHX_ (const unsigned char *)up, ul));
            SV *bp = sv_2mortal(pmail_b64_plain_sv(aTHX_ (const unsigned char *)pp, pl));
            if (pmail_smtp_sendf(aTHX_ &c, "AUTH LOGIN") != 0) {
                result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done;
            }
            PMAIL_SMTP_STEP("auth", c.code == 334);
            if (pmail_smtp_sendf(aTHX_ &c, "%s", SvPVX(bu)) != 0) {
                result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done;
            }
            PMAIL_SMTP_STEP("auth", c.code == 334);
            if (pmail_smtp_sendf(aTHX_ &c, "%s", SvPVX(bp)) != 0) {
                result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done;
            }
            PMAIL_SMTP_STEP("auth", c.code == 235);
        }
    }

    /* MAIL FROM, with SIZE when the server can use it - and a local refusal
     * when the size is already known to be over the server's limit */
    c.phase = "mail";
    if (c.cap_size && c.size_limit && size > c.size_limit) {
        result = pmail_result_newf(aTHX_ PMAIL_ST_REJECTED, 552, "5.3.4", "smtp", id,
                                   "the message is %llu bytes, over the %llu-byte SIZE "
                                   "limit %s:%d announced", (unsigned long long)size,
                                   (unsigned long long)c.size_limit, host, port);
        goto quit;
    }
    if (c.cap_size) r = pmail_smtp_sendf(aTHX_ &c, "MAIL FROM:<%s> SIZE=%llu",
                                         SvPV_nolen(from), (unsigned long long)size);
    else r = pmail_smtp_sendf(aTHX_ &c, "MAIL FROM:<%s>", SvPV_nolen(from));
    if (r != 0) { result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done; }
    PMAIL_SMTP_STEP("mail", c.code == 250);

    /* RCPT TO, each verdict kept */
    for (i = 0; i < nr; i++) {
        SV *addr = *av_fetch(rcpts, i, 0);
        c.phase = "rcpt";
        if (pmail_smtp_sendf(aTHX_ &c, "RCPT TO:<%s>", SvPV_nolen(addr)) != 0) {
            result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done;
        }
        r = pmail_smtp_reply(aTHX_ &c);
        if (r) { result = pmail_smtp_lost(aTHX_ &c, r, id); goto done; }
        rcodes[i] = c.code;
        rtexts[i] = sv_2mortal(newSVpvs(""));
        if (c.enhanced[0]) { sv_catpv(rtexts[i], c.enhanced); sv_catpvs(rtexts[i], " "); }
        sv_catsv(rtexts[i], c.text);
        if (c.code == 250 || c.code == 251) accepted_rcpts++;
        else if (c.code >= 500) all_temp = 0;
    }
    if (!accepted_rcpts) {
        SV *text = sv_2mortal(newSVpvs("every recipient was refused"));
        result = pmail_result_new(aTHX_ all_temp ? PMAIL_ST_DEFERRED : PMAIL_ST_REJECTED,
                                  c.code, c.enhanced[0] ? c.enhanced : NULL, text, id, "smtp");
        for (i = 0; i < nr; i++)
            pmail_result_recipient(aTHX_ result, *av_fetch(rcpts, i, 0), rcodes[i], rtexts[i]);
        (void)pmail_smtp_sendf(aTHX_ &c, "RSET");
        c.phase = "rset";
        (void)pmail_smtp_reply(aTHX_ &c);
        goto quit;
    }

    /* DATA: the message streams from the builder through the dot-stuffing
     * filter onto the socket; an attachment never sits in memory */
    c.phase = "data";
    if (pmail_smtp_sendf(aTHX_ &c, "DATA") != 0) { result = pmail_smtp_lost(aTHX_ &c, -1, id); goto done; }
    PMAIL_SMTP_STEP("data", c.code == 354);
    {
        pmail_sink wire, stuffed;
        pmail_dotstuff st;
        wire.write = pmail_sink_smtp_write; wire.ud = &c; wire.ud2 = NULL;
        pmail_sink_dotstuff(&stuffed, &st, &wire);
        c.last = '\n';
        if (pmail_build(aTHX_ spec, &stuffed) != 0) {
            result = pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "smtp", id,
                                       "connection lost during data");
            goto done;
        }
        if (c.last != '\n' && pmail_smtp_send(&c, PMAIL_CRLF, 2) != 0) {
            result = pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "smtp", id,
                                       "connection lost during data");
            goto done;
        }
        if (pmail_smtp_send(&c, "." PMAIL_CRLF, 3) != 0) {
            result = pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "smtp", id,
                                       "connection lost during data");
            goto done;
        }
    }
    c.phase = "data";
    r = pmail_smtp_reply(aTHX_ &c);
    if (r) { result = pmail_smtp_lost(aTHX_ &c, r, id); goto done; }
    if (c.code == 250) {
        SV *text = sv_2mortal(newSVpvs(""));
        sv_catsv(text, c.text);
        result = pmail_result_new(aTHX_ PMAIL_ST_ACCEPTED, 250,
                                  c.enhanced[0] ? c.enhanced : NULL, text, id, "smtp");
    }
    else result = pmail_smtp_refused(aTHX_ &c, id);
    for (i = 0; i < nr; i++)
        pmail_result_recipient(aTHX_ result, *av_fetch(rcpts, i, 0), rcodes[i], rtexts[i]);

quit:
    /* a polite close; its answer cannot change the verdict */
    c.phase = "quit";
    if (pmail_smtp_sendf(aTHX_ &c, "QUIT") == 0) (void)pmail_smtp_reply(aTHX_ &c);
done:
    pmail_smtp_close(aTHX_ &c);
    LEAVE;
    return result;
}

#endif /* PMAIL_TX_SMTP_H */
