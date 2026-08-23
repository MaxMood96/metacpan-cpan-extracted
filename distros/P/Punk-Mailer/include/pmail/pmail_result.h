#ifndef PMAIL_RESULT_H
#define PMAIL_RESULT_H

/* pmail_result.h - what a delivery attempt came to.
 *
 * A Punk::Mailer::Result is a blessed hash with one status word and the
 * facts behind it. Delivery never throws: a refused connection, a 5xx, a
 * pipe that exited - every one is a Result, so the code that asked can
 * decide what to do, and a job body can decide whether to retry. There is
 * no boolean overload, deliberately: `unless $result` must mean "there is
 * no result", never "it was rejected" - the difference between a missing
 * value and a bad one is the whole fail-open bug class. */

#define PMAIL_ST_ACCEPTED "accepted"
#define PMAIL_ST_DEFERRED "deferred"
#define PMAIL_ST_REJECTED "rejected"
#define PMAIL_ST_FAILED   "failed"
#define PMAIL_ST_UNSENT   "unsent"

/* status: one of the words above. code: the SMTP reply or HTTP status, 0
 * for none. enhanced: an x.y.z, or NULL. message: the server's or the
 * transport's text, may be NULL. id: the provider's id or our Message-ID,
 * may be NULL. transport: the short name. Returns +1, blessed. */
static SV *pmail_result_new(pTHX_ const char *status, IV code, const char *enhanced,
                            SV *message, SV *id, const char *transport)
{
    HV *h = newHV();
    (void)hv_stores(h, "status", newSVpv(status, 0));
    (void)hv_stores(h, "code", code ? newSViv(code) : newSV(0));
    (void)hv_stores(h, "enhanced", enhanced ? newSVpv(enhanced, 0) : newSV(0));
    (void)hv_stores(h, "message", message ? newSVsv(message) : newSVpvs(""));
    (void)hv_stores(h, "id", id ? newSVsv(id) : newSV(0));
    (void)hv_stores(h, "transport", newSVpv(transport, 0));
    (void)hv_stores(h, "recipients", newRV_noinc((SV *)newHV()));
    return sv_bless(newRV_noinc((SV *)h), gv_stashpvs("Punk::Mailer::Result", GV_ADD));
}

static SV *pmail_result_newf(pTHX_ const char *status, IV code, const char *enhanced,
                             const char *transport, SV *id, const char *fmt, ...)
{
    va_list ap;
    SV *msg = sv_2mortal(newSVpvs(""));
    SV *r;
    va_start(ap, fmt);
    sv_vcatpvf(msg, fmt, &ap);
    va_end(ap);
    r = pmail_result_new(aTHX_ status, code, enhanced, msg, id, transport);
    return r;
}

/* one recipient's verdict, for the SMTP transport's per-RCPT codes */
static void pmail_result_recipient(pTHX_ SV *result, SV *addr, IV code, SV *message)
{
    HV *h = (HV *)SvRV(result);
    SV **rp = hv_fetchs(h, "recipients", 0);
    HV *rec = (HV *)SvRV(*rp);
    HV *one = newHV();
    (void)hv_stores(one, "code", newSViv(code));
    (void)hv_stores(one, "message", message ? newSVsv(message) : newSVpvs(""));
    (void)hv_store_ent(rec, addr, newRV_noinc((SV *)one), 0);
}

static const char *pmail_result_status(pTHX_ SV *result)
{
    HV *h = (HV *)SvRV(result);
    SV **s = hv_fetchs(h, "status", 0);
    return (s && *s && SvOK(*s)) ? SvPV_nolen(*s) : "";
}

/* The Message-ID the builder wrote, read back from the header block - so
 * a transport with no id of its own (capture, log, sendmail) reports the
 * one the message carries. NULL when there is none. */
static SV *pmail_message_id_of(pTHX_ SV *bytes)
{
    STRLEN n;
    const char *p = SvPV_const(bytes, n);
    const char *end = p + n;
    const char *line = p;
    while (line < end) {
        const char *eol = (const char *)memchr(line, '\n', (size_t)(end - line));
        STRLEN ll = eol ? (STRLEN)(eol - line) : (STRLEN)(end - line);
        if (ll == 0 || (ll == 1 && line[0] == '\r')) break;    /* end of headers */
        if (ll > 12 && pmail_ieq(line, "Message-ID: ", 12)) {
            STRLEN vl = ll - 12;
            if (vl && line[12 + vl - 1] == '\r') vl--;
            return newSVpvn(line + 12, vl);
        }
        if (!eol) break;
        line = eol + 1;
    }
    return NULL;
}

#endif /* PMAIL_RESULT_H */
