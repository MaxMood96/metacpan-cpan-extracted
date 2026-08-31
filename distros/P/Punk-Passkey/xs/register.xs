MODULE = Punk::Passkey    PACKAGE = Punk::Passkey

PROTOTYPES: DISABLE

# The registration ceremony, at engine level: two functions taking the
# context, because phase 1 owns the protocol and phase 3 owns the
# keyword that will install them as $c->passkey_register_options and
# $c->passkey_register.
#
# Keeping the engine callable without the plugin is not only about
# build order. A ceremony that can only be reached through a keyword
# can only be TESTED through a keyword, and the tests here drive it
# from a hand-written route - which is also how an application with an
# unusual flow will drive it.

# register_options($c, \%args) -> the PublicKeyCredentialCreationOptions
# hashref, with a fresh challenge left in the session.
#
# %args: user_id (required), user_name, user_display_name, rp_name,
# user_verification, resident_key, exclude (arrayref of base64url
# credential ids).
SV *
register_options(c, args = &PL_sv_undef)
        SV *c
        SV *args
    CODE:
    {
        HV *a = (args && SvROK(args) && SvTYPE(SvRV(args)) == SVt_PVHV)
              ? (HV *)SvRV(args) : NULL;
        RETVAL = ppk_register_options(aTHX_ c, a);
    }
    OUTPUT:
        RETVAL

# register($c, \%response, \%args) -> the credential to store, or undef.
#
# The failure is UNIFORM: every refusal returns undef and logs its
# reason at warn. A ceremony that told the caller which check failed
# would be describing, to whoever sent the bytes, exactly what to
# change - and the caller who legitimately wants to know looks in the
# log, where the request id and the path are already waiting.
SV *
register(c, response, args = &PL_sv_undef)
        SV *c
        SV *response
        SV *args
    CODE:
    {
        HV *body, *a;
        const char *why = NULL;
        SV *out;
        if (!(response && SvROK(response)
              && SvTYPE(SvRV(response)) == SVt_PVHV))
            croak("Punk::Passkey::register: the response must be a hashref "
                  "of the browser's credential response");
        body = (HV *)SvRV(response);
        a = (args && SvROK(args) && SvTYPE(SvRV(args)) == SVt_PVHV)
          ? (HV *)SvRV(args) : NULL;
        out = ppk_register(aTHX_ c, body, a, &why);
        sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD), why ? why : "");
        if (!out) {
            SV *line = sv_2mortal(newSVpvs("passkey registration refused: "));
            sv_catpv(line, (char *)(why ? why : "unknown"));
            ppk_warn(aTHX_ c, SvPVX(line));
            XSRETURN_UNDEF;
        }
        RETVAL = out;
    }
    OUTPUT:
        RETVAL
