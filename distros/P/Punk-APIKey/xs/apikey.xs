MODULE = Punk::APIKey    PACKAGE = Punk::Plugin::APIKey

PROTOTYPES: DISABLE

# The whole plugin. lib/Punk/Plugin/APIKey.pm is documentation and a version
# number; option validation, the configuration, the guard, the checker, issue,
# revoke, list and the owner-standing read are all C.
#
# One vocabulary in one place is the reason. Splitting boot across two
# languages means two files to keep in step over the same option names - and
# boot is the half that has to be exact, because an option that silently did
# not apply is a setting nobody can see is missing.

# plugin 'APIKey' => \%opts
void
register(class, app, opts = &PL_sv_undef)
        SV *class
        SV *app
        SV *opts
    CODE:
        PERL_UNUSED_VAR(class);
        pak_register(aTHX_ app, opts);

# `use Punk::Plugin::APIKey;` in an application class, above the routes, is
# what makes the bareword forms parse.
#
# A keyword must exist before the line using it is COMPILED, and every other
# statement in an application class - `plugin`, `under`, the routes - runs
# afterwards, in order. So the keywords go in from here, and resolve their
# configuration when CALLED, by which time `plugin 'APIKey'` has run.
#
# Installing twice from one owner is a no-op in Punk (xs/app.xs's install_kw
# sets done and returns), so a placeholder here could never be replaced later.
# That is why these are the real thing.
void
import(class, ...)
        SV *class
    CODE:
    {
        SV *caller, *app;
        HV *stash;
        PERL_UNUSED_VAR(class);
        PERL_UNUSED_VAR(items);

        caller = sv_2mortal(newSVpv(CopSTASHPV(PL_curcop), 0));
        stash = gv_stashsv(caller, 0);
        if (!(stash && gv_fetchmethod_autoload(stash, "punk_app", 0)))
            XSRETURN_EMPTY;          /* not an application class: nothing to do */
        app = sv_2mortal(pak_call(aTHX_ caller, "punk_app", NULL, 0));
        if (!(app && SvROK(app))) XSRETURN_EMPTY;

        /* The configuration does not exist yet - `plugin 'APIKey'` runs
         * later - so these carry the CLASS and look the state up when they
         * are called. Their bodies croak with the fix if it never ran. */
        {
            /* An empty hash stands in for the configuration these do not have
             * yet; pak_closure takes its own reference, so the one made here
             * is released and the closure holds the only one. */
            HV *none = newHV();
            SV *argv[3];

            argv[0] = sv_2mortal(newSVpvs("api_key_guard"));
            argv[1] = sv_2mortal(pak_closure(aTHX_ pak_kw_early_guard,
                                              none, caller));
            argv[2] = sv_2mortal(newSVpvs(PAK_WHO));
            SvREFCNT_dec(pak_call(aTHX_ app, "install_kw", argv, 3));

            argv[0] = sv_2mortal(newSVpvs("api_key_checker"));
            argv[1] = sv_2mortal(pak_closure(aTHX_ pak_kw_early_checker,
                                              none, caller));
            argv[2] = sv_2mortal(newSVpvs(PAK_WHO));
            SvREFCNT_dec(pak_call(aTHX_ app, "install_kw", argv, 3));

            SvREFCNT_dec((SV *)none);
        }
    }

# The live configuration for an application class. A seam for tests and for
# the CLI, not an API: the shape changes when the plugin does.
SV *
state_for(class, app_class)
        SV *class
        SV *app_class
    CODE:
    {
        HV *cfg = pak_state_for(aTHX_ app_class);
        PERL_UNUSED_VAR(class);
        RETVAL = cfg ? newRV_inc((SV *)cfg) : newSV(0);
    }
    OUTPUT:
        RETVAL

# ---- issue, revoke, list ------------------------------------------------------
#
# What the context helpers call, for a CLI or a job with no request to reach a
# context through.

void
issue_for(class, app_class, ...)
        SV *class
        SV *app_class
    PPCODE:
    {
        HV *cfg = pak_state_for(aTHX_ app_class);
        HV *args;
        SV *key = NULL, *row = NULL;
        int i;
        PERL_UNUSED_VAR(class);

        if (!cfg)
            croak(PAK_WHO ": %s has no APIKey plugin registered",
                  SvPV_nolen(app_class));
        if ((items - 2) % 2)
            croak(PAK_WHO ": issue_for takes name => value pairs");

        args = (HV *)sv_2mortal((SV *)newHV());
        for (i = 2; i + 1 < items; i += 2) {
            STRLEN kl;
            const char *k = SvPV_const(ST(i), kl);
            (void)hv_store(args, k, (I32)kl, newSVsv(ST(i + 1)), 0);
        }
        {
            SV *pub;
            pak_issue(aTHX_ cfg, args, &key, &row);
            pub = pak_public(aTHX_ sv_2mortal(row), cfg);
            sv_2mortal(key);
            sv_2mortal(pub);

            /* pak_issue calls into Perl - create, and maybe update - and every
             * one of those moves the real stack. The SP this scope has held
             * since xsubpp's `SP -= items` is stale by now, so pushing on it
             * writes the return values somewhere nobody reads. Put SP back
             * where the arguments started, which is where the return values
             * belong. (ST() does not have this problem: it indexes off ax,
             * which nothing moves - which is why the helper form is written
             * that way.) */
            SPAGAIN;
            SP = PL_stack_base + ax - 1;
            EXTEND(SP, 2);
            PUSHs(key);
            PUSHs(pub);
        }
    }

SV *
revoke_for(class, app_class, id)
        SV *class
        SV *app_class
        SV *id
    CODE:
    {
        HV *cfg = pak_state_for(aTHX_ app_class);
        PERL_UNUSED_VAR(class);
        if (!cfg)
            croak(PAK_WHO ": %s has no APIKey plugin registered",
                  SvPV_nolen(app_class));
        RETVAL = pak_revoke(aTHX_ cfg, id);
    }
    OUTPUT:
        RETVAL

SV *
keys_for(class, app_class, owner = &PL_sv_undef)
        SV *class
        SV *app_class
        SV *owner
    CODE:
    {
        HV *cfg = pak_state_for(aTHX_ app_class);
        PERL_UNUSED_VAR(class);
        if (!cfg)
            croak(PAK_WHO ": %s has no APIKey plugin registered",
                  SvPV_nolen(app_class));
        RETVAL = pak_keys(aTHX_ cfg, SvOK(owner) ? owner : NULL);
    }
    OUTPUT:
        RETVAL

# Drop this worker's cached owner standings. The CLI calls it after a change
# an operator expects to take effect now rather than within owner_ttl.
void
forget_owners(class, app_class)
        SV *class
        SV *app_class
    CODE:
    {
        HV *cfg = pak_state_for(aTHX_ app_class);
        PERL_UNUSED_VAR(class);
        if (cfg) (void)hv_stores(cfg, "owner_cache", newRV_noinc((SV *)newHV()));
    }

# ---- the key, exposed for the vectors ----------------------------------------

# _mint($prefix) -> the whole key. The plaintext exists here and nowhere else:
# nothing in this distribution stores it.
SV *
_mint(class, prefix)
        SV *class
        SV *prefix
    CODE:
        PERL_UNUSED_VAR(class);
        RETVAL = pak_mint(aTHX_ prefix);
    OUTPUT:
        RETVAL

# _checksum($random) -> the six base62 characters for a 43-character random
# part, so a test can mangle one and know what it mangled.
SV *
_checksum(class, random)
        SV *class
        SV *random
    CODE:
    {
        STRLEN rl;
        const char *rp = SvPV_const(random, rl);
        char ck[PAK_CK_LEN];
        PERL_UNUSED_VAR(class);
        pak_b62_6(pak_crc32(rp, rl), ck);
        RETVAL = newSVpvn(ck, PAK_CK_LEN);
    }
    OUTPUT:
        RETVAL

# _parse(\%kinds, $key) -> ($verdict, $kind). The verdict is one of the
# strings below rather than a number, because a test that says
# 'bad_checksum' reads and a test that says 2 does not.
void
_parse(class, kinds, key)
        SV *class
        SV *kinds
        SV *key
    PPCODE:
    {
        STRLEN kl;
        const char *kp;
        SV *kind = NULL;
        int v;
        const char *name;
        PERL_UNUSED_VAR(class);

        if (!pak_is_hash(kinds))
            croak(PAK_WHO "::_parse: kinds must be a hashref");
        kp = SvPV_const(key, kl);
        v = pak_parse(aTHX_ (HV *)SvRV(kinds), kp, kl, &kind);
        name = v == PAK_OK           ? "ok"
             : v == PAK_MALFORMED    ? "malformed"
             : v == PAK_BAD_CHECKSUM ? "bad_checksum"
             :                         "unknown_kind";
        EXTEND(SP, 2);
        PUSHs(sv_2mortal(newSVpv(name, 0)));
        PUSHs(kind ? sv_2mortal(newSVsv(kind)) : &PL_sv_undef);
    }

# _digest($key) -> the stored form. Punk::Auth::Password::token_digest, so
# this and auth_tokens.digest are the same wire form.
SV *
_digest(class, key)
        SV *class
        SV *key
    CODE:
        PERL_UNUSED_VAR(class);
        RETVAL = pak_digest(aTHX_ key);
    OUTPUT:
        RETVAL

# _stored_prefix($key, $prefix_len) -> the `prefix` column.
SV *
_stored_prefix(class, key, plen)
        SV *class
        SV *key
        IV plen
    CODE:
        PERL_UNUSED_VAR(class);
        RETVAL = pak_stored_prefix(aTHX_ key, (STRLEN)plen);
    OUTPUT:
        RETVAL

# _guard_for(\%cfg, $scope) / _checker_for(\%cfg, $scope): what the keywords
# build. Exposed so a test can drive a checker without an OpenAPI mount.
SV *
_guard_for(class, cfg, scope = &PL_sv_undef)
        SV *class
        SV *cfg
        SV *scope
    CODE:
    {
        PERL_UNUSED_VAR(class);
        if (!pak_is_hash(cfg))
            croak(PAK_WHO "::_guard_for: cfg must be a hashref");
        RETVAL = pak_closure(aTHX_ pak_k_guard, (HV *)SvRV(cfg),
                              SvOK(scope) ? scope : NULL);
    }
    OUTPUT:
        RETVAL

SV *
_checker_for(class, cfg, scope = &PL_sv_undef)
        SV *class
        SV *cfg
        SV *scope
    CODE:
    {
        PERL_UNUSED_VAR(class);
        if (!pak_is_hash(cfg))
            croak(PAK_WHO "::_checker_for: cfg must be a hashref");
        RETVAL = pak_closure(aTHX_ pak_k_checker, (HV *)SvRV(cfg),
                              SvOK(scope) ? scope : NULL);
    }
    OUTPUT:
        RETVAL

# _check_guard_opts(\%cfg, \%opts) -> the scope, validated. The check a
# keyword does, reachable so a test can assert the boot croak without
# compiling an application that cannot boot.
SV *
_check_guard_opts(class, cfg, opts)
        SV *class
        SV *cfg
        SV *opts
    CODE:
    {
        HV *o;
        SV **flat;
        int n = 0, i = 0;
        HE *he;
        SV *scope;
        PERL_UNUSED_VAR(class);

        if (!pak_is_hash(cfg) || !pak_is_hash(opts))
            croak(PAK_WHO "::_check_guard_opts: two hashrefs");
        o = (HV *)SvRV(opts);
        n = (int)HvUSEDKEYS(o) * 2;
        Newx(flat, n ? n : 1, SV *);
        hv_iterinit(o);
        while ((he = hv_iternext(o))) {
            flat[i++] = sv_2mortal(newSVsv(HeSVKEY_force(he)));
            flat[i++] = HeVAL(he);
        }
        scope = pak_guard_scope(aTHX_ (HV *)SvRV(cfg), flat, n);
        Safefree(flat);
        RETVAL = scope ? newSVsv(scope) : newSV(0);
    }
    OUTPUT:
        RETVAL
