MODULE = Punk::Passkey    PACKAGE = Punk::Passkey

PROTOTYPES: DISABLE

# The authentication ceremony, at engine level - the same shape as
# registration's, for the same reason: phase 3's keyword will install
# these as $c->passkey_challenge and $c->passkey_verify, and the tests
# and any application with an unusual flow use the same door.

# challenge($c, \%args) -> the PublicKeyCredentialRequestOptions
# hashref, with a fresh challenge left in the session.
#
# %args: allow (arrayref of base64url credential ids - omit for the
# usernameless flow), user_verification.
SV *
challenge(c, args = &PL_sv_undef)
        SV *c
        SV *args
    CODE:
    {
        HV *a = (args && SvROK(args) && SvTYPE(SvRV(args)) == SVt_PVHV)
              ? (HV *)SvRV(args) : NULL;
        RETVAL = ppk_challenge_options(aTHX_ c, a);
    }
    OUTPUT:
        RETVAL

# verify($c, \%assertion, \%args) -> the accepted login, or undef.
#
# The failure is uniform, and here that is not a stylistic preference:
# an unknown credential id and a bad signature must be one answer, or
# the login endpoint tells anyone who asks which credential ids this
# application knows - and a credential id identifies a person's
# authenticator. The reason goes to the log.
SV *
verify(c, assertion, args = &PL_sv_undef)
        SV *c
        SV *assertion
        SV *args
    CODE:
    {
        HV *body, *a;
        const char *why = NULL;
        SV *out;
        if (!(assertion && SvROK(assertion)
              && SvTYPE(SvRV(assertion)) == SVt_PVHV))
            croak("Punk::Passkey::verify: the assertion must be a hashref "
                  "of the browser's credential response");
        body = (HV *)SvRV(assertion);
        a = (args && SvROK(args) && SvTYPE(SvRV(args)) == SVt_PVHV)
          ? (HV *)SvRV(args) : NULL;
        out = ppk_verify(aTHX_ c, body, a, &why);
        sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD), why ? why : "");
        if (!out) {
            SV *line = sv_2mortal(newSVpvs("passkey login refused: "));
            sv_catpv(line, (char *)(why ? why : "unknown"));
            ppk_warn(aTHX_ c, SvPVX(line));
            XSRETURN_UNDEF;
        }
        RETVAL = out;
    }
    OUTPUT:
        RETVAL
