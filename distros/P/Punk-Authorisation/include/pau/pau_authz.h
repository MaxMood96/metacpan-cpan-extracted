#ifndef PAU_AUTHZ_H
#define PAU_AUTHZ_H

/* Punk::Plugin::Authorisation: "may this user act on THIS ROW".
 *
 * auth_guard answers "may this user reach this route"; an API key's scope
 * answers "may this credential call this operation". Neither can answer the
 * question a controller asks after it has loaded a row by an id from the
 * request, and a controller that forgets to ask is the commonest
 * authorisation bug there is.
 *
 * The rules are the application's, in a package it owns. What is here is the
 * machinery around them: collecting them, refusing to guess at a name nobody
 * defined, and turning a refusal into the right status.
 *
 * One property holds everything else up: EVERY REFUSAL IS FALSE. A rule that
 * returned -1 for "not enough rank" would be returning a TRUE value, and
 * `$c->may(...) or return $c->deny` would let it through. `forbidden` and
 * `not_yours` are false and record which was meant; nothing else can refuse.
 *
 * Include after pau_clos.h and pau_reg.h.
 */

#define PAZ_WHO "Punk::Plugin::Authorisation"

/* the configuration, one per application class */
static HV *PAZ_STATE = NULL;
/* the rules, one hash per POLICY package: name => coderef. Filled by `rule`
 * as the policy package compiles, taken by register when it runs. */
static HV *PAZ_RULES = NULL;

/* the stash keys a refusal writes and deny reads */
#define PAZ_WHY     "punk.authz.why"
#define PAZ_SUBJECT "punk.authz.subject"

static const char *const PAZ_OPTS[] =
    { "policy", "grants", "rank", "roles", "fields", NULL };
/* The grants table's columns: the logical name a rule or an option uses, and
 * the column it means. `fields` renames any of them; the toolkit's map
 * defaults each name to itself, which is not what these are called. */
static const char *const PAZ_FIELDS[] =
    { "subject", "action", "object", "granted_by", "created", NULL };
static const char *const PAZ_COLUMNS[] =
    { "subject_id", "action", "object_id", "granted_by", "created", NULL };

/* pau_field_map with real defaults: validate the caller's keys the toolkit's
 * way, then put the columns back for the ones they did not rename. */
static HV *paz_field_map(pTHX_ HV *given)
{
    HV *out = pau_field_map(aTHX_ PAZ_WHO, "field", PAZ_FIELDS, given);
    int i;
    for (i = 0; PAZ_FIELDS[i]; i++) {
        SV **e;
        if (given && hv_exists(given, PAZ_FIELDS[i], (I32)strlen(PAZ_FIELDS[i])))
            continue;
        e = hv_fetch(out, PAZ_FIELDS[i], (I32)strlen(PAZ_FIELDS[i]), 0);
        if (e && *e) sv_setpv(*e, PAZ_COLUMNS[i]);
    }
    return out;
}
static const char *const PAZ_ENGINES[] = { "sqlite", "pg", "mysql", NULL };

static HV *paz_state_for(pTHX_ SV *class_sv)
{
    STRLEN cl;
    const char *cp;
    SV **e;
    if (!PAZ_STATE || !(class_sv && SvOK(class_sv))) return NULL;
    cp = SvPV_const(class_sv, cl);
    e = hv_fetch(PAZ_STATE, cp, (I32)cl, 0);
    return (e && *e && pau_is_hash(*e)) ? (HV *)SvRV(*e) : NULL;
}

/* The rules a policy package has declared so far, made on first use. */
static HV *paz_rules_of(pTHX_ SV *pkg, int create)
{
    STRLEN pl;
    const char *pp;
    SV **e;
    if (!PAZ_RULES) {
        if (!create) return NULL;
        PAZ_RULES = newHV();
    }
    pp = SvPV_const(pkg, pl);
    e = hv_fetch(PAZ_RULES, pp, (I32)pl, 0);
    if (e && *e && pau_is_hash(*e)) return (HV *)SvRV(*e);
    if (!create) return NULL;
    {
        HV *h = newHV();
        (void)hv_store(PAZ_RULES, pp, (I32)pl, newRV_noinc((SV *)h), 0);
        return h;
    }
}

/* ---- `rule` ----------------------------------------------------------------
 *
 * Installed into a policy package by `use Punk::Plugin::Authorisation;`. The
 * package it belongs to rides in the closure's capture, so one body serves
 * every policy package in the process.
 */
XS_INTERNAL(paz_kw_rule);
XS_INTERNAL(paz_kw_rule)
{
    dXSARGS;
    SV *pkg = pau_arg_of(aTHX_ cv);
    HV *rules;
    SV *name, *code;
    STRLEN nl;
    const char *np;

    if (items != 2 || !SvOK(ST(0)) || !(SvROK(ST(1))
        && SvTYPE(SvRV(ST(1))) == SVt_PVCV))
        croak(PAZ_WHO ": rule needs a name and a coderef");
    name = ST(0);
    code = ST(1);
    np = SvPV_const(name, nl);

    {   /* dotted lowercase parts, as in key.revoke */
        STRLEN i;
        int part = 0, ok = 1;
        for (i = 0; i < nl && ok; i++) {
            char ch = np[i];
            if (ch == '.') { ok = part > 0; part = 0; continue; }
            if (part == 0) ok = (ch >= 'a' && ch <= 'z');
            else ok = (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')
                   || ch == '_';
            part++;
        }
        if (!ok || part == 0)
            croak(PAZ_WHO ": '%.*s' is not an action name ([a-z][a-z0-9_]* in "
                  "dotted parts, as in key.revoke)", (int)nl, np);
    }

    rules = paz_rules_of(aTHX_ pkg, 1);
    if (hv_exists(rules, np, (I32)nl))
        croak(PAZ_WHO ": %s defines the rule '%.*s' twice",
              SvPV_nolen(pkg), (int)nl, np);
    (void)hv_store(rules, np, (I32)nl, newSVsv(code), 0);
    XSRETURN_EMPTY;
}

/* ---- the refusals ------------------------------------------------------------ */

/* Both are FALSE, and both record which refusal was meant. */
static void paz_set_why(pTHX_ SV *c, IV status)
{
    HV *stash = pau_stash_of(aTHX_ c);
    if (stash) (void)hv_stores(stash, PAZ_WHY, newSViv(status));
}

XS_INTERNAL(paz_h_forbidden);
XS_INTERNAL(paz_h_forbidden)
{
    dXSARGS;
    if (items < 1) croak(PAZ_WHO ": forbidden is a context method");
    paz_set_why(aTHX_ ST(0), 403);
    ST(0) = sv_2mortal(newSViv(0));
    XSRETURN(1);
}

XS_INTERNAL(paz_h_not_yours);
XS_INTERNAL(paz_h_not_yours)
{
    dXSARGS;
    if (items < 1) croak(PAZ_WHO ": not_yours is a context method");
    paz_set_why(aTHX_ ST(0), 404);
    ST(0) = sv_2mortal(newSViv(0));
    XSRETURN(1);
}

/* ---- may -----------------------------------------------------------------------
 *
 * The rule, as 0 or 1, and never anything else. An action no rule defines
 * CROAKS with the names that do: a typo must not decide - false on the page
 * nobody tests and true on the one somebody rewrites.
 *
 * The rule is called in SCALAR context so an empty list cannot arrive as a
 * true count, and nothing is cached: a rule reads rows this request may
 * already have changed.
 */
XS_INTERNAL(paz_h_may);
XS_INTERNAL(paz_h_may)
{
    dXSARGS;
    HV *cfg = pau_cfg_of(aTHX_ cv);
    SV *rules_sv = pau_hget(aTHX_ cfg, "rules");
    HV *rules = pau_is_hash(rules_sv) ? (HV *)SvRV(rules_sv) : NULL;
    SV *c, *action, **code;
    HV *stash;
    STRLEN al;
    const char *ap;
    SV *out;
    int i, argc;
    SV **argv;

    if (items < 2 || !SvOK(ST(1)))
        croak(PAZ_WHO ": may needs an action name");
    c = ST(0);
    action = ST(1);
    ap = SvPV_const(action, al);

    code = rules ? hv_fetch(rules, ap, (I32)al, 0) : NULL;
    if (!(code && *code && SvROK(*code))) {
        SV *have = rules ? pau_key_list(aTHX_ rules)
                         : sv_2mortal(newSVpvs(""));
        SV *policy = pau_hget(aTHX_ cfg, "policy");
        croak(PAZ_WHO ": no rule for '%.*s' in %s (have: %s)",
              (int)al, ap, policy ? SvPV_nolen(policy) : "the policy",
              SvPV_nolen(have));
    }

    stash = pau_stash_of(aTHX_ c);
    if (stash) {
        (void)hv_delete(stash, PAZ_WHY, (I32)strlen(PAZ_WHY), G_DISCARD);
        (void)hv_stores(stash, PAZ_SUBJECT, newSViv(items > 2 ? 1 : 0));
    }

    argc = 1 + (items - 2);
    Newx(argv, argc, SV *);
    argv[0] = c;
    for (i = 2; i < items; i++) argv[i - 1] = ST(i);
    out = sv_2mortal(pau_call_common(aTHX_ NULL, NULL, *code, argv, argc));
    Safefree(argv);

    ST(0) = sv_2mortal(newSViv(SvTRUE(out) ? 1 : 0));
    XSRETURN(1);
}

/* ---- deny ----------------------------------------------------------------------
 *
 * The status is the one the rule recorded. Without one it is 404 when the
 * check carried a subject and 403 when it did not: a subject means a row
 * whose existence is nobody's business, and a 403 on someone else's id
 * confirms the id.
 *
 * A plain 404 goes through $c->not_found, so an application's on_not_found
 * page answers it. Otherwise a browser gets a page and everything else the
 * house error object, which is the shape auth_guard's own denial uses.
 */
static int paz_wants_html(pTHX_ SV *c)
{
    SV *req, *hdr, *argv[1];
    const char *p, *end;
    int wants = 0;

    req = sv_2mortal(pau_call(aTHX_ c, "req", NULL, 0));
    if (!(req && SvROK(req))) return 0;
    argv[0] = sv_2mortal(newSVpvs("Accept"));
    hdr = sv_2mortal(pau_call(aTHX_ req, "header", argv, 1));
    if (!(hdr && SvOK(hdr) && SvCUR(hdr))) return 0;

    p = SvPVX(hdr);
    end = p + SvCUR(hdr);
    while (p < end) {
        const char *comma = (const char *)memchr(p, ',', (STRLEN)(end - p));
        const char *stop = comma ? comma : end;
        const char *semi = (const char *)memchr(p, ';', (STRLEN)(stop - p));
        const char *tend = semi ? semi : stop;
        const char *t = p;
        while (t < tend && isSPACE(*t)) t++;
        while (tend > t && isSPACE(tend[-1])) tend--;
        if ((STRLEN)(tend - t) == 9 && strnEQ(t, "text/html", 9)) {
            double q = 1.0;
            if (semi) {
                const char *s = semi;
                while (s < stop) {
                    while (s < stop && (*s == ';' || isSPACE(*s))) s++;
                    if (s + 1 < stop && (s[0] == 'q' || s[0] == 'Q')) {
                        const char *eq = s + 1;
                        while (eq < stop && isSPACE(*eq)) eq++;
                        if (eq < stop && *eq == '=')
                            q = Atof(eq + 1);
                    }
                    while (s < stop && *s != ';') s++;
                }
            }
            wants = q > 0 ? 1 : 0;
            break;
        }
        p = comma ? comma + 1 : end;
    }
    return wants;
}

XS_INTERNAL(paz_h_deny);
XS_INTERNAL(paz_h_deny)
{
    dXSARGS;
    SV *c, *why = NULL, *msg, *out;
    HV *stash;
    IV status = 0;
    int had_subject = 0;

    if (items < 1) croak(PAZ_WHO ": deny is a context method");
    c = ST(0);
    if (items > 1 && SvOK(ST(1))) why = ST(1);

    stash = pau_stash_of(aTHX_ c);
    if (stash) {
        SV **w = hv_fetch(stash, PAZ_WHY, (I32)strlen(PAZ_WHY), 0);
        SV **s = hv_fetch(stash, PAZ_SUBJECT, (I32)strlen(PAZ_SUBJECT), 0);
        if (w && *w && SvOK(*w)) status = SvIV(*w);
        if (s && *s && SvOK(*s)) had_subject = SvTRUE(*s) ? 1 : 0;
        (void)hv_delete(stash, PAZ_WHY, (I32)strlen(PAZ_WHY), G_DISCARD);
        (void)hv_delete(stash, PAZ_SUBJECT, (I32)strlen(PAZ_SUBJECT), G_DISCARD);
    }
    if (!status) status = had_subject ? 404 : 403;

    if (status == 404 && !why) {
        out = pau_call(aTHX_ c, "not_found", NULL, 0);
        ST(0) = sv_2mortal(out);
        XSRETURN(1);
    }

    msg = why ? sv_2mortal(newSVsv(why))
              : sv_2mortal(newSVpv(status == 404 ? "Not Found" : "Forbidden", 0));

    if (paz_wants_html(aTHX_ c)) {
        SV *body = sv_2mortal(newSVpvs("<!doctype html>\n<title>"));
        SV *argv[2];
        STRLEN ml;
        const char *mp = SvPV_const(msg, ml);
        STRLEN i;
        sv_catpvf(body, "%" IVdf "</title>\n<h1>%" IVdf "</h1>\n<p>", status, status);
        for (i = 0; i < ml; i++) {          /* the message is the caller's text */
            if      (mp[i] == '&') sv_catpvs(body, "&amp;");
            else if (mp[i] == '<') sv_catpvs(body, "&lt;");
            else if (mp[i] == '>') sv_catpvs(body, "&gt;");
            else sv_catpvn(body, mp + i, 1);
        }
        sv_catpvs(body, "</p>\n");
        argv[0] = body;
        argv[1] = sv_2mortal(newSViv(status));
        out = pau_call(aTHX_ c, "html", argv, 2);
    }
    else {
        HV *err = newHV();
        AV *errs = newAV();
        SV *argv[2];
        (void)hv_stores(err, "message", newSVsv(msg));
        av_push(errs, newRV_noinc((SV *)err));
        {
            HV *body = newHV();
            (void)hv_stores(body, "errors", newRV_noinc((SV *)errs));
            argv[0] = sv_2mortal(newRV_noinc((SV *)body));
        }
        argv[1] = sv_2mortal(newSViv(status));
        out = pau_call(aTHX_ c, "json", argv, 2);
    }
    ST(0) = sv_2mortal(out);
    XSRETURN(1);
}

/* ---- rank_at_least ---------------------------------------------------------------
 *
 * The roles come from the `auth` keyword's own hook - the same answer
 * auth_guard acts on - or from $c->stash->{auth}{roles} when a guard has
 * already loaded them. A name that is not on the ladder croaks: a typo here
 * is the same bug as a typo in an action name.
 */
static AV *paz_roles_of(pTHX_ SV *c, HV *cfg)
{
    AV *out = (AV *)sv_2mortal((SV *)newAV());
    HV *stash = pau_stash_of(aTHX_ c);
    SV *hook, *user, *roles;
    SV *argv[2];

    if (stash) {
        SV **a = hv_fetchs(stash, "auth", 0);
        if (a && *a && pau_is_hash(*a)) {
            SV *r = pau_hget(aTHX_ (HV *)SvRV(*a), "roles");
            if (pau_is_array(r)) {
                AV *have = (AV *)SvRV(r);
                SSize_t i, n = av_len(have) + 1;
                for (i = 0; i < n; i++) {
                    SV **e = av_fetch(have, i, 0);
                    if (e && *e && SvOK(*e)) av_push(out, newSVsv(*e));
                }
                return out;
            }
        }
    }

    hook = pau_hget(aTHX_ cfg, "roles");
    if (!(hook && SvROK(hook) && SvTYPE(SvRV(hook)) == SVt_PVCV)) return out;
    user = sv_2mortal(pau_call(aTHX_ c, "current_user", NULL, 0));
    if (!(user && SvOK(user))) return out;

    argv[0] = c;
    argv[1] = user;
    {   /* the hook may return one name, a list, or an arrayref */
        dSP;
        int count, i;
        ENTER; SAVETMPS;
        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(argv[0]); PUSHs(argv[1]);
        PUTBACK;
        count = call_sv(hook, G_LIST);
        SPAGAIN;
        for (i = 0; i < count; i++) {
            SV *v = SP[i - count + 1];
            if (!(v && SvOK(v))) continue;
            if (pau_is_array(v)) {
                AV *av = (AV *)SvRV(v);
                SSize_t j, n = av_len(av) + 1;
                for (j = 0; j < n; j++) {
                    SV **e = av_fetch(av, j, 0);
                    if (e && *e && SvOK(*e)) av_push(out, newSVsv(*e));
                }
            }
            else av_push(out, newSVsv(v));
        }
        SP -= count;
        PUTBACK;
        FREETMPS; LEAVE;
    }
    roles = NULL;
    PERL_UNUSED_VAR(roles);
    return out;
}

XS_INTERNAL(paz_h_rank);
XS_INTERNAL(paz_h_rank)
{
    dXSARGS;
    HV *cfg = pau_cfg_of(aTHX_ cv);
    SV *ladder_sv = pau_hget(aTHX_ cfg, "rank");
    AV *ladder = pau_is_array(ladder_sv) ? (AV *)SvRV(ladder_sv) : NULL;
    SSize_t n = ladder ? av_len(ladder) + 1 : 0, i, want = -1;
    AV *roles;
    SSize_t rn, j;
    int ok = 0;

    if (items < 2 || !SvOK(ST(1)))
        croak(PAZ_WHO ": rank_at_least needs a role name");

    for (i = 0; i < n; i++) {
        SV **e = av_fetch(ladder, i, 0);
        if (e && *e && sv_eq(*e, ST(1))) { want = i; break; }
    }
    if (want < 0) {
        SV *have = sv_2mortal(newSVpvs(""));
        for (i = 0; i < n; i++) {
            if (i) sv_catpvs(have, ", ");
            sv_catsv(have, *av_fetch(ladder, i, 0));
        }
        croak(PAZ_WHO ": '%s' is not on the rank ladder (%s)",
              SvPV_nolen(ST(1)),
              n ? SvPV_nolen(have)
                : "none declared - `auth rank => [...]`, or rank => [...] on "
                  "the plugin");
    }

    roles = paz_roles_of(aTHX_ ST(0), cfg);
    rn = av_len(roles) + 1;
    for (j = 0; j < rn && !ok; j++) {
        SV **r = av_fetch(roles, j, 0);
        if (!(r && *r && SvOK(*r))) continue;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(ladder, i, 0);
            if (e && *e && sv_eq(*e, *r)) { if (i >= want) ok = 1; break; }
        }
    }
    ST(0) = sv_2mortal(newSViv(ok));
    XSRETURN(1);
}

/* ---- grants -----------------------------------------------------------------------
 *
 * Off unless asked for. Ownership belongs in a rule; a grant is what one user
 * hands another, and it is data. Every `granted` is one indexed lookup, per
 * call, uncached - a revoked grant has to stop working at once.
 */
static SV *paz_grant_filter(pTHX_ HV *cfg, SV *who, SV *action, SV *object)
{
    HV *f_sv = (HV *)SvRV(pau_hget(aTHX_ cfg, "fields"));
    HV *filter = newHV();
    SV *obj = sv_2mortal(newSVsv(object));
    sv_2pv_flags(obj, 0, SV_GMAGIC);           /* the column is text */
    (void)hv_store_ent(filter, pau_hget(aTHX_ f_sv, "subject"), newSVsv(who), 0);
    (void)hv_store_ent(filter, pau_hget(aTHX_ f_sv, "action"), newSVsv(action), 0);
    (void)hv_store_ent(filter, pau_hget(aTHX_ f_sv, "object"),
                       newSVpv(SvPV_nolen(obj), 0), 0);
    return newRV_noinc((SV *)filter);
}

/* the first page of rows matching (subject, action, object) */
static SV *paz_grant_rows(pTHX_ SV *c, HV *cfg, SV *who, SV *action,
                          SV *object, IV limit)
{
    SV *model = sv_2mortal(pau_model_of(aTHX_ cfg));
    HV *opts = newHV();
    SV *argv[2], *page;
    argv[0] = sv_2mortal(paz_grant_filter(aTHX_ cfg, who, action, object));
    (void)hv_stores(opts, "limit", newSViv(limit));
    argv[1] = sv_2mortal(newRV_noinc((SV *)opts));
    page = pau_call(aTHX_ model, "search", argv, 2);
    return sv_2mortal(pau_await(aTHX_ c, sv_2mortal(page)));
}

static SSize_t paz_row_count(pTHX_ SV *page)
{
    SV *rows;
    if (!pau_is_hash(page)) return 0;
    rows = pau_hget(aTHX_ (HV *)SvRV(page), "rows");
    if (!pau_is_array(rows)) return 0;
    return av_len((AV *)SvRV(rows)) + 1;
}

XS_INTERNAL(paz_h_granted);
XS_INTERNAL(paz_h_granted)
{
    dXSARGS;
    HV *cfg = pau_cfg_of(aTHX_ cv);
    SV *c, *who = NULL, *page;
    int i;

    if (items < 3) croak(PAZ_WHO ": granted needs an action and an object");
    c = ST(0);
    for (i = 3; i + 1 < items; i += 2)
        if (strEQ(SvPV_nolen(ST(i)), "to")) who = ST(i + 1);
    if (!who) who = sv_2mortal(pau_call(aTHX_ c, "auth_id", NULL, 0));
    if (!(who && SvOK(who)) || !SvOK(ST(1)) || !SvOK(ST(2))) {
        ST(0) = sv_2mortal(newSViv(0));
        XSRETURN(1);
    }
    page = paz_grant_rows(aTHX_ c, cfg, who, ST(1), ST(2), 1);
    ST(0) = sv_2mortal(newSViv(paz_row_count(aTHX_ page) ? 1 : 0));
    XSRETURN(1);
}

XS_INTERNAL(paz_h_grant);
XS_INTERNAL(paz_h_grant)
{
    dXSARGS;
    HV *cfg = pau_cfg_of(aTHX_ cv);
    SV *c, *to = NULL, *page, *model, *row, *argv[1];
    HV *data;
    HV *f_sv;
    int i;

    if (items < 3) croak(PAZ_WHO ": grant needs an action and an object");
    c = ST(0);
    for (i = 3; i + 1 < items; i += 2)
        if (strEQ(SvPV_nolen(ST(i)), "to")) to = ST(i + 1);
    if (!(to && SvOK(to)))
        croak(PAZ_WHO ": grant needs to => $user_id");

    page = paz_grant_rows(aTHX_ c, cfg, to, ST(1), ST(2), 1);
    if (paz_row_count(aTHX_ page)) {          /* granting twice is one row */
        ST(0) = sv_2mortal(newSViv(1));
        XSRETURN(1);
    }

    f_sv = (HV *)SvRV(pau_hget(aTHX_ cfg, "fields"));
    data = (HV *)SvRV(sv_2mortal(paz_grant_filter(aTHX_ cfg, to, ST(1), ST(2))));
    (void)hv_store_ent(data, pau_hget(aTHX_ f_sv, "granted_by"),
                       pau_call(aTHX_ c, "auth_id", NULL, 0), 0);
    (void)hv_store_ent(data, pau_hget(aTHX_ f_sv, "created"),
                       newSViv((IV)time(NULL)), 0);

    model = sv_2mortal(pau_model_of(aTHX_ cfg));
    argv[0] = sv_2mortal(newRV_inc((SV *)data));
    row = sv_2mortal(pau_call(aTHX_ model, "create", argv, 1));
    /* mortal, not mortal-AND-decremented: await hands back its own reference
     * and the mortal stack releases it once */
    (void)sv_2mortal(pau_await(aTHX_ c, row));
    ST(0) = sv_2mortal(newSViv(1));
    XSRETURN(1);
}

XS_INTERNAL(paz_h_revoke);
XS_INTERNAL(paz_h_revoke)
{
    dXSARGS;
    HV *cfg = pau_cfg_of(aTHX_ cv);
    SV *c, *from = NULL, *page, *model, *rows_sv;
    AV *rows;
    SSize_t i, n;
    IV gone = 0;

    if (items < 3) croak(PAZ_WHO ": revoke_grant needs an action and an object");
    c = ST(0);
    for (i = 3; i + 1 < items; i += 2)
        if (strEQ(SvPV_nolen(ST(i)), "from")) from = ST(i + 1);
    if (!(from && SvOK(from)))
        croak(PAZ_WHO ": revoke_grant needs from => $user_id");

    page = paz_grant_rows(aTHX_ c, cfg, from, ST(1), ST(2), 50);
    if (!pau_is_hash(page)) { ST(0) = sv_2mortal(newSViv(0)); XSRETURN(1); }
    rows_sv = pau_hget(aTHX_ (HV *)SvRV(page), "rows");
    if (!pau_is_array(rows_sv)) { ST(0) = sv_2mortal(newSViv(0)); XSRETURN(1); }
    rows = (AV *)SvRV(rows_sv);
    n = av_len(rows) + 1;
    model = sv_2mortal(pau_model_of(aTHX_ cfg));
    for (i = 0; i < n; i++) {
        SV **e = av_fetch(rows, i, 0);
        SV *id, *argv[2], *r;
        if (!(e && *e && pau_is_hash(*e))) continue;
        id = pau_hget(aTHX_ (HV *)SvRV(*e), "id");
        if (!(id && SvOK(id))) continue;
        argv[0] = sv_2mortal(newSVpvs("id"));
        argv[1] = id;
        r = sv_2mortal(pau_call(aTHX_ model, "delete", argv, 2));
        (void)sv_2mortal(pau_await(aTHX_ c, r));
        gone++;
    }
    ST(0) = sv_2mortal(newSViv(gone));
    XSRETURN(1);
}

#endif /* PAU_AUTHZ_H */
