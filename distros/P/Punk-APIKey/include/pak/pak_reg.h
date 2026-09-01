#ifndef PAK_REG_H
#define PAK_REG_H

/* The boot-time devices a plugin's `register` needs in C: reading options
 * without letting a typo through, installing helpers and keywords, finding a
 * shipped directory through %INC, and registering a Sqitch project.
 *
 * These exist because this distribution is XS the whole way down. Option
 * validation in Perl and the decision in C would mean two files to keep in
 * step over one vocabulary, and the half that runs at boot is the half that
 * has to be exact - it is where a misspelling either croaks or opens a door.
 */

/* ---- reading options ------------------------------------------------------ */

/* A sorted, comma-joined list of a hash's keys, for a diagnostic that says
 * what the caller could have meant. Mortal. */
static SV *pak_key_list(pTHX_ HV *h)
{
    SV *out = sv_2mortal(newSVpvs(""));
    AV *keys = (AV *)sv_2mortal((SV *)newAV());
    HE *he;
    SSize_t i, n;

    if (!h) return out;
    hv_iterinit(h);
    while ((he = hv_iternext(h))) av_push(keys, newSVsv(HeSVKEY_force(he)));
    n = av_len(keys) + 1;
    if (n > 1) sortsv(AvARRAY(keys), (STRLEN)n, Perl_sv_cmp);
    for (i = 0; i < n; i++) {
        if (i) sv_catpvs(out, ", ");
        sv_catsv(out, *av_fetch(keys, i, 0));
    }
    return out;
}

/* The same for a NUL-terminated list of names. */
static SV *pak_name_list(pTHX_ const char *const *names)
{
    SV *out = sv_2mortal(newSVpvs(""));
    int i;
    for (i = 0; names[i]; i++) {
        if (i) sv_catpvs(out, ", ");
        sv_catpv(out, names[i]);
    }
    return out;
}

/* Every key of `opts` must be in `known`, or the option was misspelled - and
 * a misspelled option is a setting that silently did not apply, which for
 * anything guarding a route is a door left open. */
static void pak_check_opts(pTHX_ const char *who, const char *noun, HV *opts,
                            const char *const *known)
{
    HE *he;
    if (!opts) return;
    hv_iterinit(opts);
    while ((he = hv_iternext(opts))) {
        STRLEN kl;
        const char *k = HePV(he, kl);
        int i, ok = 0;
        for (i = 0; known[i]; i++)
            if (strlen(known[i]) == kl && memEQ(known[i], k, kl)) { ok = 1; break; }
        if (!ok)
            croak("%s: unknown %soption '%.*s' (known: %s)", who,
                  noun ? noun : "", (int)kl, k,
                  SvPV_nolen(pak_name_list(aTHX_ known)));
    }
}

/* A hash of logical name => column, defaulting each to its own name and
 * letting `map` rename any of them. An unknown key croaks: `fields` is where
 * a typo means the plugin reads a column nobody has. */
static HV *pak_field_map(pTHX_ const char *who, const char *what,
                          const char *const *names, HV *map)
{
    HV *out = newHV();
    int i;
    for (i = 0; names[i]; i++)
        (void)hv_store(out, names[i], (I32)strlen(names[i]),
                       newSVpv(names[i], 0), 0);
    if (map) {
        HE *he;
        hv_iterinit(map);
        while ((he = hv_iternext(map))) {
            STRLEN kl;
            const char *k = HePV(he, kl);
            if (!hv_exists(out, k, (I32)kl)) {
                SvREFCNT_dec((SV *)out);
                croak("%s: unknown %s '%.*s' (known: %s)", who, what,
                      (int)kl, k, SvPV_nolen(pak_name_list(aTHX_ names)));
            }
            (void)hv_store(out, k, (I32)kl, newSVsv(HeVAL(he)), 0);
        }
    }
    return out;
}

/* ---- installing ----------------------------------------------------------- */

static void pak_helper(pTHX_ SV *app, const char *name, XSUBADDR_t body,
                        HV *cfg, SV *extra)
{
    SV *argv[2];
    argv[0] = sv_2mortal(newSVpv(name, 0));
    argv[1] = sv_2mortal(pak_closure(aTHX_ body, cfg, extra));
    SvREFCNT_dec(pak_call(aTHX_ app, "helper", argv, 2));
}

/* A keyword, owned by this plugin so a second install from the same owner is
 * the no-op Punk makes it. */
static void pak_keyword(pTHX_ SV *app, const char *name, XSUBADDR_t body,
                         HV *cfg, SV *extra, const char *owner)
{
    SV *argv[3];
    argv[0] = sv_2mortal(newSVpv(name, 0));
    argv[1] = sv_2mortal(pak_closure(aTHX_ body, cfg, extra));
    argv[2] = sv_2mortal(newSVpv(owner, 0));
    SvREFCNT_dec(pak_call(aTHX_ app, "install_kw", argv, 3));
}

/* ---- where this distribution's files are ---------------------------------- */

/* A directory shipped beside a module, found through %INC rather than @INC:
 * a blib and an installed copy in one @INC must not be able to disagree
 * about which one is running.
 *
 * `pm` is the %INC key (Punk/Plugin/APIKey.pm), `suffix` what to put in its
 * place (Plugin/APIKey/sqitch). Mortal, or NULL when the module is not
 * in %INC - which happens when Punk skipped the require because the package
 * already had a register.
 */
static SV *pak_beside(pTHX_ const char *pm, const char *strip,
                       const char *suffix)
{
    SV **e = hv_fetch(GvHV(PL_incgv), pm, (I32)strlen(pm), 0);
    SV *dir;
    STRLEN dl, sl = strlen(strip);
    const char *dp;

    if (!(e && *e && SvOK(*e))) return NULL;
    dir = sv_2mortal(newSVsv(*e));
    dp = SvPV_const(dir, dl);
    if (dl >= sl && memEQ(dp + dl - sl, strip, sl)) SvCUR_set(dir, dl - sl);
    sv_catpv(dir, suffix);
    return dir;
}

/* Register a Sqitch project, when Punk-Sqitch is installed.
 *
 * The `can` guard is the contract Punk-Sqitch states: a plugin must work
 * without it, with the DDL in the POD for an application that manages its
 * schema some other way. So this is silent when it is absent, and only the
 * application asking for something it has not installed is an error.
 */
static void pak_sqitch(pTHX_ SV *app, const char *name, SV *dir,
                        const char *const *engines)
{
    SV *cls, *argv[5];
    AV *eng;
    int i;

    if (!dir) return;
    {   /* -d $dir */
        Stat_t st;
        if (PerlLIO_stat(SvPV_nolen(dir), &st) < 0 || !S_ISDIR(st.st_mode))
            return;
    }
    eval_pv("require Punk::Plugin::Sqitch; 1", FALSE);
    if (SvTRUE(ERRSV)) return;          /* not installed: not an error */

    cls = sv_2mortal(newSVpvs("Punk::Plugin::Sqitch"));
    {   /* ->can('project'): an older Punk-Sqitch without the registry */
        HV *stash = gv_stashpvs("Punk::Plugin::Sqitch", 0);
        if (!(stash && gv_fetchmethod_autoload(stash, "project", 0))) return;
    }

    eng = newAV();
    for (i = 0; engines[i]; i++) av_push(eng, newSVpv(engines[i], 0));

    argv[0] = app;
    argv[1] = sv_2mortal(newSVpv(name, 0));
    argv[2] = dir;
    argv[3] = sv_2mortal(newSVpvs("engines"));
    argv[4] = sv_2mortal(newRV_noinc((SV *)eng));
    SvREFCNT_dec(pak_call(aTHX_ cls, "project", argv, 5));
}

/* ---- the model ------------------------------------------------------------ */

/* Make sure the model this plugin reads exists by the time a request asks.
 *
 * When the application registered one by the configured name, or has one
 * discoverable under its own Model namespace, that is the one. Otherwise the
 * class shipped here is registered under its full name, which Punk takes as a
 * class rather than as a name in the application's namespace.
 *
 * The trap: naming ANY model turns auto-discovery off unless it was asked for
 * explicitly (punk_compile.h: autoflag = explicit ? explicit : !named), so an
 * application relying on a bare `model;` to find its own classes would lose
 * them the moment this plugin named one. Put it back first.
 */
static void pak_ensure_model(pTHX_ SV *app, HV *cfg, const char *shipped)
{
    SV *name = pak_hget(aTHX_ cfg, "model");
    HV *apph;
    SV *models, *auto_sv;
    STRLEN nl;
    const char *np;
    int named = 0;

    if (!(name && SvOK(name))) return;
    np = SvPV_const(name, nl);
    if (memchr(np, ':', nl)) return;          /* already a class: ours */

    apph = SvROK(app) ? (HV *)SvRV(app) : NULL;
    if (!apph) return;

    models = pak_hget(aTHX_ apph, "models");
    if (pak_is_array(models)) {
        AV *av = (AV *)SvRV(models);
        SSize_t i, n = av_len(av) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(av, i, 0);
            if (e && *e && SvOK(*e) && sv_eq(*e, name)) return;
            if (e && *e && SvOK(*e)) named++;
        }
    }

    {   /* <App>::Model::<Name>, loadable? */
        SV *caller = sv_2mortal(pak_call(aTHX_ app, "caller_class", NULL, 0));
        SV *full = sv_2mortal(newSVsv(caller));
        SV *req;
        sv_catpvs(full, "::Model::");
        sv_catsv(full, name);
        req = sv_2mortal(newSVpvs("require "));
        sv_catsv(req, full);
        sv_catpvs(req, "; 1");
        eval_pv(SvPV_nolen(req), FALSE);
        if (!SvTRUE(ERRSV)) return;
    }

    auto_sv = pak_hget(aTHX_ apph, "model_auto");
    if (!named && !(auto_sv && SvOK(auto_sv))) {
        SV *one = sv_2mortal(newSViv(1));
        SvREFCNT_dec(pak_call(aTHX_ app, "model_auto", &one, 1));
    }
    {
        SV *req = sv_2mortal(newSVpvs("require "));
        SV *cls = sv_2mortal(newSVpv(shipped, 0));
        SV *argv[1];
        sv_catpv(req, shipped);
        sv_catpvs(req, "; 1");
        eval_pv(SvPV_nolen(req), TRUE);
        argv[0] = cls;
        SvREFCNT_dec(pak_call(aTHX_ app, "model_class", argv, 1));
        (void)hv_stores(cfg, "model", newSVpv(shipped, 0));
    }
}

/* The per-worker model instance, for the paths with no context: the CLI, an
 * admin action reaching through the class. Through the registrar, which
 * caches per worker and is fork-safe. */
static SV *pak_model_of(pTHX_ HV *cfg)
{
    SV *cls = pak_hget(aTHX_ cfg, "class");
    SV *app, *argv[1];

    if (!(cls && SvOK(cls))) croak("Punk::APIKey: no application class");
    app = sv_2mortal(pak_call(aTHX_ cls, "punk_app", NULL, 0));
    if (!(app && SvROK(app)))
        croak("%s has not compiled yet; call this after to_app",
              SvPV_nolen(cls));
    argv[0] = pak_hget(aTHX_ cfg, "model");
    return pak_call(aTHX_ app, "model_instance", argv, 1);
}

/* The same as pak_model_of, but surviving a failure: the caller decides
 * whether not having a model is fatal. */
static SV *pak_try_model(pTHX_ HV *cfg, int *failed)
{
    SV *cls = pak_hget(aTHX_ cfg, "class");
    SV *app, *argv[1];

    *failed = 0;
    if (!(cls && SvOK(cls))) { *failed = 1; return NULL; }
    app = pak_try(aTHX_ cls, "punk_app", NULL, NULL, 0, failed);
    if (*failed || !(app && SvROK(app))) {
        if (app) SvREFCNT_dec(app);
        *failed = 1;
        return NULL;
    }
    sv_2mortal(app);
    argv[0] = pak_hget(aTHX_ cfg, "model");
    return pak_try(aTHX_ app, "model_instance", NULL, argv, 1, failed);
}

/* ---- small string work ---------------------------------------------------- */

/* Split on whitespace and commas into a fresh AV. */
static AV *pak_split(pTHX_ SV *sv)
{
    AV *out = newAV();
    STRLEN l, i, start = 0;
    const char *p;
    if (!(sv && SvOK(sv))) return out;
    p = SvPV_const(sv, l);
    for (i = 0; i <= l; i++) {
        if (i == l || p[i] == ' ' || p[i] == '\t' || p[i] == ',' || p[i] == '\n') {
            if (i > start) av_push(out, newSVpvn(p + start, i - start));
            start = i + 1;
        }
    }
    return out;
}

/* Join an AV with single spaces, which is how a set of names is stored in one
 * column. Mortal. */
static SV *pak_join(pTHX_ AV *av)
{
    SV *out = sv_2mortal(newSVpvs(""));
    SSize_t i, n = av ? av_len(av) + 1 : 0;
    for (i = 0; i < n; i++) {
        SV **e = av_fetch(av, i, 0);
        if (!(e && *e && SvOK(*e))) continue;
        if (SvCUR(out)) sv_catpvs(out, " ");
        sv_catsv(out, *e);
    }
    return out;
}

/* An option that is a single value or an arrayref, as an AV either way. */
static AV *pak_as_list(pTHX_ SV *sv)
{
    AV *out = newAV();
    if (!(sv && SvOK(sv))) return out;
    if (pak_is_array(sv)) {
        AV *in = (AV *)SvRV(sv);
        SSize_t i, n = av_len(in) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(in, i, 0);
            if (e && *e) av_push(out, newSVsv(*e));
        }
        return out;
    }
    av_push(out, newSVsv(sv));
    return out;
}

/* Log through the application, once per distinct message per worker: a
 * database that is away is away for every request, and a line per request is
 * how the reason gets buried. */
static void pak_warn_once(pTHX_ SV *c, HV *cfg, const char *who, SV *msg)
{
    SV *w = pak_hget(aTHX_ cfg, "warned");
    HV *seen;
    STRLEN ml;
    const char *mp;
    SV *full;

    if (!pak_is_hash(w)) {
        SV *fresh = newRV_noinc((SV *)newHV());
        (void)hv_stores(cfg, "warned", fresh);
        w = fresh;
    }
    seen = (HV *)SvRV(w);
    mp = SvPV_const(msg, ml);
    if (hv_exists(seen, mp, (I32)ml)) return;
    (void)hv_store(seen, mp, (I32)ml, newSViv(1), 0);

    full = sv_2mortal(newSVpv(who, 0));
    sv_catpvs(full, ": ");
    sv_catsv(full, msg);

    {
        SV *app = c ? sv_2mortal(pak_call(aTHX_ c, "app", NULL, 0)) : NULL;
        SV *log = (app && SvOK(app))
                ? sv_2mortal(pak_call(aTHX_ app, "log", NULL, 0)) : NULL;
        if (log && SvOK(log)) {
            SV *argv[1];
            argv[0] = full;
            SvREFCNT_dec(pak_call(aTHX_ log, "warn", argv, 1));
            return;
        }
    }
    warn("%s\n", SvPV_nolen(full));
}

#endif /* PAK_REG_H */
