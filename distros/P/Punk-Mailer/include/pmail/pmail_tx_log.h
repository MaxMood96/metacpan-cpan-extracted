#ifndef PMAIL_TX_LOG_H
#define PMAIL_TX_LOG_H

/* pmail_tx_log.h - the honest fallback.
 *
 * Writes the built message to STDERR (or to a filehandle or a callback
 * given as `to`) and reports `unsent`. It exists so that a development
 * box with no mail configured says `transport => 'log'` and sees the
 * message, rather than having no transport and wondering where the mail
 * went - and so the Result says plainly that nothing was delivered. */

static const char *const PMAIL_LOG_OPTS[] = { "to" };

static SV *pmail_log_new(pTHX_ const char *class, SV *opts_sv)
{
    HV *opts = pmail_opts_hv(aTHX_ opts_sv, "the log transport");
    HV *self = newHV();
    SV *to;
    pmail_opts_check(aTHX_ "the log transport", opts, PMAIL_LOG_OPTS, 1);
    to = pmail_opt(aTHX_ opts, "to");
    if (to) {
        int ok = SvROK(to) && (SvTYPE(SvRV(to)) == SVt_PVCV || SvTYPE(SvRV(to)) == SVt_PVGV
                               || SvTYPE(SvRV(to)) == SVt_PVIO);
        if (!ok && !(SvTYPE(to) == SVt_PVGV)) ok = sv_2io(to) != NULL;
        if (!ok) croak("Punk::Mailer: the log transport's 'to' must be a filehandle "
                       "or a coderef");
    }
    (void)hv_stores(self, "to", to ? newSVsv(to) : newSV(0));
    return pmail_bless(aTHX_ self, class);
}

static SV *pmail_log_deliver(pTHX_ SV *self_sv, SV *spec_sv, SV *env_sv)
{
    HV *self = pmail_self(aTHX_ self_sv, "deliver");
    HV *spec = pmail_spec_hv(aTHX_ spec_sv, "deliver");
    SV *bytes = sv_2mortal(pmail_build_bytes(aTHX_ spec));
    SV *to = pmail_hv_get(aTHX_ self, "to");
    SV *id = pmail_message_id_of(aTHX_ bytes);
    STRLEN n; const char *p = SvPV_const(bytes, n);
    (void)env_sv;
    if (id) sv_2mortal(id);

    if (to && SvROK(to) && SvTYPE(SvRV(to)) == SVt_PVCV) {
        dSP;
        ENTER; SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(bytes);
        PUTBACK;
        call_sv(to, G_VOID | G_DISCARD);
        FREETMPS; LEAVE;
    }
    else {
        PerlIO *fp = NULL;
        if (to) { IO *io = sv_2io(to); fp = io ? IoOFP(io) : NULL; }
        if (!fp) fp = PerlIO_stderr();
        PerlIO_printf(fp, "Punk::Mailer (transport log, not sent):\n");
        PerlIO_write(fp, p, n);
        if (n == 0 || p[n - 1] != '\n') PerlIO_write(fp, "\n", 1);
        PerlIO_flush(fp);
    }
    return pmail_result_newf(aTHX_ PMAIL_ST_UNSENT, 0, NULL, "log", id,
                             "not sent: the log transport only records");
}

#endif /* PMAIL_TX_LOG_H */
