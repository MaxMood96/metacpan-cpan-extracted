MODULE = Punk::Mailer    PACKAGE = Punk::Mailer::Transport::Capture

SV *
new(class, opts = &PL_sv_undef)
        SV *class
        SV *opts
    CODE:
        RETVAL = pmail_capture_new(aTHX_ SvPV_nolen(class), opts);
    OUTPUT:
        RETVAL

SV *
deliver(self, spec, envelope)
        SV *self
        SV *spec
        SV *envelope
    CODE:
        RETVAL = pmail_capture_deliver(aTHX_ self, spec, envelope);
    OUTPUT:
        RETVAL

const char *
name(self)
        SV *self
    CODE:
        PERL_UNUSED_VAR(self);
        RETVAL = "capture";
    OUTPUT:
        RETVAL

# the captured messages: [ { spec, envelope, bytes, result }, ... ]
SV *
messages(self)
        SV *self
    ALIAS:
        dir       = 1
        last_path = 2
    PREINIT:
        static const char *const keys[] = { "messages", "dir", "last_path" };
        HV *h;
        SV *v;
    CODE:
        h = pmail_self(aTHX_ self, keys[ix]);
        v = pmail_hv_get(aTHX_ h, keys[ix]);
        RETVAL = v ? newSVsv(v) : newSV(0);
    OUTPUT:
        RETVAL

void
clear(self)
        SV *self
    PREINIT:
        HV *h;
        SV **mp;
    PPCODE:
        h = pmail_self(aTHX_ self, "clear");
        mp = hv_fetchs(h, "messages", 0);
        if (mp && *mp) av_clear((AV *)SvRV(*mp));
        XSRETURN_YES;

MODULE = Punk::Mailer    PACKAGE = Punk::Mailer::Transport::Log

SV *
new(class, opts = &PL_sv_undef)
        SV *class
        SV *opts
    CODE:
        RETVAL = pmail_log_new(aTHX_ SvPV_nolen(class), opts);
    OUTPUT:
        RETVAL

SV *
deliver(self, spec, envelope)
        SV *self
        SV *spec
        SV *envelope
    CODE:
        RETVAL = pmail_log_deliver(aTHX_ self, spec, envelope);
    OUTPUT:
        RETVAL

const char *
name(self)
        SV *self
    CODE:
        PERL_UNUSED_VAR(self);
        RETVAL = "log";
    OUTPUT:
        RETVAL

MODULE = Punk::Mailer    PACKAGE = Punk::Mailer::Transport::Sendmail

SV *
new(class, opts = &PL_sv_undef)
        SV *class
        SV *opts
    CODE:
        RETVAL = pmail_sendmail_new(aTHX_ SvPV_nolen(class), opts);
    OUTPUT:
        RETVAL

SV *
deliver(self, spec, envelope)
        SV *self
        SV *spec
        SV *envelope
    CODE:
        RETVAL = pmail_sendmail_deliver(aTHX_ self, spec, envelope);
    OUTPUT:
        RETVAL

const char *
name(self)
        SV *self
    CODE:
        PERL_UNUSED_VAR(self);
        RETVAL = "sendmail";
    OUTPUT:
        RETVAL

# the argv list, as it will be run (before -f and the recipients)
SV *
command(self)
        SV *self
    PREINIT:
        HV *h;
        SV *v;
    CODE:
        h = pmail_self(aTHX_ self, "command");
        v = pmail_hv_get(aTHX_ h, "command");
        RETVAL = v ? newSVsv(v) : newSV(0);
    OUTPUT:
        RETVAL

MODULE = Punk::Mailer    PACKAGE = Punk::Mailer::Transport::Resend

SV *
new(class, opts = &PL_sv_undef)
        SV *class
        SV *opts
    CODE:
        RETVAL = pmail_http_new(aTHX_ SvPV_nolen(class), opts, &PMAIL_RESEND);
    OUTPUT:
        RETVAL

SV *
deliver(self, spec, envelope)
        SV *self
        SV *spec
        SV *envelope
    CODE:
        PERL_UNUSED_VAR(envelope);
        RETVAL = pmail_http_deliver(aTHX_ self, spec, &PMAIL_RESEND);
    OUTPUT:
        RETVAL

const char *
name(self)
        SV *self
    CODE:
        PERL_UNUSED_VAR(self);
        RETVAL = "resend";
    OUTPUT:
        RETVAL

# the endpoint and limits this transport was built with
SV *
url(self)
        SV *self
    ALIAS:
        timeout        = 1
        max_attachment = 2
    PREINIT:
        static const char *const keys[] = { "url", "timeout", "max_attachment" };
        HV *h;
        SV *v;
    CODE:
        h = pmail_self(aTHX_ self, keys[ix]);
        v = pmail_hv_get(aTHX_ h, keys[ix]);
        RETVAL = v ? newSVsv(v) : newSV(0);
    OUTPUT:
        RETVAL

MODULE = Punk::Mailer    PACKAGE = Punk::Mailer::Transport::SMTP

SV *
new(class, opts = &PL_sv_undef)
        SV *class
        SV *opts
    CODE:
        RETVAL = pmail_smtp_new(aTHX_ SvPV_nolen(class), opts);
    OUTPUT:
        RETVAL

SV *
deliver(self, spec, envelope)
        SV *self
        SV *spec
        SV *envelope
    CODE:
        RETVAL = pmail_smtp_deliver(aTHX_ self, spec, envelope);
    OUTPUT:
        RETVAL

const char *
name(self)
        SV *self
    CODE:
        PERL_UNUSED_VAR(self);
        RETVAL = "smtp";
    OUTPUT:
        RETVAL

# what this transport was built with; the password is not reachable
SV *
host(self)
        SV *self
    ALIAS:
        port     = 1
        tls      = 2
        verify   = 3
        timeout  = 4
        username = 5
    PREINIT:
        static const char *const keys[] = { "host", "port", "tls", "verify", "timeout", "username" };
        HV *h;
        SV *v;
    CODE:
        h = pmail_self(aTHX_ self, keys[ix]);
        v = pmail_hv_get(aTHX_ h, keys[ix]);
        RETVAL = v ? newSVsv(v) : newSV(0);
    OUTPUT:
        RETVAL
