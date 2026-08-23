#ifndef PMAIL_ENGINE_H
#define PMAIL_ENGINE_H

/* pmail_engine.h - Punk::Mailer->new and ->send.
 *
 * The engine holds one transport and the defaults a message may leave out
 * (from, reply_to, message_id_domain). `new` resolves and constructs the
 * transport, so every option of every layer is checked there: boot is the
 * only good time to find a typo. `send` fills the defaults in, validates
 * the message (a bad one is a croak - it is a programming error), and
 * hands the transport the message and its envelope; what the transport
 * returns is a Result, never an exception. */

static const char *const PMAIL_ENGINE_OPTS[] = {
    "transport", "from", "reply_to", "message_id_domain",
    "capture", "log", "sendmail", "resend", "smtp", "options",
};

typedef struct { const char *name; const char *class; } pmail_tx_name;
static const pmail_tx_name PMAIL_TX_NAMES[] = {
    { "capture",  "Punk::Mailer::Transport::Capture"  },
    { "log",      "Punk::Mailer::Transport::Log"      },
    { "sendmail", "Punk::Mailer::Transport::Sendmail" },
    { "resend",   "Punk::Mailer::Transport::Resend"   },
    { "smtp",     "Punk::Mailer::Transport::SMTP"     },
};

/* $class->new(\%opts) on a transport class, through method dispatch so a
 * class from outside this dist works the same way */
static SV *pmail_tx_construct(pTHX_ const char *class, SV *opts)
{
    dSP;
    SV *obj = NULL;
    int count;
    HV *stash = gv_stashpv(class, 0);
    if (!stash || !gv_fetchmethod_autoload(stash, "new", 0)) {
        /* not loaded yet: a class from outside this dist may need requiring */
        eval_pv(form("require %s;", class), FALSE);
        stash = gv_stashpv(class, 0);
        if (!stash || !gv_fetchmethod_autoload(stash, "new", 0))
            croak("Punk::Mailer: transport class %s has no 'new' (%s)", class,
                  SvTRUE(ERRSV) ? SvPV_nolen(ERRSV) : "is it installed?");
    }
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv(class, 0)));
    XPUSHs(opts ? opts : &PL_sv_undef);
    PUTBACK;
    count = call_method("new", G_SCALAR);
    SPAGAIN;
    if (count > 0) { obj = POPs; SvREFCNT_inc_simple_void(obj); }
    PUTBACK;
    FREETMPS; LEAVE;
    if (!obj || !sv_isobject(obj))
        croak("Punk::Mailer: %s->new did not return an object", class);
    return obj;
}

static SV *pmail_engine_new(pTHX_ const char *class, SV **args, I32 nargs)
{
    HV *opts = (HV *)sv_2mortal((SV *)newHV());
    HV *self = newHV();
    SV *self_ref = pmail_bless(aTHX_ self, class);
    SV *name, *from, *reply_to, *domain, *tx_opts = NULL, *tx;
    const char *tx_class = NULL;
    STRLEN nl; const char *np;
    size_t i;
    I32 k;

    sv_2mortal(self_ref);
    if (nargs == 1 && SvROK(args[0]) && SvTYPE(SvRV(args[0])) == SVt_PVHV) {
        HV *given = (HV *)SvRV(args[0]);
        HE *he;
        hv_iterinit(given);
        while ((he = hv_iternext(given)))
            (void)hv_store_ent(opts, hv_iterkeysv(he), newSVsv(HeVAL(he)), 0);
    }
    else {
        if (nargs % 2) croak("Punk::Mailer->new takes key/value pairs or a hashref");
        for (k = 0; k + 1 < nargs; k += 2) {
            STRLEN kl; const char *kp = SvPV_const(args[k], kl);
            (void)hv_store(opts, kp, (I32)kl, newSVsv(args[k + 1]), 0);
        }
    }
    pmail_opts_check(aTHX_ "Punk::Mailer->new", opts, PMAIL_ENGINE_OPTS,
                     sizeof PMAIL_ENGINE_OPTS / sizeof *PMAIL_ENGINE_OPTS);

    name = pmail_opt_str(aTHX_ opts, "transport", "Punk::Mailer->new", 1);
    sv_2mortal(name);
    np = SvPV_const(name, nl);
    if (memchr(np, ':', nl)) {
        tx_class = np;
        tx_opts = pmail_opt(aTHX_ opts, "options");
    }
    else {
        for (i = 0; i < sizeof PMAIL_TX_NAMES / sizeof *PMAIL_TX_NAMES; i++) {
            if (strlen(PMAIL_TX_NAMES[i].name) == nl && memEQ(np, PMAIL_TX_NAMES[i].name, nl)) {
                tx_class = PMAIL_TX_NAMES[i].class;
                tx_opts = pmail_opt(aTHX_ opts, PMAIL_TX_NAMES[i].name);
                break;
            }
        }
        if (!tx_class)
            croak("Punk::Mailer: unknown transport '%.*s' (capture, log, sendmail, "
                  "resend, smtp, or a class name)", (int)nl, np);
    }
    if (tx_opts && !(SvROK(tx_opts) && SvTYPE(SvRV(tx_opts)) == SVt_PVHV))
        croak("Punk::Mailer: the options for transport '%.*s' must be a hashref",
              (int)nl, np);

    from = pmail_opt_str(aTHX_ opts, "from", "Punk::Mailer->new", 0);
    if (from) {
        SV *d, *a;
        sv_2mortal(from);
        pmail_addr_parse(aTHX_ "from", from, &d, &a);
        SvREFCNT_dec(d); SvREFCNT_dec(a);
    }
    reply_to = pmail_opt_str(aTHX_ opts, "reply_to", "Punk::Mailer->new", 0);
    if (reply_to) {
        SV *d, *a;
        sv_2mortal(reply_to);
        pmail_addr_parse(aTHX_ "reply_to", reply_to, &d, &a);
        SvREFCNT_dec(d); SvREFCNT_dec(a);
    }
    domain = pmail_opt_str(aTHX_ opts, "message_id_domain", "Punk::Mailer->new", 0);
    if (domain) {
        STRLEN dl; const char *dp = SvPV_const(domain, dl);
        sv_2mortal(domain);
        pmail_hdr_assert_clean(aTHX_ "message_id_domain", dp, dl);
    }

    tx = pmail_tx_construct(aTHX_ tx_class, tx_opts);
    (void)hv_stores(self, "transport", tx);
    (void)hv_stores(self, "transport_name", newSVpvn(np, nl));
    (void)hv_stores(self, "from", from ? newSVsv(from) : newSV(0));
    (void)hv_stores(self, "reply_to", reply_to ? newSVsv(reply_to) : newSV(0));
    (void)hv_stores(self, "message_id_domain", domain ? newSVsv(domain) : newSV(0));
    return SvREFCNT_inc_simple_NN(self_ref);
}

static SV *pmail_engine_send(pTHX_ SV *self_sv, SV *spec_sv)
{
    HV *self = pmail_self(aTHX_ self_sv, "send");
    HV *given = pmail_spec_hv(aTHX_ spec_sv, "send");
    HV *spec = newHVhv(given);
    SV *spec_ref = sv_2mortal(newRV_noinc((SV *)spec));
    SV *tx = pmail_hv_get(aTHX_ self, "transport");
    SV *env_ref, *result = NULL;
    static const char *const defaults[] = { "from", "reply_to", "message_id_domain" };
    size_t i;
    dSP;
    int count;

    for (i = 0; i < 3; i++) {
        SV *d = pmail_hv_get(aTHX_ self, defaults[i]);
        if (d && !pmail_spec_get(aTHX_ spec, defaults[i]))
            (void)hv_store(spec, defaults[i], (I32)strlen(defaults[i]), newSVsv(d), 0);
    }
    /* validate now: a malformed message is the caller's bug and croaks
     * here, before a transport is involved */
    {
        pmail_msg m;
        ENTER;
        pmail_msg_read(aTHX_ spec, &m);
        LEAVE;
    }
    env_ref = sv_2mortal(newRV_noinc((SV *)pmail_envelope(aTHX_ spec)));

    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(tx);
    XPUSHs(spec_ref);
    XPUSHs(env_ref);
    PUTBACK;
    count = call_method("deliver", G_SCALAR);
    SPAGAIN;
    if (count > 0) { result = POPs; SvREFCNT_inc_simple_void(result); }
    PUTBACK;
    FREETMPS; LEAVE;
    if (!result || !sv_derived_from(result, "Punk::Mailer::Result"))
        croak("Punk::Mailer: the transport's deliver did not return a Punk::Mailer::Result");
    return result;
}

#endif /* PMAIL_ENGINE_H */
