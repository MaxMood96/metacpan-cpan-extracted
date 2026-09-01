#ifndef PAK_APIKEY_BOOT_H
#define PAK_APIKEY_BOOT_H

/* Punk::Plugin::APIKey's `register`.
 *
 * Last of the three APIKey headers, because it installs the guard and the
 * checker and so needs their addresses: pak_apikey_reg.h has the state and
 * the writers, pak_apikey.h the per-request bodies, this the boot.
 *
 * Everything an application can get wrong is refused here, by name, with what
 * it could have meant. Boot is where a plugin's diagnostics have to be exact:
 * an option that silently did not apply is a setting nobody can see is
 * missing, and for anything guarding a route that is a door left open.
 */

/* The keywords as `import` installs them, before `plugin 'APIKey'` has run.
 *
 * They carry the application CLASS rather than a configuration, and look the
 * configuration up when they are CALLED - by which time the plugin line has
 * run, because every statement in an application class after the `use` runs
 * in order. One keyword, both spellings, and no window in which it exists but
 * cannot check the scope it is given.
 *
 * If the plugin line never ran, the croak says what to do rather than letting
 * a guard exist that can check nothing. */
XS_INTERNAL(pak_kw_early_guard);
XS_INTERNAL(pak_kw_early_guard)
{
    dXSARGS;
    SV *class_sv = pak_arg_of(aTHX_ cv);
    HV *cfg = pak_state_for(aTHX_ class_sv);
    SV *scope;
    if (!cfg)
        croak(PAK_WHO ": api_key_guard used before plugin 'APIKey' - move "
              "the plugin line above the routes");
    scope = pak_guard_scope(aTHX_ cfg, &ST(0), (int)items);
    ST(0) = sv_2mortal(pak_closure(aTHX_ pak_k_guard, cfg, scope));
    XSRETURN(1);
}

XS_INTERNAL(pak_kw_early_checker);
XS_INTERNAL(pak_kw_early_checker)
{
    dXSARGS;
    SV *class_sv = pak_arg_of(aTHX_ cv);
    HV *cfg = pak_state_for(aTHX_ class_sv);
    SV *scope;
    if (!cfg)
        croak(PAK_WHO ": api_key_checker used before plugin 'APIKey' - move "
              "the plugin line above the routes");
    scope = pak_guard_scope(aTHX_ cfg, &ST(0), (int)items);
    ST(0) = sv_2mortal(pak_closure(aTHX_ pak_k_checker, cfg, scope));
    XSRETURN(1);
}

/* the keywords as `register` installs them, for an application that wrote
 * `plugin 'APIKey'` without the `use`: the parenthesised form still works */
XS_INTERNAL(pak_kw_guard);
XS_INTERNAL(pak_kw_guard)
{
    dXSARGS;
    HV *cfg = pak_cfg_of(aTHX_ cv);
    SV *scope = pak_guard_scope(aTHX_ cfg, &ST(0), (int)items);
    ST(0) = sv_2mortal(pak_closure(aTHX_ pak_k_guard, cfg, scope));
    XSRETURN(1);
}

XS_INTERNAL(pak_kw_checker);
XS_INTERNAL(pak_kw_checker)
{
    dXSARGS;
    HV *cfg = pak_cfg_of(aTHX_ cv);
    SV *scope = pak_guard_scope(aTHX_ cfg, &ST(0), (int)items);
    ST(0) = sv_2mortal(pak_closure(aTHX_ pak_k_checker, cfg, scope));
    XSRETURN(1);
}

/* ---- the context helpers -------------------------------------------------- */

XS_INTERNAL(pak_h_issue);
XS_INTERNAL(pak_h_issue)
{
    dXSARGS;
    HV *cfg = pak_cfg_of(aTHX_ cv);
    HV *args = (HV *)sv_2mortal((SV *)newHV());
    SV *key = NULL, *row = NULL;
    int i;

    if ((items - 1) % 2)
        croak(PAK_WHO ": api_key_issue takes name => value pairs");
    for (i = 1; i + 1 < items; i += 2) {
        STRLEN kl;
        const char *k = SvPV_const(ST(i), kl);
        (void)hv_store(args, k, (I32)kl, newSVsv(ST(i + 1)), 0);
    }
    pak_issue(aTHX_ cfg, args, &key, &row);

    /* the plaintext and the row, in that order - and the row without its
     * digest, because nothing outside this plugin has any use for it */
    EXTEND(SP, 2);
    ST(0) = sv_2mortal(key);
    ST(1) = sv_2mortal(pak_public(aTHX_ sv_2mortal(row), cfg));
    XSRETURN(2);
}

XS_INTERNAL(pak_h_revoke);
XS_INTERNAL(pak_h_revoke)
{
    dXSARGS;
    HV *cfg = pak_cfg_of(aTHX_ cv);
    if (items < 2) croak(PAK_WHO ": api_key_revoke needs an id");
    ST(0) = sv_2mortal(pak_revoke(aTHX_ cfg, ST(1)));
    XSRETURN(1);
}

XS_INTERNAL(pak_h_keys);
XS_INTERNAL(pak_h_keys)
{
    dXSARGS;
    HV *cfg = pak_cfg_of(aTHX_ cv);
    ST(0) = sv_2mortal(pak_keys(aTHX_ cfg, items > 1 ? ST(1) : NULL));
    XSRETURN(1);
}

/* $c->api_key: the row behind this request, minus the digest. Never the
 * plaintext - nothing has it after the response that minted it. */
XS_INTERNAL(pak_h_api_key);
XS_INTERNAL(pak_h_api_key)
{
    dXSARGS;
    HV *cfg = pak_cfg_of(aTHX_ cv);
    HV *stash;
    SV *row;

    if (items < 1) XSRETURN_UNDEF;
    stash = pak_stash_of(aTHX_ ST(0));
    row = stash ? pak_hget(aTHX_ stash, "punk.apikey") : NULL;
    if (!pak_is_hash(row)) XSRETURN_UNDEF;
    ST(0) = sv_2mortal(pak_public(aTHX_ row, cfg));
    XSRETURN(1);
}

/* $c->api_key_auth: { owner, key, kind, scopes } for this request, or undef.
 *
 * The same thing the guard leaves in $c->stash->{auth}, from a slot an
 * OpenAPI mount does not overwrite - behind an `api` mount the usual slot
 * holds the mount's per-scheme results instead. `scopes` is the EFFECTIVE
 * set, after the owner's rank has narrowed what the key's row claims. */
XS_INTERNAL(pak_h_api_key_auth);
XS_INTERNAL(pak_h_api_key_auth)
{
    dXSARGS;
    HV *stash;
    SV *auth;

    if (items < 1) XSRETURN_UNDEF;
    stash = pak_stash_of(aTHX_ ST(0));
    auth = stash ? pak_hget(aTHX_ stash, "punk.apikey.auth") : NULL;
    if (!pak_is_hash(auth)) XSRETURN_UNDEF;
    ST(0) = sv_2mortal(newSVsv(auth));
    XSRETURN(1);
}

/* Run at to_app, after every keyword has recorded: `model` may be declared
 * after the plugin line, so which model exists cannot be settled at `plugin`. */
XS_INTERNAL(pak_on_compile);
XS_INTERNAL(pak_on_compile)
{
    dXSARGS;
    HV *cfg = pak_cfg_of(aTHX_ cv);
    if (items > 0) pak_ensure_model(aTHX_ ST(0), cfg, "Punk::Model::ApiKey");
    XSRETURN_EMPTY;
}

/* ---- register ------------------------------------------------------------- */

static void pak_register(pTHX_ SV *app, SV *opts_sv)
{
    HV *opts = pak_is_hash(opts_sv) ? (HV *)SvRV(opts_sv) : NULL;
    HV *cfg, *kinds, *scopes, *fields, *owner_fields, *rank, *scope_rank_n;
    SV *class_sv, *v, *prefix_opt, *kinds_opt;
    STRLEN kl;

    pak_check_opts(aTHX_ "plugin 'APIKey'", NULL, opts, PAK_OPTS);

    class_sv = sv_2mortal(pak_call(aTHX_ app, "caller_class", NULL, 0));
    if (!(class_sv && SvOK(class_sv)))
        croak(PAK_WHO ": no application class");

    cfg = newHV();

    /* --- kinds XOR prefix ---------------------------------------------------
     * Two ways to say one thing is a configuration bug class, so neither is
     * allowed to shadow the other. */
    kinds_opt  = opts ? pak_hget(aTHX_ opts, "kinds")  : NULL;
    prefix_opt = opts ? pak_hget(aTHX_ opts, "prefix") : NULL;
    if (kinds_opt && SvOK(kinds_opt) && prefix_opt && SvOK(prefix_opt)) {
        SvREFCNT_dec((SV *)cfg);
        croak("plugin 'APIKey': give kinds or prefix, not both");
    }

    kinds = newHV();
    if (kinds_opt && SvOK(kinds_opt)) {
        HE *he;
        if (!pak_is_hash(kinds_opt)) {
            SvREFCNT_dec((SV *)cfg); SvREFCNT_dec((SV *)kinds);
            croak("plugin 'APIKey': kinds must be a hashref of kind => prefix");
        }
        hv_iterinit((HV *)SvRV(kinds_opt));
        while ((he = hv_iternext((HV *)SvRV(kinds_opt)))) {
            SV *val = HeVAL(he);
            const char *k = HePV(he, kl);
            if (!(val && SvOK(val) && SvCUR(val))) {
                SvREFCNT_dec((SV *)cfg); SvREFCNT_dec((SV *)kinds);
                croak("plugin 'APIKey': kind '%.*s' has no prefix",
                      (int)kl, k);
            }
            (void)hv_store(kinds, k, (I32)kl, newSVsv(val), 0);
        }
        if (!HvUSEDKEYS(kinds)) {
            SvREFCNT_dec((SV *)cfg); SvREFCNT_dec((SV *)kinds);
            croak("plugin 'APIKey': kinds is empty");
        }
    }
    else {
        (void)hv_stores(kinds, "live",
            (prefix_opt && SvOK(prefix_opt)) ? newSVsv(prefix_opt)
                                             : newSVpvs("sk_"));
    }

    /* One prefix being a prefix of another would leave match order as the
     * only thing telling two credentials apart, and match order is a rule
     * nobody can see. Refused outright rather than relied on.
     *
     * Flattened into an array first: an HV has ONE iterator, so a nested
     * hv_iternext over the same hash walks the inner loop once and then
     * finds the outer one already exhausted. */
    {
        AV *names = (AV *)sv_2mortal((SV *)newAV());
        AV *pre   = (AV *)sv_2mortal((SV *)newAV());
        HE *he;
        SSize_t i, j, n;

        hv_iterinit(kinds);
        while ((he = hv_iternext(kinds))) {
            av_push(names, newSVsv(HeSVKEY_force(he)));
            av_push(pre,   newSVsv(HeVAL(he)));
        }
        n = av_len(names) + 1;
        for (i = 0; i < n; i++) {
            SV *pa = *av_fetch(pre, i, 0);
            for (j = 0; j < n; j++) {
                SV *pb;
                if (i == j) continue;
                pb = *av_fetch(pre, j, 0);
                if (SvCUR(pa) <= SvCUR(pb)
                    && memEQ(SvPVX(pb), SvPVX(pa), SvCUR(pa))) {
                    SV *ka = newSVsv(*av_fetch(names, i, 0));
                    SV *kb = newSVsv(*av_fetch(names, j, 0));
                    SV *sa = newSVsv(pa), *sb = newSVsv(pb);
                    sv_2mortal(ka); sv_2mortal(kb);
                    sv_2mortal(sa); sv_2mortal(sb);
                    SvREFCNT_dec((SV *)cfg); SvREFCNT_dec((SV *)kinds);
                    croak("plugin 'APIKey': kinds '%s' and '%s' overlap "
                          "('%s' and '%s') - one prefix is a prefix of the "
                          "other, so a key could be read as either",
                          SvPV_nolen(ka), SvPV_nolen(kb),
                          SvPV_nolen(sa), SvPV_nolen(sb));
                }
            }
        }
    }

    /* --- the scope vocabulary ----------------------------------------------- */
    scopes = newHV();
    if (opts && (v = pak_hget(aTHX_ opts, "scopes")) && SvOK(v)) {
        AV *av;
        SSize_t i, n;
        if (!pak_is_array(v)) {
            SvREFCNT_dec((SV *)cfg); SvREFCNT_dec((SV *)kinds);
            SvREFCNT_dec((SV *)scopes);
            croak("plugin 'APIKey': scopes must be an arrayref");
        }
        av = (AV *)SvRV(v);
        n = av_len(av) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(av, i, 0);
            if (e && *e && SvOK(*e))
                (void)hv_store(scopes, SvPV_nolen(*e), (I32)SvCUR(*e),
                               newSViv(1), 0);
        }
    }

    /* --- the column names --------------------------------------------------- */
    fields = pak_field_map(aTHX_ "plugin 'APIKey'", "field", PAK_FIELDS,
                 (opts && pak_is_hash(pak_hget(aTHX_ opts, "fields")))
                     ? (HV *)SvRV(pak_hget(aTHX_ opts, "fields")) : NULL);
    if (opts && (v = pak_hget(aTHX_ opts, "owner")) && SvOK(v))
        (void)hv_stores(fields, "owner", newSVsv(v));

    owner_fields = pak_field_map(aTHX_ "plugin 'APIKey'", "owner field",
                 PAK_OWNER_FIELDS,
                 (opts && pak_is_hash(pak_hget(aTHX_ opts, "owner_fields")))
                     ? (HV *)SvRV(pak_hget(aTHX_ opts, "owner_fields")) : NULL);

    /* --- the rank ladder, and what each scope needs on it -------------------
     * The ladder comes from the `auth` keyword and never from a second copy
     * here: auth_guard(role => ...) reads that one, and two ladders drift. */
    rank = newHV();
    scope_rank_n = newHV();
    if (opts && (v = pak_hget(aTHX_ opts, "scope_rank")) && SvOK(v)) {
        SV *auth = pak_hget(aTHX_ (HV *)SvRV(app), "auth");
        AV *ladder = NULL;
        HE *he;
        SSize_t i, n;

        if (!pak_is_hash(v))
            croak("plugin 'APIKey': scope_rank must be a hashref");
        if (!(opts && pak_hget(aTHX_ opts, "owner_model")))
            croak("plugin 'APIKey': scope_rank needs owner_model, since it "
                  "is the owner whose rank is read");
        if (pak_is_hash(auth)) {
            SV *r = pak_hget(aTHX_ (HV *)SvRV(auth), "rank");
            if (pak_is_array(r)) ladder = (AV *)SvRV(r);
        }
        if (!(ladder && av_len(ladder) >= 0))
            croak("plugin 'APIKey': scope_rank needs `auth rank => [...]`, "
                  "which is the ladder it names positions on");

        n = av_len(ladder) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(ladder, i, 0);
            if (e && *e && SvOK(*e))
                (void)hv_store(rank, SvPV_nolen(*e), (I32)SvCUR(*e),
                               newSViv(i), 0);
        }

        hv_iterinit((HV *)SvRV(v));
        while ((he = hv_iternext((HV *)SvRV(v)))) {
            const char *s = HePV(he, kl);
            SV *role = HeVAL(he);
            SV **pos;
            if (HvUSEDKEYS(scopes) && !hv_exists(scopes, s, (I32)kl))
                croak("plugin 'APIKey': scope_rank names scope '%.*s', which "
                      "is not in the vocabulary (%s)", (int)kl, s,
                      SvPV_nolen(pak_key_list(aTHX_ scopes)));
            pos = (role && SvOK(role))
                ? hv_fetch(rank, SvPV_nolen(role), (I32)SvCUR(role), 0) : NULL;
            if (!(pos && *pos))
                croak("plugin 'APIKey': scope_rank puts '%.*s' at role '%s', "
                      "which is not on the auth rank ladder (%s)",
                      (int)kl, s, role && SvOK(role) ? SvPV_nolen(role) : "?",
                      SvPV_nolen(pak_key_list(aTHX_ rank)));
            (void)hv_store(scope_rank_n, s, (I32)kl, newSViv(SvIV(*pos)), 0);
        }
    }

    /* --- the header to read -------------------------------------------------- */
    if (opts && (v = pak_hget(aTHX_ opts, "header")) && SvOK(v) && SvCUR(v)) {
        STRLEN hl;
        const char *hp = SvPV_const(v, hl);
        SV *env;
        STRLEN i;
        for (i = 0; i < hl; i++) {
            char ch = hp[i];
            if (!((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
                  || (ch >= '0' && ch <= '9') || ch == '-' || ch == '_'))
                croak("plugin 'APIKey': header '%s' is not a usable header "
                      "name", hp);
        }
        env = newSVpvs("HTTP_");
        for (i = 0; i < hl; i++) {
            char ch = hp[i];
            if (ch == '-') ch = '_';
            else if (ch >= 'a' && ch <= 'z') ch = (char)(ch - 'a' + 'A');
            sv_catpvn(env, &ch, 1);
        }
        (void)hv_stores(cfg, "header", newSVsv(v));
        (void)hv_stores(cfg, "header_env", env);
    }

    /* --- the configuration --------------------------------------------------- */
    (void)hv_stores(cfg, "class", newSVsv(class_sv));
    (void)hv_stores(cfg, "model",
        (opts && (v = pak_hget(aTHX_ opts, "model")) && SvOK(v))
            ? newSVsv(v) : newSVpvs("ApiKey"));
    (void)hv_stores(cfg, "fields",       newRV_noinc((SV *)fields));
    (void)hv_stores(cfg, "kinds",        newRV_noinc((SV *)kinds));
    (void)hv_stores(cfg, "scopes",       newRV_noinc((SV *)scopes));
    (void)hv_stores(cfg, "owner_fields", newRV_noinc((SV *)owner_fields));
    (void)hv_stores(cfg, "rank",         newRV_noinc((SV *)rank));
    (void)hv_stores(cfg, "scope_rank_n", newRV_noinc((SV *)scope_rank_n));
    (void)hv_stores(cfg, "grace",
        (opts && (v = pak_hget(aTHX_ opts, "grace")) && SvOK(v))
            ? newSVsv(v) : newSViv(3600));
    (void)hv_stores(cfg, "owner_ttl",
        (opts && (v = pak_hget(aTHX_ opts, "owner_ttl")) && SvOK(v))
            ? newSVsv(v) : newSViv(30));
    if (opts && (v = pak_hget(aTHX_ opts, "owner_model")) && SvOK(v))
        (void)hv_stores(cfg, "owner_model", newSVsv(v));
    (void)hv_stores(cfg, "owner_cache", newRV_noinc((SV *)newHV()));
    (void)hv_stores(cfg, "warned",      newRV_noinc((SV *)newHV()));
    (void)hv_stores(cfg, "pid",         newSViv(0));

    if (!PAK_STATE) PAK_STATE = newHV();
    (void)hv_store(PAK_STATE, SvPV_nolen(class_sv), (I32)SvCUR(class_sv),
                   newRV_inc((SV *)cfg), 0);

    /* --- the schema ---------------------------------------------------------- */
    pak_sqitch(aTHX_ app, "punk_apikey",
        pak_beside(aTHX_ "Punk/Plugin/APIKey.pm", "APIKey.pm",
                    "APIKey/sqitch"),
        PAK_ENGINES);

    /* --- helpers and keywords ------------------------------------------------ */
    pak_helper(aTHX_ app, "api_key_issue",  pak_h_issue,   cfg, NULL);
    pak_helper(aTHX_ app, "api_key_revoke", pak_h_revoke,  cfg, NULL);
    pak_helper(aTHX_ app, "api_keys",       pak_h_keys,    cfg, NULL);
    pak_helper(aTHX_ app, "api_key",        pak_h_api_key, cfg, NULL);
    pak_helper(aTHX_ app, "api_key_auth",   pak_h_api_key_auth, cfg, NULL);

    /* For an application that wrote `plugin 'APIKey'` without the `use`: the
     * parenthesised form still works. A no-op when import already did it,
     * which is what Punk makes a second install from one owner. */
    pak_keyword(aTHX_ app, "api_key_guard",   pak_kw_guard,   cfg, NULL,
                 PAK_WHO);
    pak_keyword(aTHX_ app, "api_key_checker", pak_kw_checker, cfg, NULL,
                 PAK_WHO);

    /* --- the model ----------------------------------------------------------- */
    {
        HV *apph = SvROK(app) ? (HV *)SvRV(app) : NULL;
        HV *stash = gv_stashpvs("Punk::App", 0);
        if (apph && stash && gv_fetchmethod_autoload(stash, "on_compile", 0)) {
            /* checked at compile rather than at `plugin`, because `model` may
             * be declared after this line */
            SV *argv[2];
            argv[0] = sv_2mortal(pak_closure(aTHX_ pak_on_compile, cfg, NULL));
            argv[1] = sv_2mortal(newSVpvs(PAK_WHO));
            SvREFCNT_dec(pak_call(aTHX_ app, "on_compile", argv, 2));
        }
        else {
            pak_ensure_model(aTHX_ app, cfg, "Punk::Model::ApiKey");
        }
    }

    SvREFCNT_dec((SV *)cfg);   /* PAK_STATE holds the reference now */
}

#endif /* PAK_APIKEY_BOOT_H */
