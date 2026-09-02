#ifndef PAK_APIKEY_REG_H
#define PAK_APIKEY_REG_H

/* Punk::Plugin::APIKey's boot and its write paths, in C.
 *
 * lib/Punk/Plugin/APIKey.pm is documentation and a version number. This is
 * the plugin: option validation, the configuration, issue, revoke, list, and
 * the owner-standing read the guard in pak_apikey.h calls.
 *
 * The configuration for an application class is held live in PAK_STATE, so
 * the closures the guard is built from and the writers below are looking at
 * one hash rather than two copies.
 */

#define PAK_WHO "Punk::Plugin::APIKey"

static HV *PAK_STATE = NULL;

static const char *const PAK_OPTS[] = {
    "model", "fields", "owner", "kinds", "prefix", "scopes", "header",
    "grace", "owner_model", "owner_fields", "owner_ttl", "scope_rank", NULL
};
static const char *const PAK_FIELDS[] = {
    "id", "owner", "kind", "label", "prefix", "digest", "scopes",
    "rate_per_min", "expires", "revoked", "last_used", "created", NULL
};
static const char *const PAK_OWNER_FIELDS[] = {
    "id", "role", "verified", "suspended", NULL
};
static const char *const PAK_ENGINES[] = { "sqlite", "pg", "mysql", NULL };

static HV *pak_state_for(pTHX_ SV *class_sv)
{
    STRLEN cl;
    const char *cp;
    SV **e;
    if (!PAK_STATE || !(class_sv && SvOK(class_sv))) return NULL;
    cp = SvPV_const(class_sv, cl);
    e = hv_fetch(PAK_STATE, cp, (I32)cl, 0);
    return (e && *e && pak_is_hash(*e)) ? (HV *)SvRV(*e) : NULL;
}


/* ---- the row, as anyone outside this plugin sees it ------------------------
 *
 * Everything except the digest. The digest IS the credential in stored form,
 * so a list that leaks it has leaked every key on the page. */
static SV *pak_public(pTHX_ SV *row, HV *cfg)
{
    HV *out, *r;
    HV *f;
    SV *fields, *dcol;
    HE *he;

    if (!pak_is_hash(row)) return newSV(0);
    r = (HV *)SvRV(row);
    out = newHV();
    fields = pak_hget(aTHX_ cfg, "fields");
    f = pak_is_hash(fields) ? (HV *)SvRV(fields) : NULL;
    dcol = f ? pak_hget(aTHX_ f, "digest") : NULL;

    hv_iterinit(r);
    while ((he = hv_iternext(r))) {
        STRLEN kl;
        const char *k = HePV(he, kl);
        if (dcol && SvOK(dcol)) {
            STRLEN dl;
            const char *dp = SvPV_const(dcol, dl);
            if (dl == kl && memEQ(dp, k, kl)) continue;
        }
        (void)hv_store(out, k, (I32)kl, newSVsv(HeVAL(he)), 0);
    }
    return newRV_noinc((SV *)out);
}

/* The column name for a logical field. */
static SV *pak_col(pTHX_ HV *cfg, const char *name)
{
    SV *fields = pak_hget(aTHX_ cfg, "fields");
    HV *f = pak_is_hash(fields) ? (HV *)SvRV(fields) : NULL;
    SV *c = f ? pak_hget(aTHX_ f, name) : NULL;
    return (c && SvOK(c)) ? c : sv_2mortal(newSVpv(name, 0));
}

/* ---- which kind an issue gets when it does not say ------------------------
 *
 * NOT "the first declared": kinds are a hash, and hash order is not an order.
 * Minting a `test` key because the iterator felt like it - and having it work
 * everywhere a live one does, since what a kind MEANS is the application's
 * business - is a bug that is found late.
 */
static SV *pak_default_kind(pTHX_ HV *cfg)
{
    SV *k = pak_hget(aTHX_ cfg, "kinds");
    HV *kinds = pak_is_hash(k) ? (HV *)SvRV(k) : NULL;
    HE *he;

    if (!kinds) croak(PAK_WHO ": no kinds are configured");
    if (hv_exists(kinds, "live", 4)) return sv_2mortal(newSVpvs("live"));
    if (HvUSEDKEYS(kinds) == 1) {
        hv_iterinit(kinds);
        he = hv_iternext(kinds);
        return sv_2mortal(newSVsv(HeSVKEY_force(he)));
    }
    croak(PAK_WHO ": which kind? there is no `live` to default to, so name "
          "one (%s)", SvPV_nolen(pak_key_list(aTHX_ kinds)));
    return NULL;   /* not reached */
}

/* ---- issue ----------------------------------------------------------------
 *
 * The plaintext exists here and nowhere else. Nothing stores it; the one
 * legitimate display is the response to the request that minted it.
 */
static const char *const PAK_ISSUE_OPTS[] = {
    "owner", "label", "scopes", "kind", "expires", "rate_per_min",
    "replaces", NULL
};

static void pak_issue(pTHX_ HV *cfg, HV *args, SV **key_out, SV **row_out)
{
    SV *owner, *label, *kind, *prefix, *v;
    SV *kv = pak_hget(aTHX_ cfg, "kinds");
    HV *kinds = pak_is_hash(kv) ? (HV *)SvRV(kv) : NULL;
    SV *sv = pak_hget(aTHX_ cfg, "scopes");
    HV *vocab = pak_is_hash(sv) ? (HV *)SvRV(sv) : NULL;
    AV *scopes;
    HV *data;
    SV *model, *key, *argv[1];
    IV now = (IV)time(NULL);

    pak_check_opts(aTHX_ PAK_WHO, "issue ", args, PAK_ISSUE_OPTS);

    owner = pak_hget(aTHX_ args, "owner");
    if (!(owner && SvOK(owner))) croak(PAK_WHO ": issue needs an owner");
    label = pak_hget(aTHX_ args, "label");

    kind = pak_hget(aTHX_ args, "kind");
    if (!(kind && SvOK(kind))) kind = pak_default_kind(aTHX_ cfg);
    {
        STRLEN kl;
        const char *kp = SvPV_const(kind, kl);
        SV **pe = kinds ? hv_fetch(kinds, kp, (I32)kl, 0) : NULL;
        if (!(pe && *pe && SvOK(*pe)))
            croak(PAK_WHO ": no kind '%.*s' (known: %s)", (int)kl, kp,
                  SvPV_nolen(pak_key_list(aTHX_ kinds)));
        prefix = *pe;
    }

    scopes = (AV *)sv_2mortal((SV *)pak_as_list(aTHX_
                 pak_hget(aTHX_ args, "scopes")));
    if (av_len(scopes) == 0) {
        /* one string may itself be a list */
        SV **only = av_fetch(scopes, 0, 0);
        if (only && *only && SvOK(*only)
            && strpbrk(SvPV_nolen(*only), " ,\t")) {
            AV *split = pak_split(aTHX_ *only);
            scopes = (AV *)sv_2mortal((SV *)split);
        }
    }
    if (vocab && HvUSEDKEYS(vocab)) {
        SSize_t i, n = av_len(scopes) + 1;
        for (i = 0; i < n; i++) {
            SV *one = *av_fetch(scopes, i, 0);
            STRLEN ol;
            const char *op = SvPV_const(one, ol);
            if (!hv_exists(vocab, op, (I32)ol))
                croak(PAK_WHO ": scope '%.*s' is not in the vocabulary (%s)",
                      (int)ol, op, SvPV_nolen(pak_key_list(aTHX_ vocab)));
        }
    }

    model = sv_2mortal(pak_model_of(aTHX_ cfg));
    key = sv_2mortal(pak_mint(aTHX_ prefix));

    data = (HV *)sv_2mortal((SV *)newHV());
#define PAK_SET(f, val) \
    do { SV *c_ = pak_col(aTHX_ cfg, (f)); STRLEN cl_; \
         const char *cp_ = SvPV_const(c_, cl_); \
         (void)hv_store(data, cp_, (I32)cl_, (val), 0); } while (0)

    PAK_SET("owner",  newSVsv(owner));
    PAK_SET("kind",   newSVsv(kind));
    PAK_SET("label",  label && SvOK(label) ? newSVsv(label) : newSVpvs(""));
    PAK_SET("prefix", pak_stored_prefix(aTHX_ key, SvCUR(prefix)));
    PAK_SET("digest", pak_digest(aTHX_ key));
    PAK_SET("scopes", newSVsv(pak_join(aTHX_ scopes)));
    PAK_SET("created", newSViv(now));

    if ((v = pak_hget(aTHX_ args, "rate_per_min")) && SvOK(v))
        PAK_SET("rate_per_min", newSVsv(v));
    if ((v = pak_hget(aTHX_ args, "expires")) && SvOK(v))
        PAK_SET("expires", newSVsv(v));

    argv[0] = sv_2mortal(newRV_inc((SV *)data));
    *row_out = pak_call(aTHX_ model, "create", argv, 1);
    *key_out = newSVsv(key);

    /* A rotation must not break the deployment that has not picked up the new
     * key yet, so the one being replaced gets a grace period rather than
     * being cut off the moment its successor exists. */
    if ((v = pak_hget(aTHX_ args, "replaces")) && SvOK(v)) {
        SV *g = pak_hget(aTHX_ cfg, "grace");
        HV *up = (HV *)sv_2mortal((SV *)newHV());
        SV *gargv[2], *prev;
        gargv[0] = pak_col(aTHX_ cfg, "id");
        gargv[1] = v;
        prev = sv_2mortal(pak_call(aTHX_ model, "get", gargv, 2));
        if (pak_is_hash(prev)) {
            SV *uargv[1];
            {   /* the same PAK_SET, over `up` */
                SV *c_ = pak_col(aTHX_ cfg, "id");
                STRLEN cl_; const char *cp_ = SvPV_const(c_, cl_);
                (void)hv_store(up, cp_, (I32)cl_, newSVsv(v), 0);
                c_ = pak_col(aTHX_ cfg, "expires");
                cp_ = SvPV_const(c_, cl_);
                (void)hv_store(up, cp_, (I32)cl_,
                    newSViv(now + ((g && SvOK(g)) ? SvIV(g) : 3600)), 0);
            }
            uargv[0] = sv_2mortal(newRV_inc((SV *)up));
            SvREFCNT_dec(pak_call(aTHX_ model, "update", uargv, 1));
        }
    }
#undef PAK_SET
}

/* Revoke is a timestamp, not a delete: the row stays for the list, and for
 * the audit of what was revoked and when. */
static SV *pak_revoke(pTHX_ HV *cfg, SV *id)
{
    SV *model = sv_2mortal(pak_model_of(aTHX_ cfg));
    HV *data = (HV *)sv_2mortal((SV *)newHV());
    SV *argv[1], *row;
    SV *c;
    STRLEN cl;
    const char *cp;

    if (!(id && SvOK(id))) croak(PAK_WHO ": revoke needs an id");

    c = pak_col(aTHX_ cfg, "id");
    cp = SvPV_const(c, cl);
    (void)hv_store(data, cp, (I32)cl, newSVsv(id), 0);
    c = pak_col(aTHX_ cfg, "revoked");
    cp = SvPV_const(c, cl);
    (void)hv_store(data, cp, (I32)cl, newSViv((IV)time(NULL)), 0);

    argv[0] = sv_2mortal(newRV_inc((SV *)data));
    row = sv_2mortal(pak_call(aTHX_ model, "update", argv, 1));

    /* a revoked key must not keep passing on a cached standing */
    (void)hv_stores(cfg, "owner_cache", newRV_noinc((SV *)newHV()));
    return pak_public(aTHX_ row, cfg);
}

static SV *pak_keys(pTHX_ HV *cfg, SV *owner)
{
    SV *model = sv_2mortal(pak_model_of(aTHX_ cfg));
    HV *filter = newHV();
    HV *opts = newHV();
    AV *order = newAV();
    SV *argv[2], *page, *rows;
    AV *out = newAV();

    if (owner && SvOK(owner)) {
        SV *c = pak_col(aTHX_ cfg, "owner");
        STRLEN cl;
        const char *cp = SvPV_const(c, cl);
        (void)hv_store(filter, cp, (I32)cl, newSVsv(owner), 0);
    }
    av_push(order, newSVsv(pak_col(aTHX_ cfg, "created")));
    av_push(order, newSVpvs("desc"));
    (void)hv_stores(opts, "order_by", newRV_noinc((SV *)order));
    (void)hv_stores(opts, "limit", newSViv(200));

    argv[0] = sv_2mortal(newRV_noinc((SV *)filter));
    argv[1] = sv_2mortal(newRV_noinc((SV *)opts));
    page = sv_2mortal(pak_call(aTHX_ model, "search", argv, 2));

    rows = pak_is_hash(page) ? pak_hget(aTHX_ (HV *)SvRV(page), "rows")
                              : page;
    if (pak_is_array(rows)) {
        AV *av = (AV *)SvRV(rows);
        SSize_t i, n = av_len(av) + 1;
        for (i = 0; i < n; i++)
            av_push(out, pak_public(aTHX_ *av_fetch(av, i, 0), cfg));
    }
    return newRV_noinc((SV *)out);
}

/* ---- the owner's standing -------------------------------------------------
 *
 * Returns a hash - { gone => 1 }, or { rank => N, suspended => 0|1 } - or
 * NULL when the READ ITSELF failed. Those are different answers: an owner who
 * is not there is a refusal, a table nobody can read is a 503, and conflating
 * them would either honour a deleted account's keys or refuse everyone over
 * a blip.
 */
static SV *pak_standing(pTHX_ SV *c, HV *cfg, SV *owner_id)
{
    SV *om = pak_hget(aTHX_ cfg, "owner_model");
    SV *ofv = pak_hget(aTHX_ cfg, "owner_fields");
    HV *of = pak_is_hash(ofv) ? (HV *)SvRV(ofv) : NULL;
    SV *row = NULL;
    HV *out;
    int failed = 0;

    if (!(om && SvOK(om))) return NULL;

    {
        /* Through pak_try, not JMPENV: a die inside a plain call longjmps
         * past this file's ENTER/SAVETMPS and leaves the Perl stack short,
         * which surfaces later as garbage somewhere unrelated. Catching the
         * jump is not the problem; unwinding the bookkeeping is. */
        SV *margv[1], *m = NULL, *gargv[2];
        margv[0] = om;
        m = pak_try(aTHX_ c, "model", NULL, margv, 1, &failed);
        if (m) sv_2mortal(m);
        if (!failed) {
            if (!m) failed = 1;
            else {
                gargv[0] = of ? pak_hget(aTHX_ of, "id")
                              : sv_2mortal(newSVpvs("id"));
                gargv[1] = owner_id;
                row = pak_try(aTHX_ m, "get", NULL, gargv, 2, &failed);
                if (row) {
                    sv_2mortal(row);
                    row = sv_2mortal(pak_await(aTHX_ c, row));
                }
            }
        }
    }

    if (failed) {
        SV *msg = sv_2mortal(newSVpvs(
            "the owner table is unreachable, refusing keys rather than "
            "honouring what cannot be checked: "));
        sv_catsv(msg, ERRSV);
        {   /* one actionable line */
            STRLEN ml; char *mp = SvPV(msg, ml);
            while (ml && (mp[ml - 1] == '\n' || mp[ml - 1] == ' ')) ml--;
            SvCUR_set(msg, ml);
        }
        pak_warn_once(aTHX_ c, cfg, PAK_WHO, msg);
        return NULL;
    }

    out = newHV();
    if (!pak_is_hash(row)) {
        (void)hv_stores(out, "gone", newSViv(1));
        return newRV_noinc((SV *)out);
    }
    (void)hv_stores(out, "gone", newSViv(0));

    {
        HV *r = (HV *)SvRV(row);
        SV *col = of ? pak_hget(aTHX_ of, "suspended") : NULL;
        if (col && SvOK(col)) {
            SV *v = pak_hget(aTHX_ r, SvPV_nolen(col));
            (void)hv_stores(out, "suspended",
                            newSViv(v && SvTRUE(v) ? 1 : 0));
        }
        col = of ? pak_hget(aTHX_ of, "role") : NULL;
        {
            SV *rk = pak_hget(aTHX_ cfg, "rank");
            HV *rank = pak_is_hash(rk) ? (HV *)SvRV(rk) : NULL;
            if (col && SvOK(col) && rank && HvUSEDKEYS(rank)) {
                SV *v = pak_hget(aTHX_ r, SvPV_nolen(col));
                SV **pos = (v && SvOK(v))
                    ? hv_fetch(rank, SvPV_nolen(v), (I32)SvCUR(v), 0) : NULL;
                (void)hv_stores(out, "rank",
                    newSViv((pos && *pos) ? SvIV(*pos) : -1));
            }
        }
    }
    return newRV_noinc((SV *)out);
}

/* ---- after a passing check ------------------------------------------------
 *
 * The row into the stash, the per-key limit, and last_used. Returns a triplet
 * to refuse (the 429) or NULL to continue.
 */
static SV *pak_after_check(pTHX_ SV *c, HV *cfg, SV *row)
{
    HV *r = (HV *)SvRV(row);
    SV *id, *limit;
    HV *stash = pak_stash_of(aTHX_ c);

    if (stash) (void)hv_stores(stash, "punk.apikey", newSVsv(row));

    id    = pak_hget(aTHX_ r, SvPV_nolen(pak_col(aTHX_ cfg, "id")));
    limit = pak_hget(aTHX_ r, SvPV_nolen(pak_col(aTHX_ cfg, "rate_per_min")));

    /* Keyed by ROW ID, never by the credential. rate_limit's counters live in
     * Hyperman's shared arena under their key's name, so keying by the
     * Authorization header would write the secret into shared memory - which
     * is why the POD says in bold not to do that with this plugin loaded. */
    if (limit && SvOK(limit) && SvIV(limit) > 0 && id && SvOK(id)) {
        SV *k = sv_2mortal(newSVpvs("apikey:"));
        SV *argv[3];
        SV *rsv, *osv;
        dSP;
        int count;
        IV ok = 1, reset = 0;

        sv_catsv(k, id);
        argv[0] = k;
        argv[1] = limit;
        argv[2] = sv_2mortal(newSViv(60));

        ENTER; SAVETMPS;
        PUSHMARK(SP);
        EXTEND(SP, 4);
        PUSHs(c); PUSHs(argv[0]); PUSHs(argv[1]); PUSHs(argv[2]);
        PUTBACK;
        count = call_method("rate_hit", G_LIST);
        SPAGAIN;
        /* POP FIRST, CONVERT AFTER. SvIV mentions its argument more than once
         * until 5.37.1, so SvIV(POPs) pops once per mention and reads the
         * verdict from whatever sits below it: the limiter's own answer comes
         * back as whatever the stack happened to hold, which refuses a request
         * inside its limit or admits one past it. */
        if (count >= 3) {
            rsv = POPs; (void)POPs; osv = POPs;
            reset = SvIV(rsv); ok = SvIV(osv);
        }
        else if (count > 0) {
            while (count-- > 1) (void)POPs;
            osv = POPs; ok = SvIV(osv);
        }
        PUTBACK; FREETMPS; LEAVE;

        if (!ok) {
            /* The limiter's shape, not this plugin's: a client that already
             * handles rate_limit's 429 must handle this one identically. */
            IV after = reset ? reset - (IV)time(NULL) : 60;
            AV *out = newAV(), *hdr = newAV(), *bod = newAV();
            SV *ra;
            if (after < 1) after = 1;
            ra = newSViv(after);
            av_push(hdr, newSVpvs("Content-Type"));
            av_push(hdr, newSVpvs("application/problem+json"));
            av_push(hdr, newSVpvs("Retry-After"));
            av_push(hdr, ra);
            av_push(hdr, newSVpvs("X-RateLimit-Limit"));
            av_push(hdr, newSVsv(limit));
            av_push(hdr, newSVpvs("X-RateLimit-Remaining"));
            av_push(hdr, newSViv(0));
            av_push(hdr, newSVpvs("X-RateLimit-Reset"));
            av_push(hdr, newSViv(reset ? reset : (IV)time(NULL) + after));
            av_push(bod, newSVpvs(
                "{\"type\":\"about:blank\",\"title\":\"Too Many Requests\","
                "\"status\":429}"));
            av_push(out, newSViv(429));
            av_push(out, newRV_noinc((SV *)hdr));
            av_push(out, newRV_noinc((SV *)bod));
            return newRV_noinc((SV *)out);
        }
    }

    /* Best effort, and at most once a minute: "is anyone still using this
     * key" does not need second precision, and it is not worth a write per
     * request. A failed write never refuses the request. */
    {
        SV *lu = pak_hget(aTHX_ r, SvPV_nolen(pak_col(aTHX_ cfg, "last_used")));
        IV now = (IV)time(NULL);
        if (id && SvOK(id) && (!(lu && SvOK(lu)) || now - SvIV(lu) >= 60)) {
            /* Best effort: a failed write never refuses the request, and it
             * must not corrupt the stack on the way to not refusing it. */
            int failed = 0;
            SV *model = pak_try_model(aTHX_ cfg, &failed);
            if (!failed && model) {
                HV *up = (HV *)sv_2mortal((SV *)newHV());
                SV *argv[1], *col, *r;
                STRLEN cl;
                const char *cp;
                sv_2mortal(model);
                col = pak_col(aTHX_ cfg, "id");
                cp = SvPV_const(col, cl);
                (void)hv_store(up, cp, (I32)cl, newSVsv(id), 0);
                col = pak_col(aTHX_ cfg, "last_used");
                cp = SvPV_const(col, cl);
                (void)hv_store(up, cp, (I32)cl, newSViv(now), 0);
                argv[0] = sv_2mortal(newRV_inc((SV *)up));
                r = pak_try(aTHX_ model, "update", NULL, argv, 1, &failed);
                if (r) SvREFCNT_dec(r);
            }
            else if (model) SvREFCNT_dec(model);
        }
    }
    return NULL;
}

/* ---- a guard's own options ------------------------------------------------
 *
 * Checked where the application writes api_key_guard(scope => 'wrte') - which
 * is boot - and not at the request. A guard asking for a scope no key can
 * ever hold would otherwise be a route that refuses everyone, in production.
 */
static SV *pak_guard_scope(pTHX_ HV *cfg, SV **args, int nargs)
{
    SV *scope = NULL;
    SV *sv = pak_hget(aTHX_ cfg, "scopes");
    HV *vocab = pak_is_hash(sv) ? (HV *)SvRV(sv) : NULL;
    int i;

    if (nargs % 2)
        croak(PAK_WHO ": a guard takes name => value pairs (known: scope)");
    for (i = 0; i + 1 < nargs; i += 2) {
        STRLEN kl;
        const char *k = SvPV_const(args[i], kl);
        if (!(kl == 5 && memEQ(k, "scope", 5)))
            croak(PAK_WHO ": unknown guard option '%.*s' (known: scope)",
                  (int)kl, k);
        scope = args[i + 1];
    }
    if (!(scope && SvOK(scope))) return NULL;

    {
        AV *want = (AV *)sv_2mortal((SV *)pak_as_list(aTHX_ scope));
        SSize_t j, n = av_len(want) + 1;
        for (j = 0; j < n; j++) {
            SV *one = *av_fetch(want, j, 0);
            STRLEN ol;
            const char *op = SvPV_const(one, ol);
            if (vocab && !hv_exists(vocab, op, (I32)ol))
                croak(PAK_WHO ": scope '%.*s' is not in the vocabulary (%s)",
                      (int)ol, op, SvPV_nolen(pak_key_list(aTHX_ vocab)));
        }
    }
    return scope;
}

#endif /* PAK_APIKEY_REG_H */
