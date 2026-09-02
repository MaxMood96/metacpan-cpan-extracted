#ifndef PAU_AUTHZ_BOOT_H
#define PAU_AUTHZ_BOOT_H

/* Punk::Plugin::Authorisation's boot: `use` installs `rule` into the policy
 * package, `plugin 'Authorisation'` takes the rules and installs the helpers.
 *
 * Include after pau_authz.h.
 */

/* `use Punk::Plugin::Authorisation;` in a policy package.
 *
 * The caller here is the POLICY package, not the application class - it has
 * no punk_app and wants none. What it gets is `rule`, closed over its own
 * name, so one body serves every policy package in the process.
 *
 * A package that already has a `rule` keeps it: this must not quietly
 * replace something the application defined.
 */
static void paz_install_rule(pTHX_ SV *pkg)
{
    STRLEN pl;
    const char *pp = SvPV_const(pkg, pl);
    SV *name = sv_2mortal(newSVsv(pkg));
    HV *none;
    SV *code;
    GV *gv;

    sv_catpvs(name, "::rule");
    gv = gv_fetchpvn_flags(SvPVX(name), SvCUR(name), 0, SVt_PVCV);
    if (gv && GvCV(gv)) return;                  /* already has one */
    PERL_UNUSED_VAR(pp);
    PERL_UNUSED_VAR(pl);

    none = newHV();
    code = sv_2mortal(pau_closure(aTHX_ paz_kw_rule, none, pkg));
    SvREFCNT_dec((SV *)none);                    /* the closure holds its own */

    gv = gv_fetchpvn_flags(SvPVX(name), SvCUR(name), GV_ADD, SVt_PVCV);
    sv_setsv((SV *)gv, code);                    /* *{"Pkg::rule"} = $code */
}

/* The on_compile callback: resolve the grants model once every keyword has
 * recorded, so a `model` declared below the plugin line is still found. */
XS_INTERNAL(paz_boot_model);
XS_INTERNAL(paz_boot_model)
{
    dXSARGS;
    HV *cfg = pau_cfg_of(aTHX_ cv);
    if (items > 0) pau_ensure_model(aTHX_ ST(0), cfg, "Punk::Model::Grant");
    XSRETURN_EMPTY;
}

/* plugin 'Authorisation' => \%opts */
static void paz_register(pTHX_ SV *app, SV *opts_sv)
{
    HV *opts = pau_is_hash(opts_sv) ? (HV *)SvRV(opts_sv) : NULL;
    HV *cfg;
    SV *class_sv, *policy, *grants, *rank = NULL, *auth = NULL;
    HV *rules;

    pau_check_opts(aTHX_ PAZ_WHO, NULL, opts, PAZ_OPTS);

    class_sv = sv_2mortal(pau_call(aTHX_ app, "caller_class", NULL, 0));
    if (!(class_sv && SvOK(class_sv)))
        croak(PAZ_WHO ": no application class");

    /* The policy package: <AppClass>::Authorisation unless named. */
    {
        SV *given = opts ? pau_hget(aTHX_ opts, "policy") : NULL;
        if (given && SvOK(given)) policy = sv_2mortal(newSVsv(given));
        else {
            policy = sv_2mortal(newSVsv(class_sv));
            sv_catpvs(policy, "::Authorisation");
        }
    }
    {   /* a package name, and nothing else */
        STRLEN pl;
        const char *pp = SvPV_const(policy, pl), *q = pp;
        int ok = pl > 0;
        while (ok && q < pp + pl) {
            if (!(isALPHA(*q) || *q == '_')) { ok = 0; break; }
            while (q < pp + pl && (isALNUM(*q) || *q == '_')) q++;
            if (q + 1 < pp + pl && q[0] == ':' && q[1] == ':') q += 2;
            else break;
        }
        if (!ok || q != pp + pl)
            croak(PAZ_WHO ": policy must be a package name, not '%s'",
                  SvPV_nolen(policy));
    }

    /* Load it here so `rule` has run by the time the rules are taken. A
     * package already in memory is left alone: it may have no file at all -
     * one declared in the application's own file, or in a test - and
     * requiring it would report "cannot load" for what is really "defines
     * no rules". */
    rules = paz_rules_of(aTHX_ policy, 0);
    if (!rules) {
        HV *stash = gv_stashsv(policy, 0);
        int in_memory = stash && HvKEYS(stash);
        if (!in_memory) {
            SV *req = sv_2mortal(newSVpvs("require "));
            sv_catsv(req, policy);
            sv_catpvs(req, "; 1");
            eval_pv(SvPV_nolen(req), FALSE);
            if (SvTRUE(ERRSV)) {
                SV *err = sv_2mortal(newSVsv(ERRSV));
                croak(PAZ_WHO ": cannot load the policy package %s: %s",
                      SvPV_nolen(policy), SvPV_nolen(err));
            }
        }
        rules = paz_rules_of(aTHX_ policy, 0);
    }
    if (!rules || !HvKEYS(rules))
        croak(PAZ_WHO ": %s defines no rules - a policy package says "
              "`use Punk::Plugin::Authorisation;` and then "
              "`rule NAME => sub {...}`", SvPV_nolen(policy));

    /* The ladder comes from the `auth` keyword, never from a second copy
     * here: auth_guard(role => ...) reads that one, and two ladders drift.
     * `rank => []` is how a policy that never asks about rank says so. */
    if (opts) rank = pau_hget(aTHX_ opts, "rank");
    {
        int can_ask = SvROK(app)
            && gv_fetchmethod_autoload(SvSTASH(SvRV(app)), "auth_config", 0) != NULL;
        if (can_ask)
            auth = sv_2mortal(pau_call(aTHX_ app, "auth_config", NULL, 0));
        if (!(rank && SvOK(rank)) && auth && pau_is_hash(auth)) {
            SV *r = pau_hget(aTHX_ (HV *)SvRV(auth), "rank");
            if (pau_is_array(r) && av_len((AV *)SvRV(r)) >= 0) rank = r;
        }
        if (rank && SvOK(rank) && !pau_is_array(rank))
            croak(PAZ_WHO ": rank must be an arrayref of role names, lowest first");

        /* No ladder, and none asked for. `rank_at_least` would croak on every
         * name it was ever given, which is a 500 per request for something
         * knowable now - so it is knowable now. The two ways to arrive here
         * are different problems and the message names both. */
        if (!(rank && SvOK(rank))) {
            if (!can_ask)
                croak(PAZ_WHO ": no rank ladder. This Punk does not provide "
                      "$app->auth_config (0.32 and later do), so the ladder "
                      "`auth rank => [...]` declares cannot be read here: pass "
                      "rank => [...] to the plugin, or rank => [] for a policy "
                      "that never calls rank_at_least");
            croak(PAZ_WHO ": no rank ladder - `auth rank => [...]` declares "
                  "one, or pass rank => [...] to the plugin; a policy that "
                  "never calls rank_at_least says rank => []");
        }
    }

    cfg = newHV();
    (void)hv_stores(cfg, "class",  newSVsv(class_sv));
    (void)hv_stores(cfg, "policy", newSVsv(policy));
    (void)hv_stores(cfg, "rules",  newRV_noinc((SV *)newHVhv(rules)));
    {   /* An empty ladder has no AvARRAY at all, and av_make asserts its
         * pointer before it looks at the count - so `rank => []` aborts a
         * DEBUGGING perl. Copy only when there is something to copy. */
        AV *src = (rank && pau_is_array(rank)) ? (AV *)SvRV(rank) : NULL;
        SSize_t n = src ? av_len(src) + 1 : 0;
        (void)hv_stores(cfg, "rank",
            newRV_noinc((SV *)(n > 0 ? av_make(n, AvARRAY(src)) : newAV())));
    }
    {   /* The roles hook is the other half of the ladder: the ladder orders
         * the names, the hook says which the signed-in user holds. It comes
         * from the same `auth` keyword, and on a Punk that cannot be asked
         * the application passes it here - otherwise rank_at_least would
         * answer "no" to everything, which is a refusal nobody can explain.
         *
         * A guard that has already run leaves its roles in the stash, and
         * paz_roles_of prefers those; the hook is for the rest. */
        SV *given = opts ? pau_hget(aTHX_ opts, "roles") : NULL;
        SV *hook = NULL;
        if (given && SvOK(given)) {
            if (!(SvROK(given) && SvTYPE(SvRV(given)) == SVt_PVCV))
                croak(PAZ_WHO ": roles must be a coderef - the same one "
                      "`auth roles => sub {...}` takes");
            hook = given;
        }
        else if (auth && pau_is_hash(auth)) {
            SV *h = pau_hget(aTHX_ (HV *)SvRV(auth), "roles");
            if (h && SvROK(h)) hook = h;
        }
        if (hook) (void)hv_stores(cfg, "roles", newSVsv(hook));
    }

    grants = opts ? pau_hget(aTHX_ opts, "grants") : NULL;
    if (grants && SvOK(grants)) {
        /* the toolkit reads the model under `model`; `grants` is the switch */
        (void)hv_stores(cfg, "grants", newSViv(1));
        (void)hv_stores(cfg, "model", newSVsv(grants));
        {
            SV *f = opts ? pau_hget(aTHX_ opts, "fields") : NULL;
            (void)hv_stores(cfg, "fields",
                newRV_noinc((SV *)paz_field_map(aTHX_
                    pau_is_hash(f) ? (HV *)SvRV(f) : NULL)));
        }
    }
    else if (opts && pau_hget(aTHX_ opts, "fields"))
        croak(PAZ_WHO ": fields names the grants table's columns, and grants "
              "are off - add grants => 'Model' or drop fields");

    if (!PAZ_STATE) PAZ_STATE = newHV();
    (void)hv_store_ent(PAZ_STATE, class_sv, newRV_inc((SV *)cfg), 0);

    /* The schema, as a Sqitch project - only with grants. An application
     * with no grants should not carry the table. */
    if (grants && SvOK(grants))
        pau_sqitch(aTHX_ app, "punk_authz",
                    pau_beside(aTHX_ "Punk/Plugin/Authorisation.pm",
                                "Authorisation.pm", "Authorisation/sqitch"),
                    PAZ_ENGINES);

    pau_helper(aTHX_ app, "may",           paz_h_may,       cfg, NULL);
    pau_helper(aTHX_ app, "deny",          paz_h_deny,      cfg, NULL);
    pau_helper(aTHX_ app, "forbidden",     paz_h_forbidden, cfg, NULL);
    pau_helper(aTHX_ app, "not_yours",     paz_h_not_yours, cfg, NULL);
    pau_helper(aTHX_ app, "rank_at_least", paz_h_rank,      cfg, NULL);

    if (grants && SvOK(grants)) {
        pau_helper(aTHX_ app, "granted",      paz_h_granted, cfg, NULL);
        pau_helper(aTHX_ app, "grant",        paz_h_grant,   cfg, NULL);
        pau_helper(aTHX_ app, "revoke_grant", paz_h_revoke,  cfg, NULL);

        /* The model has to exist by the time a request asks. Checked at
         * compile rather than here, because `model` may be declared below
         * this line. */
        if (gv_fetchmethod_autoload(SvSTASH(SvRV(app)), "on_compile", 0)) {
            SV *argv[2];
            argv[0] = sv_2mortal(pau_closure(aTHX_ paz_boot_model, cfg, NULL));
            argv[1] = sv_2mortal(newSVpvs(PAZ_WHO));
            SvREFCNT_dec(pau_call(aTHX_ app, "on_compile", argv, 2));
        }
        else pau_ensure_model(aTHX_ app, cfg, "Punk::Model::Grant");
    }

    SvREFCNT_dec((SV *)cfg);        /* the state and the closures hold it */
}

#endif /* PAU_AUTHZ_BOOT_H */
