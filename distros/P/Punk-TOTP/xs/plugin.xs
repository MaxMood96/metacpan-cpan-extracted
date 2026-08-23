MODULE = Punk::TOTP    PACKAGE = Punk::Plugin::TOTP

PROTOTYPES: DISABLE

# plugin 'TOTP' => \%opts, via Punk: validates the options, freezes the
# configuration under the application class, and installs the helpers,
# the challenge routes, the rate limit and the totp_guard keyword
# (ptotp_plugin.h).
void
register(class, app, opts = &PL_sv_undef)
    SV *class
    SV *app
    SV *opts
  CODE:
    PERL_UNUSED_VAR(class);
    pp_register(aTHX_ app, opts);

# The configuration for an application class - the test and introspection
# seam. The hash is live: a value changed here is what the next request
# reads.
SV *
state_for(...)
  CODE:
    {
        SV **e = NULL;
        if (items > 0 && PP_STATE) {
            STRLEN kl;
            const char *k = SvPV_const(ST(items - 1), kl);
            e = hv_fetch(PP_STATE, k, (I32)kl, 0);
        }
        RETVAL = (e && *e) ? newSVsv(*e) : newSV(0);
    }
  OUTPUT:
    RETVAL

# The recovery digest: case folded, grouping stripped, lowercase sha256
# hex - pwd_token_digest's wire form.
SV *
_recovery_digest(code)
    SV *code
  CODE:
    RETVAL = pp_recovery_digest(aTHX_ code);
  OUTPUT:
    RETVAL
