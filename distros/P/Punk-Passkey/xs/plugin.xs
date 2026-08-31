MODULE = Punk::Passkey    PACKAGE = Punk::Plugin::Passkey

PROTOTYPES: DISABLE

# plugin 'Passkey' => \%opts, via Punk: validates the options, freezes
# the configuration under the application class, mounts the routes and
# installs the helpers.
#
# What it does NOT do is decide what logging in means. The login route
# hands the verified user id to the application's own sign_in, so
# session rotation and redirect policy stay in the one place every
# other factor already uses them.
void
register(class, app, opts = &PL_sv_undef)
    SV *class
    SV *app
    SV *opts
  CODE:
    PERL_UNUSED_VAR(class);
    ppk_plugin_register(aTHX_ app, opts);

# The frozen configuration for an application class - the test and
# introspection seam, the same shape Punk::Plugin::TOTP exposes.
SV *
state_for(...)
  CODE:
    {
        SV **e = NULL;
        if (items > 0 && PPK_STATE) {
            STRLEN kl;
            const char *k = SvPV_const(ST(items - 1), kl);
            e = hv_fetch(PPK_STATE, k, (I32)kl, 0);
        }
        RETVAL = (e && *e) ? newSVsv(*e) : newSV(0);
    }
  OUTPUT:
    RETVAL

# The JavaScript this plugin serves, for a test that wants to assert on
# it without going through a request.
SV *
_asset()
  CODE:
    RETVAL = newSVpvn(PPK_JS, sizeof(PPK_JS) - 1);
  OUTPUT:
    RETVAL
