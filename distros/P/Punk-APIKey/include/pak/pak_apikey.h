#ifndef PAK_APIKEY_H
#define PAK_APIKEY_H

/* Punk::Plugin::APIKey - the part that runs per request.
 *
 * The configuration is one hash per application class, built and validated in
 * Perl at `plugin` time and held live. Its keys:
 *
 *   model        the model name to look a key up through
 *   fields       { logical => column }
 *   kinds        { kind => prefix }
 *   scopes       { scope => 1 }              the declared vocabulary
 *   header       the header to read, or undef for Authorization: Bearer
 *   owner_model  the model an owner's standing is read through, or absent
 *   owner_ttl    seconds a worker trusts a standing
 *   owner_cache  { id => [ standing, fetched ] }, bounded
 *   rank         { role => position }        auth's ladder, flattened
 *   scope_rank   { scope => role }
 *   pid          the worker that owns owner_cache
 *
 * The refusals are all here. There is one shape for every reason a
 * credential is not good - missing, malformed, bad checksum, unknown kind,
 * unknown digest, revoked, expired, owner gone - because a client that can
 * tell "unknown" from "revoked" can enumerate keys, and the difference is of
 * no use to a caller who is not doing that.
 */

/* The house error shape, as Punk's own 401 and 403 write it. Not
 * problem+json: that is what the rate limiter answers, and this is the API's
 * own refusal. Both appear in this plugin, and the POD says which is which. */
#define PAK_401_BODY "{\"errors\":[{\"message\":\"Unauthorized\"}]}"
#define PAK_403_BODY "{\"errors\":[{\"message\":\"Forbidden\"}]}"
#define PAK_503_BODY "{\"errors\":[{\"message\":\"Service Unavailable\"}]}"

/* A PSGI triplet, which is what a guard returns to short-circuit. */
static SV *pak_deny(pTHX_ int status, const char *body, const char *extra_k,
                     const char *extra_v)
{
    AV *out = newAV();
    AV *hdr = newAV();
    AV *bod = newAV();

    av_push(hdr, newSVpvs("Content-Type"));
    av_push(hdr, newSVpvs("application/json"));
    if (extra_k) {
        av_push(hdr, newSVpv(extra_k, 0));
        av_push(hdr, newSVpv(extra_v, 0));
    }
    av_push(bod, newSVpv(body, 0));

    av_push(out, newSViv(status));
    av_push(out, newRV_noinc((SV *)hdr));
    av_push(out, newRV_noinc((SV *)bod));
    return newRV_noinc((SV *)out);
}

/* Every "this credential is not good" answer. WWW-Authenticate because a 401
 * without it is an incomplete answer, and Bearer because that is the scheme
 * even when the key arrived in a named header. */
static SV *pak_deny_401(pTHX)
{
    return pak_deny(aTHX_ 401, PAK_401_BODY, "WWW-Authenticate", "Bearer");
}

/* ---- the credential ---------------------------------------------------------
 *
 * Authorization: Bearer <key>, or a named header for an API that promised a
 * different spelling. Read from the env directly: this runs on every guarded
 * request and $c->req->header would be two method calls to reach a hash. */

static SV *pak_credential(pTHX_ HV *cfg, SV *c)
{
    SV *env = pak_cx_slot(aTHX_ c, PAK_CX_ENV);
    HV *e;
    SV *hdr, *v;

    if (!pak_is_hash(env)) return NULL;
    e = (HV *)SvRV(env);

    hdr = pak_hget(aTHX_ cfg, "header_env");
    if (hdr && SvOK(hdr)) {
        STRLEN hl;
        const char *hp = SvPV_const(hdr, hl);
        SV **slot = hv_fetch(e, hp, (I32)hl, 0);
        return (slot && *slot && SvOK(*slot)) ? *slot : NULL;
    }

    v = pak_hget(aTHX_ e, "HTTP_AUTHORIZATION");
    if (!(v && SvOK(v))) return NULL;
    {
        STRLEN vl;
        const char *vp = SvPV_const(v, vl);
        /* "Bearer " - the scheme is case insensitive per RFC 7235 */
        if (vl > 7 && (vp[0] == 'B' || vp[0] == 'b')
            && (vp[1] == 'e' || vp[1] == 'E') && (vp[2] == 'a' || vp[2] == 'A')
            && (vp[3] == 'r' || vp[3] == 'R') && (vp[4] == 'e' || vp[4] == 'E')
            && (vp[5] == 'r' || vp[5] == 'R') && vp[6] == ' ') {
            const char *s = vp + 7;
            STRLEN n = vl - 7;
            while (n && *s == ' ') { s++; n--; }
            return sv_2mortal(newSVpvn(s, n));
        }
        return v;   /* a bare key, for a client that sent no scheme */
    }
}

/* ---- scopes -----------------------------------------------------------------
 *
 * A flat set against a declared vocabulary, not Punk::Auth's rank ladder: an
 * API scope is a permission, and `write` does not imply `read` unless the
 * application issued both. */

static HV *pak_scope_set(pTHX_ SV *joined)
{
    HV *set = newHV();
    STRLEN l;
    const char *p, *start;
    STRLEN i;

    if (!(joined && SvOK(joined))) return set;
    p = SvPV_const(joined, l);
    start = p;
    for (i = 0; i <= l; i++) {
        if (i == l || p[i] == ' ' || p[i] == '\t' || p[i] == ',') {
            STRLEN n = (STRLEN)(p + i - start);
            if (n) (void)hv_store(set, start, (I32)n, newSViv(1), 0);
            start = p + i + 1;
        }
    }
    return set;
}

/* Does the holder have at least one of what the guard asked for? An empty
 * requirement is "any valid key", which is what `under '/api' =>
 * api_key_guard` with no scope means. */
static int pak_scope_ok(pTHX_ HV *have, SV *want)
{
    if (!(want && SvOK(want))) return 1;
    if (pak_is_array(want)) {
        AV *av = (AV *)SvRV(want);
        SSize_t i, n = av_len(av) + 1;
        if (!n) return 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(av, i, 0);
            if (e && *e && SvOK(*e)) {
                STRLEN sl;
                const char *sp = SvPV_const(*e, sl);
                if (hv_exists(have, sp, (I32)sl)) return 1;
            }
        }
        return 0;
    }
    {
        STRLEN sl;
        const char *sp = SvPV_const(want, sl);
        return hv_exists(have, sp, (I32)sl) ? 1 : 0;
    }
}

/* ---- the owner's standing ---------------------------------------------------
 *
 * A key is a credential for an account, and an account's standing changes
 * after the key is minted. Without this a suspended user's key keeps working
 * and an admin-scoped key outlives the demotion that took admin away, with
 * revoking every key by hand as the only remedy - which means the remedy is
 * forgotten.
 *
 * Cached per owner id rather than as a whole-table snapshot: there are as
 * many owners as users. Bounded, and pid-stamped, like every other
 * per-worker cache here.
 *
 * Returns 1 to continue, 0 when *deny was filled in.
 */

#define PAK_OWNER_CACHE_MAX 1024

static int pak_owner_ok(pTHX_ HV *cfg, SV *c, SV *owner_id, HV *scopes,
                         SV **deny)
{
    SV *om = pak_hget(aTHX_ cfg, "owner_model");
    HV *cache;
    SV *cv, *standing = NULL;
    IV now = (IV)time(NULL);
    IV ttl = pak_hiv(aTHX_ cfg, "owner_ttl", 30);
    STRLEN idl;
    const char *idp;

    *deny = NULL;
    if (!(om && SvOK(om))) return 1;       /* off: keys stand alone */
    if (!(owner_id && SvOK(owner_id))) return 1;

    /* a fork invalidates what the parent cached */
    if (pak_hiv(aTHX_ cfg, "pid", 0) != (IV)PerlProc_getpid()) {
        (void)hv_stores(cfg, "owner_cache", newRV_noinc((SV *)newHV()));
        (void)hv_stores(cfg, "pid", newSViv((IV)PerlProc_getpid()));
    }
    cv = pak_hget(aTHX_ cfg, "owner_cache");
    if (!pak_is_hash(cv)) {
        SV *fresh = newRV_noinc((SV *)newHV());
        (void)hv_stores(cfg, "owner_cache", fresh);
        cv = fresh;
    }
    cache = (HV *)SvRV(cv);
    idp = SvPV_const(owner_id, idl);

    {
        SV **slot = hv_fetch(cache, idp, (I32)idl, 0);
        if (slot && *slot && pak_is_array(*slot)) {
            AV *ent = (AV *)SvRV(*slot);
            SV **fe = av_fetch(ent, 1, 0);
            if (fe && *fe && now - SvIV(*fe) < ttl) {
                SV **se = av_fetch(ent, 0, 0);
                standing = (se && *se) ? *se : NULL;
            }
        }
    }

    if (!standing) {
        SV *argv[2];
        SV *got;
        /* A crude bound: past it the whole cache goes rather than a victim
         * being chosen. A worker serving more than this many distinct keys
         * inside one ttl is doing a different job, and an eviction policy
         * for a case that does not arise is code that is never right. */
        if (HvUSEDKEYS(cache) >= PAK_OWNER_CACHE_MAX) hv_clear(cache);

        PERL_UNUSED_VAR(argv);
        got = sv_2mortal(pak_standing(aTHX_ c, cfg, owner_id));

        /* NULL means the read FAILED, which is not the same as the owner not
         * existing - a missing owner comes back as { gone => 1 }. */
        if (!(got && SvOK(got))) {
            *deny = pak_deny(aTHX_ 503, PAK_503_BODY, "Retry-After", "5");
            return 0;
        }
        if (!pak_is_hash(got)) return 1;
        standing = got;
        {
            AV *ent = newAV();
            av_push(ent, newSVsv(standing));
            av_push(ent, newSViv(now));
            (void)hv_store(cache, idp, (I32)idl,
                           newRV_noinc((SV *)ent), 0);
        }
    }

    {
        HV *st = (HV *)SvRV(standing);
        SV *v;

        v = pak_hget(aTHX_ st, "gone");
        if (v && SvTRUE(v)) {
            /* The owner is not there. Same answer as an unknown key: the
             * credential is no good, and which of the two it is would tell a
             * caller something they have no business learning. */
            *deny = pak_deny_401(aTHX);
            return 0;
        }

        v = pak_hget(aTHX_ st, "suspended");
        if (v && SvTRUE(v)) {
            /* 403, not 401. The caller has already proved they hold the key,
             * so there is nothing to enumerate, and "your account is
             * suspended" is the useful answer rather than a lie about the
             * credential. */
            *deny = pak_deny(aTHX_ 403, PAK_403_BODY, NULL, NULL);
            return 0;
        }

        /* A demotion NARROWS the key rather than killing it: a former admin's
         * CI keeps deploying and stops administering, which is what demotion
         * means. Scopes the owner's current role no longer reaches are
         * dropped from the effective set for this request. */
        v = pak_hget(aTHX_ st, "rank");
        if (v && SvOK(v)) {
            IV have_rank = SvIV(v);
            SV *sr = pak_hget(aTHX_ cfg, "scope_rank_n");
            if (pak_is_hash(sr)) {
                HV *need = (HV *)SvRV(sr);
                HE *he;
                AV *drop = (AV *)sv_2mortal((SV *)newAV());
                SSize_t i, n;
                hv_iterinit(scopes);
                while ((he = hv_iternext(scopes))) {
                    STRLEN sl;
                    const char *sp = HePV(he, sl);
                    SV **ne = hv_fetch(need, sp, (I32)sl, 0);
                    if (ne && *ne && SvOK(*ne) && SvIV(*ne) > have_rank)
                        av_push(drop, newSVpvn(sp, sl));
                }
                n = av_len(drop) + 1;
                for (i = 0; i < n; i++) {
                    SV *d = *av_fetch(drop, i, 0);
                    STRLEN dl;
                    const char *dp = SvPV_const(d, dl);
                    (void)hv_delete(scopes, dp, (I32)dl, G_DISCARD);
                }
            }
        }
    }
    return 1;
}

/* ---- the check --------------------------------------------------------------
 *
 * One routine behind both entry points. `cred` is supplied by the OpenAPI
 * checker and read from the request by the guard.
 *
 * On success it fills *auth with { owner, key, kind, scopes } - the slot
 * Punk::Auth and the OpenAPI mount both use - and returns 1. On refusal it
 * fills *deny with a triplet and returns 0.
 */

static int pak_check(pTHX_ HV *cfg, SV *c, SV *cred, SV *want_scope,
                      SV **auth, SV **deny)
{
    HV *kinds = NULL;
    SV *v, *kind = NULL, *row = NULL;
    STRLEN cl;
    const char *cp;
    int verdict;

    *auth = NULL;
    *deny = NULL;

    if (!(cred && SvOK(cred) && SvCUR(cred))) {
        *deny = pak_deny_401(aTHX);
        return 0;
    }
    cp = SvPV_const(cred, cl);

    v = pak_hget(aTHX_ cfg, "kinds");
    if (pak_is_hash(v)) kinds = (HV *)SvRV(v);

    /* Parsed before anything else: a truncated or mistyped key never becomes
     * a database query, which is the whole point of carrying a checksum. */
    verdict = pak_parse(aTHX_ kinds, cp, cl, &kind);
    if (verdict != PAK_OK) {
        *deny = pak_deny_401(aTHX);
        return 0;
    }

    {
        SV *digest = sv_2mortal(pak_digest(aTHX_ cred));
        SV *model = pak_hget(aTHX_ cfg, "model");
        SV *fields = pak_hget(aTHX_ cfg, "fields");
        HV *f = pak_is_hash(fields) ? (HV *)SvRV(fields) : NULL;
        SV *dcol = f ? pak_hget(aTHX_ f, "digest") : NULL;
        SV *margv[1], *m, *gargv[2];

        margv[0] = model ? model : &PL_sv_undef;
        m = sv_2mortal(pak_call(aTHX_ c, "model", margv, 1));
        if (!(m && SvOK(m))) { *deny = pak_deny_401(aTHX); return 0; }

        gargv[0] = dcol ? dcol : sv_2mortal(newSVpvs("digest"));
        gargv[1] = digest;
        row = sv_2mortal(pak_call(aTHX_ m, "get", gargv, 2));
        row = sv_2mortal(pak_await(aTHX_ c, row));
    }

    if (!pak_is_hash(row)) { *deny = pak_deny_401(aTHX); return 0; }

    {
        HV *r = (HV *)SvRV(row);
        SV *fields = pak_hget(aTHX_ cfg, "fields");
        HV *f = pak_is_hash(fields) ? (HV *)SvRV(fields) : NULL;
        IV now = (IV)time(NULL);
        SV *col;
        HV *have;

#define PAK_COL(name) \
        (f && (col = pak_hget(aTHX_ f, name)) && SvOK(col) \
            ? pak_hget(aTHX_ r, SvPV_nolen(col)) : pak_hget(aTHX_ r, name))

        v = PAK_COL("revoked");
        if (v && SvOK(v) && SvIV(v)) { *deny = pak_deny_401(aTHX); return 0; }

        v = PAK_COL("expires");
        if (v && SvOK(v) && SvIV(v) && SvIV(v) <= now) {
            *deny = pak_deny_401(aTHX);
            return 0;
        }

        /* The row's kind and the prefix's must agree. A key whose prefix
         * claims one kind while its row records another is forged or mangled,
         * and the row is the one that was written by this application. */
        v = PAK_COL("kind");
        if (v && SvOK(v) && kind && SvOK(kind) && !sv_eq(v, kind)) {
            *deny = pak_deny_401(aTHX);
            return 0;
        }

        have = (HV *)sv_2mortal((SV *)pak_scope_set(aTHX_ PAK_COL("scopes")));

        {
            SV *owner = PAK_COL("owner");
            SV *odeny = NULL;
            if (!pak_owner_ok(aTHX_ cfg, c, owner, have, &odeny)) {
                *deny = odeny;
                return 0;
            }

            if (!pak_scope_ok(aTHX_ have, want_scope)) {
                /* 403 here and only here. The OpenAPI checker form cannot
                 * say 403 - the mount turns anything false into a 401 - so
                 * the two entry points differ, and the POD says so. */
                *deny = pak_deny(aTHX_ 403, PAK_403_BODY, NULL, NULL);
                return 0;
            }

            {
                HV *a = newHV();
                AV *slist = newAV();
                HE *he;
                SSize_t i, n;
                hv_iterinit(have);
                while ((he = hv_iternext(have)))
                    av_push(slist, newSVsv(HeSVKEY_force(he)));
                n = av_len(slist) + 1;
                if (n > 1) sortsv(AvARRAY(slist), (STRLEN)n, Perl_sv_cmp);
                (void)hv_stores(a, "owner", owner ? newSVsv(owner) : newSV(0));
                (void)hv_stores(a, "key",   newSVsv(PAK_COL("id")
                                                    ? PAK_COL("id") : &PL_sv_undef));
                (void)hv_stores(a, "kind",  kind ? newSVsv(kind) : newSV(0));
                (void)hv_stores(a, "scopes", newRV_noinc((SV *)slist));
                *auth = sv_2mortal(newRV_noinc((SV *)a));
                for (i = 0; i < 0; i++) { /* silence an unused warning path */ }

                {   /* And into a slot of the plugin's own, beside the row.
                     *
                     * An OpenAPI mount's security check REPLACES
                     * $c->stash->{auth} with a fresh hash of its per-scheme
                     * results, so a guard's answer does not survive one - a
                     * controller behind an `api` mount that read the usual
                     * slot would find an empty owner and no scopes. This
                     * name is the plugin's, nothing else writes it, and
                     * $c->api_key_auth reads it. */
                    HV *st = pak_stash_of(aTHX_ c);
                    if (st)
                        (void)hv_stores(st, "punk.apikey.auth", newSVsv(*auth));
                }
            }

            /* The row into the stash, the per-key limit and last_used. A
             * 429 comes back as a triplet, which is a refusal like any
             * other - the only one this plugin answers in the limiter's
             * shape rather than its own. */
            {
                SV *over = pak_after_check(aTHX_ c, cfg, row);
                if (over) { *deny = over; return 0; }
            }
        }
#undef PAK_COL
    }
    return 1;
}

/* ---- the bodies -------------------------------------------------------------
 *
 * XSUBs, so they live here rather than in xs/apikey.xs: anything after a
 * `MODULE =` line is xsubpp's to parse. */

/* the guard for an `under` chain */
XS_INTERNAL(pak_k_guard);
XS_INTERNAL(pak_k_guard)
{
    dXSARGS;
    HV *cfg = pak_cfg_of(aTHX_ cv);
    SV *want = pak_arg_of(aTHX_ cv);
    SV *auth = NULL, *deny = NULL;
    SV *cred;

    if (items < 1) XSRETURN_EMPTY;
    cred = pak_credential(aTHX_ cfg, ST(0));

    if (!pak_check(aTHX_ cfg, ST(0), cred, want, &auth, &deny)) {
        ST(0) = sv_2mortal(deny);
        XSRETURN(1);
    }
    {   /* $c->stash->{auth} - the slot Punk::Auth and the mount both use */
        HV *stash = pak_stash_of(aTHX_ ST(0));
        if (stash) (void)hv_stores(stash, "auth", newSVsv(auth));
    }
    XSRETURN_EMPTY;              /* continue */
}

/* the OpenAPI security checker: ($credential, $c, $op_id, $scopes) */
XS_INTERNAL(pak_k_checker);
XS_INTERNAL(pak_k_checker)
{
    dXSARGS;
    HV *cfg = pak_cfg_of(aTHX_ cv);
    SV *want = pak_arg_of(aTHX_ cv);
    SV *auth = NULL, *deny = NULL;
    SV *cred, *c;

    if (items < 2) XSRETURN_NO;
    cred = ST(0);
    c    = ST(1);

    /* The spec's own scopes for this operation are ALSO required: the
     * keyword's list is any-of, the document's is all-of, and both hold. */
    if (items > 3 && pak_is_array(ST(3))) {
        AV *need = (AV *)SvRV(ST(3));
        SSize_t i, n = av_len(need) + 1;
        if (n) {
            SV *a2 = NULL, *d2 = NULL;
            if (!pak_check(aTHX_ cfg, c, cred, want, &a2, &d2)) XSRETURN_NO;
            {
                HV *a = (HV *)SvRV(a2);
                SV *sl = pak_hget(aTHX_ a, "scopes");
                AV *got = pak_is_array(sl) ? (AV *)SvRV(sl) : NULL;
                for (i = 0; i < n; i++) {
                    SV **w = av_fetch(need, i, 0);
                    int found = 0;
                    SSize_t j, m = got ? av_len(got) + 1 : 0;
                    if (!(w && *w && SvOK(*w))) continue;
                    for (j = 0; j < m; j++) {
                        SV **g = av_fetch(got, j, 0);
                        if (g && *g && sv_eq(*g, *w)) { found = 1; break; }
                    }
                    if (!found) XSRETURN_NO;
                }
            }
            ST(0) = a2;
            XSRETURN(1);
        }
    }

    /* A refusal is FALSE, not a triplet: punk_oa_security_cb stores anything
     * truthy as the authorisation, so a 403 triplet returned here would
     * AUTHORISE the request. The mount answers 401 for everything. */
    if (!pak_check(aTHX_ cfg, c, cred, want, &auth, &deny)) XSRETURN_NO;
    ST(0) = auth;
    XSRETURN(1);
}

#endif /* PAK_APIKEY_H */
