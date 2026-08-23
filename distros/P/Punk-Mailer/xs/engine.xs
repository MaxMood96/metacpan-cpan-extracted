MODULE = Punk::Mailer    PACKAGE = Punk::Mailer

# Punk::Mailer->new(transport => ..., from => ..., resend => {...}, ...)
SV *
new(class, ...)
        SV *class
    CODE:
        RETVAL = pmail_engine_new(aTHX_ SvPV_nolen(class), &ST(1), items - 1);
    OUTPUT:
        RETVAL

# $mailer->send(\%message) - a Punk::Mailer::Result
SV *
send(self, spec)
        SV *self
        SV *spec
    CODE:
        RETVAL = pmail_engine_send(aTHX_ self, spec);
    OUTPUT:
        RETVAL

# the transport object, and the name it was asked for by
SV *
transport(self)
        SV *self
    ALIAS:
        transport_name    = 1
        from              = 2
        reply_to          = 3
        message_id_domain = 4
    PREINIT:
        static const char *const keys[] = {
            "transport", "transport_name", "from", "reply_to", "message_id_domain",
        };
        HV *h;
        SV *v;
    CODE:
        h = pmail_self(aTHX_ self, keys[ix]);
        v = pmail_hv_get(aTHX_ h, keys[ix]);
        RETVAL = v ? newSVsv(v) : newSV(0);
    OUTPUT:
        RETVAL

MODULE = Punk::Mailer    PACKAGE = Punk::Mailer::Result

# status / code / enhanced / message / id / transport / recipients
SV *
status(self)
        SV *self
    ALIAS:
        code       = 1
        enhanced   = 2
        message    = 3
        id         = 4
        transport  = 5
        recipients = 6
    PREINIT:
        static const char *const keys[] = {
            "status", "code", "enhanced", "message", "id", "transport", "recipients",
        };
        HV *h;
        SV *v;
    CODE:
        h = pmail_self(aTHX_ self, keys[ix]);
        v = pmail_hv_get(aTHX_ h, keys[ix]);
        RETVAL = v ? newSVsv(v) : newSV(0);
    OUTPUT:
        RETVAL

# the status as a question
IV
accepted(self)
        SV *self
    ALIAS:
        deferred  = 1
        rejected  = 2
        failed    = 3
        unsent    = 4
        retryable = 5
    PREINIT:
        const char *st;
    CODE:
        (void)pmail_self(aTHX_ self, "status");
        st = pmail_result_status(aTHX_ self);
        switch (ix) {
        case 0:  RETVAL = strEQ(st, PMAIL_ST_ACCEPTED); break;
        case 1:  RETVAL = strEQ(st, PMAIL_ST_DEFERRED); break;
        case 2:  RETVAL = strEQ(st, PMAIL_ST_REJECTED); break;
        case 3:  RETVAL = strEQ(st, PMAIL_ST_FAILED);   break;
        case 4:  RETVAL = strEQ(st, PMAIL_ST_UNSENT);   break;
        default: RETVAL = strEQ(st, PMAIL_ST_DEFERRED) || strEQ(st, PMAIL_ST_FAILED); break;
        }
    OUTPUT:
        RETVAL
