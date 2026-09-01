MODULE = Punk::Authorisation    PACKAGE = Punk::Plugin::Authorisation

PROTOTYPES: DISABLE

# The whole plugin. lib/Punk/Plugin/Authorisation.pm is documentation and a
# version number; option validation, the rule registry, `rule`, the helpers
# and the grants half are all C.
#
# One vocabulary in one place is the reason, and here there is a second: the
# 403-versus-404 choice leaks row ids when it is wrong, and security-shaped
# branches are worth keeping where the tests are.

# plugin 'Authorisation' => \%opts
void
register(class, app, opts = &PL_sv_undef)
        SV *class
        SV *app
        SV *opts
    CODE:
        PERL_UNUSED_VAR(class);
        paz_register(aTHX_ app, opts);

# `use Punk::Plugin::Authorisation;` in a POLICY package installs `rule` into
# it. The caller is not an application class and needs none: the rules are
# recorded per policy package, and `plugin 'Authorisation'` takes them.
void
import(class, ...)
        SV *class
    CODE:
    {
        SV *caller;
        PERL_UNUSED_VAR(class);
        PERL_UNUSED_VAR(items);
        caller = sv_2mortal(newSVpv(CopSTASHPV(PL_curcop), 0));
        if (!SvCUR(caller) || strEQ(SvPVX(caller), "main")) XSRETURN_EMPTY;
        paz_install_rule(aTHX_ caller);
    }

# The live configuration for an application class. A seam for tests, not an
# API: the shape changes when the plugin does.
SV *
state_for(class, app_class)
        SV *class
        SV *app_class
    CODE:
    {
        HV *cfg = paz_state_for(aTHX_ app_class);
        PERL_UNUSED_VAR(class);
        RETVAL = cfg ? newRV_inc((SV *)cfg) : newSV(0);
    }
    OUTPUT:
        RETVAL

# The rules a policy package has declared, as a copy: for tests, and for a
# `punk` command that wants to list them.
SV *
rules_for(class, policy)
        SV *class
        SV *policy
    CODE:
    {
        HV *rules = paz_rules_of(aTHX_ policy, 0);
        PERL_UNUSED_VAR(class);
        RETVAL = rules ? newRV_noinc((SV *)newHVhv(rules)) : newSV(0);
    }
    OUTPUT:
        RETVAL
