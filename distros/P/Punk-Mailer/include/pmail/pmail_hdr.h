#ifndef PMAIL_HDR_H
#define PMAIL_HDR_H

/* pmail_hdr.h - the header rules.
 *
 * Everything that decides whether a string may become part of a header,
 * and what it looks like when it does: the injection refusal, address
 * parsing and formatting, RFC 2047 encoded-words for text outside ASCII,
 * RFC 5322 folding, and the generated Date and Message-ID. The builder
 * calls these; nothing else in the dist touches a header byte. */

/* ---- the one unconditional rule --------------------------------------
 * A CR, LF or NUL anywhere in a value that is going into a header is
 * refused. That is what stops a form field from ending one header and
 * starting another. It applies to addresses, names, the subject, custom
 * header names and values, and attachment filenames - every string a
 * caller supplies that the builder writes before the blank line. */

static int pmail_hdr_unsafe(const char *p, STRLEN n)
{
    STRLEN i;
    for (i = 0; i < n; i++)
        if (p[i] == '\r' || p[i] == '\n' || p[i] == 0) return 1;
    return 0;
}

static void pmail_hdr_assert_clean(pTHX_ const char *what, const char *p, STRLEN n)
{
    if (pmail_hdr_unsafe(p, n))
        croak("Punk::Mailer: %s contains a carriage return, line feed or NUL, "
              "which would inject a header", what);
}

/* every string reaches C as UTF-8 bytes: perl semantics for a byte string
 * (a latin-1 scalar upgrades), so the charset can always be utf-8 */
static const char *pmail_sv_utf8(pTHX_ SV *sv, STRLEN *len)
{
    return SvPVutf8(sv, *len);
}

static int pmail_is_ascii(const char *p, STRLEN n)
{
    STRLEN i;
    for (i = 0; i < n; i++) if ((unsigned char)p[i] >= 0x80) return 0;
    return 1;
}

/* RFC 5322 atext, plus space: a display name made only of these needs
 * neither quoting nor encoding */
static int pmail_atext_or_space(unsigned char c)
{
    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))
        return 1;
    return c == ' ' || strchr("!#$%&'*+-/=?^_`{|}~", c) != NULL;
}

/* ---- RFC 2047 encoded-words ------------------------------------------
 * "=?UTF-8?B?<base64>?=" words of at most 75 characters, separated by a
 * space (which decoders drop between adjacent words). 45 input bytes
 * encode to 60 characters and 72 with the envelope; 48 would be 76. The
 * split backs off to a UTF-8 character boundary, so a multi-byte
 * character is never cut in half - which produces a word that decodes to
 * garbage, and which naive splitters do. */

#define PMAIL_2047_BYTES 45

static void pmail_hdr_encode_words(pTHX_ SV *out, const char *p, STRLEN n)
{
    int first = 1;
    while (n) {
        STRLEN take = n > PMAIL_2047_BYTES ? PMAIL_2047_BYTES : n;
        SV *b64;
        while (take < n && take > 0 && ((unsigned char)p[take] & 0xC0) == 0x80)
            take--;
        if (take == 0) take = 1;        /* cannot happen for valid UTF-8 */
        b64 = pmail_b64_plain_sv(aTHX_ (const unsigned char *)p, take);
        if (!first) sv_catpvs(out, " ");
        sv_catpvs(out, "=?UTF-8?B?");
        sv_catsv(out, b64);
        sv_catpvs(out, "?=");
        SvREFCNT_dec(b64);
        first = 0;
        p += take; n -= take;
    }
}

/* an unstructured header value (Subject, a custom header): ASCII as it is,
 * otherwise encoded-words */
static void pmail_hdr_unstructured(pTHX_ SV *out, const char *p, STRLEN n)
{
    if (pmail_is_ascii(p, n)) sv_catpvn(out, p, n);
    else pmail_hdr_encode_words(aTHX_ out, p, n);
}

/* ---- folding -----------------------------------------------------------
 * "Name: value" with the value folded at spaces so no line is longer than
 * 78 characters where a space allows it. A run with no space in it goes
 * out whole; one longer than 998 characters cannot be a header line at all
 * and croaks. Output ends with CRLF. */

static void pmail_hdr_fold(pTHX_ SV *out, const char *name, STRLEN nlen,
                           const char *val, STRLEN vlen)
{
    STRLEN col, i = 0;
    sv_catpvn(out, name, nlen);
    sv_catpvs(out, ":");
    col = nlen + 1;
    while (i < vlen) {
        STRLEN j = i;
        while (i < vlen && val[i] == ' ') i++;       /* the separating spaces */
        j = i;
        while (j < vlen && val[j] != ' ') j++;       /* one token */
        if (j == i) break;
        if (j - i > PMAIL_MAX_LINE - 1)
            croak("Punk::Mailer: header %.*s has a run of %lu characters with "
                  "no whitespace, longer than a header line may be",
                  (int)nlen, name, (unsigned long)(j - i));
        if (col + 1 + (j - i) > PMAIL_FOLD_AT && col > nlen + 1) {
            sv_catpvs(out, PMAIL_CRLF " ");
            col = 1;
        }
        else {
            sv_catpvs(out, " ");
            col++;
        }
        sv_catpvn(out, val + i, j - i);
        col += j - i;
        i = j;
    }
    sv_catpvs(out, PMAIL_CRLF);
}

static void pmail_hdr_fold_sv(pTHX_ SV *out, const char *name, SV *val)
{
    STRLEN vl;
    const char *v = SvPV_const(val, vl);
    pmail_hdr_fold(aTHX_ out, name, strlen(name), v, vl);
}

/* ---- addresses ----------------------------------------------------------
 * Accepted: "addr", "Name <addr>", "\"Quoted Name\" <addr>". The addr-spec
 * must be ASCII, one '@', a local part and a domain on either side, and
 * none of the characters that would make it read as structure. Anything
 * else croaks naming what it was given. */

static int pmail_addr_spec_ok(const char *p, STRLEN n)
{
    STRLEN i, at = 0;
    int ats = 0;
    if (n == 0) return 0;
    for (i = 0; i < n; i++) {
        unsigned char c = (unsigned char)p[i];
        if (c <= ' ' || c >= 0x7f) return 0;
        if (strchr("<>()[],;:\"\\", c)) return 0;
        if (c == '@') { ats++; at = i; }
    }
    if (ats != 1 || at == 0 || at == n - 1) return 0;
    if (p[at + 1] == '.' || p[n - 1] == '.') return 0;
    return 1;
}

/* display (may be empty) and addr, as new SVs the caller owns */
static void pmail_addr_parse(pTHX_ const char *what, SV *in, SV **display, SV **addr)
{
    STRLEN n, i, end;
    const char *p = pmail_sv_utf8(aTHX_ in, &n);
    const char *lt, *gt;

    pmail_hdr_assert_clean(aTHX_ what, p, n);
    /* trim */
    i = 0; end = n;
    while (i < end && (p[i] == ' ' || p[i] == '\t')) i++;
    while (end > i && (p[end - 1] == ' ' || p[end - 1] == '\t')) end--;
    p += i; n = end - i;

    if (n && p[n - 1] == '>' && (lt = (const char *)memchr(p, '<', n)) != NULL) {
        STRLEN dn = (STRLEN)(lt - p);
        const char *a = lt + 1;
        STRLEN an = (STRLEN)(p + n - 1 - a);
        gt = (const char *)memchr(a, '>', an + 1);
        if (gt != p + n - 1 || memchr(a, '<', an))
            croak("Punk::Mailer: %s '%.*s' is not an address", what, (int)n, p);
        if (!pmail_addr_spec_ok(a, an))
            croak("Punk::Mailer: %s '%.*s' is not an address", what, (int)n, p);
        while (dn && (p[dn - 1] == ' ' || p[dn - 1] == '\t')) dn--;
        if (dn >= 2 && p[0] == '"' && p[dn - 1] == '"') {
            /* a quoted display name: unescape \" and \\ */
            SV *d = newSVpvs("");
            STRLEN k;
            for (k = 1; k + 1 < dn; k++) {
                if (p[k] == '\\' && k + 2 < dn) k++;
                sv_catpvn(d, p + k, 1);
            }
            SvUTF8_on(d);
            *display = d;
        }
        else {
            *display = newSVpvn(p, dn);
            SvUTF8_on(*display);
        }
        *addr = newSVpvn(a, an);
        return;
    }
    if (!pmail_addr_spec_ok(p, n))
        croak("Punk::Mailer: %s '%.*s' is not an address", what, (int)n, p);
    *display = newSVpvs("");
    *addr = newSVpvn(p, n);
}

/* a mailbox as it goes on the wire: name encoded or quoted as it needs */
static void pmail_addr_format(pTHX_ SV *out, SV *display, SV *addr)
{
    STRLEN dn, an;
    const char *d = SvPV_const(display, dn);
    const char *a = SvPV_const(addr, an);
    if (dn == 0) { sv_catpvn(out, a, an); return; }
    if (!pmail_is_ascii(d, dn)) {
        pmail_hdr_encode_words(aTHX_ out, d, dn);
    }
    else {
        STRLEN i;
        int plain = 1;
        for (i = 0; i < dn; i++)
            if (!pmail_atext_or_space((unsigned char)d[i])) { plain = 0; break; }
        if (plain) sv_catpvn(out, d, dn);
        else {
            sv_catpvs(out, "\"");
            for (i = 0; i < dn; i++) {
                if (d[i] == '"' || d[i] == '\\') sv_catpvs(out, "\\");
                sv_catpvn(out, d + i, 1);
            }
            sv_catpvs(out, "\"");
        }
    }
    sv_catpvs(out, " <");
    sv_catpvn(out, a, an);
    sv_catpvs(out, ">");
}

/* `what` may be a string or an arrayref of strings; each becomes a
 * two-element AV [display, addr] pushed onto `out`. undef adds nothing. */
static void pmail_addr_list(pTHX_ const char *what, SV *v, AV *out)
{
    if (!v || !SvOK(v)) return;
    if (SvROK(v) && SvTYPE(SvRV(v)) == SVt_PVAV) {
        AV *in = (AV *)SvRV(v);
        SSize_t i, n = av_len(in) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(in, i, 0);
            if (e && *e) pmail_addr_list(aTHX_ what, *e, out);
        }
        return;
    }
    if (SvROK(v))
        croak("Punk::Mailer: %s must be an address or a list of them", what);
    {
        SV *display, *addr;
        AV *pair = newAV();
        pmail_addr_parse(aTHX_ what, v, &display, &addr);
        av_push(pair, display);
        av_push(pair, addr);
        av_push(out, newRV_noinc((SV *)pair));
    }
}

/* the header value for a list: mailboxes joined by ", " */
static SV *pmail_addr_header_value(pTHX_ AV *list)
{
    SV *out = newSVpvs("");
    SSize_t i, n = av_len(list) + 1;
    for (i = 0; i < n; i++) {
        SV **e = av_fetch(list, i, 0);
        AV *pair = (AV *)SvRV(*e);
        if (i) sv_catpvs(out, ", ");
        pmail_addr_format(aTHX_ out, *av_fetch(pair, 0, 0), *av_fetch(pair, 1, 0));
    }
    return out;
}

/* ---- generated headers ------------------------------------------------ */

/* RFC 5322 date, always +0000: a fixed offset has no timezone database,
 * no locale and no daylight-saving edge to be wrong about on a smoker */
static void pmail_hdr_date(char *buf, size_t size, time_t t)
{
    static const char *const days[] =
        { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
    static const char *const mons[] =
        { "Jan", "Feb", "Mar", "Apr", "May", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    struct tm *tm = gmtime(&t);
    if (!tm) { snprintf(buf, size, "Thu, 01 Jan 1970 00:00:00 +0000"); return; }
    snprintf(buf, size, "%s, %02d %s %04d %02d:%02d:%02d +0000",
             days[tm->tm_wday], tm->tm_mday, mons[tm->tm_mon],
             tm->tm_year + 1900, tm->tm_hour, tm->tm_min, tm->tm_sec);
}

/* <epoch.pid.token@domain> - unique across a forked pool by construction
 * (the token comes from a pid-keyed pool), and readable in a log */
static SV *pmail_hdr_message_id(pTHX_ const char *domain, STRLEN dlen, time_t t)
{
    char token[25], tb[PMAIL_U64_LEN];
    if (pmail_random_token(token, 24) != 0)
        croak("Punk::Mailer: no entropy available for a Message-ID");
    return newSVpvf("<%s.%lu.%s@%.*s>", pmail_u64_str(tb, (pmail_u64)t),
                    (unsigned long)getpid(), token, (int)dlen, domain);
}

/* a custom header name: printable ASCII with no ':' (RFC 5322 ftext) */
static int pmail_hdr_name_ok(const char *p, STRLEN n)
{
    STRLEN i;
    if (n == 0) return 0;
    for (i = 0; i < n; i++) {
        unsigned char c = (unsigned char)p[i];
        if (c < 33 || c > 126 || c == ':') return 0;
    }
    return 1;
}

#endif /* PMAIL_HDR_H */
