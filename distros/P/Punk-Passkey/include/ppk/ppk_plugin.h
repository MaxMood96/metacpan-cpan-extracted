/* ppk_plugin.h - `plugin 'Passkey'`: the keyword, the routes it mounts
 * and the pages they answer with.
 *
 * Everything below this file is the protocol, which knows nothing about
 * routes, storage or users. This file is where it meets an application:
 * it decides where the endpoints live, which model holds the
 * credentials, who the current user is, and what the management page
 * looks like when the application has not said.
 *
 * The division matters because the protocol is the part that must not
 * be worked around. An application with an unusual flow calls
 * Punk::Passkey::register/verify directly and gets every check; what it
 * gives up is only the routing and the default page.
 *
 * ---- what is checked at boot ------------------------------------------
 *
 * A passkey ceremony cannot run without a session (the challenge has to
 * outlive the response that issued it) or without `host` (the rpId and
 * the origin check are configuration, never the request). Both are
 * checked at to_app through on_compile - after every keyword has
 * recorded, so declaration order cannot matter - and both croak naming
 * what to add. 3am is the wrong time to learn that the origin check was
 * never configured.
 *
 * Include after ppk_auth.h.
 */

#ifndef PPK_PLUGIN_H
#define PPK_PLUGIN_H

/* ---- closures over the frozen configuration ------------------------------- */

typedef struct { AV *cap; } ppk_clos_t;

static int ppk_clos_free(pTHX_ SV *sv, MAGIC *mg) {
    ppk_clos_t *c = (ppk_clos_t *)mg->mg_ptr;
    PERL_UNUSED_ARG(sv);
    if (c) {
        if (c->cap) SvREFCNT_dec((SV *)c->cap);
        Safefree(c);
    }
    return 0;
}
static MGVTBL ppk_clos_vtbl = { NULL, NULL, NULL, NULL, ppk_clos_free,
                                NULL, NULL, NULL };

static SV *ppk_closure(pTHX_ XSUBADDR_t body, HV *cfg) {
    CV *cv = (CV *)newXS(NULL, body, (char *)__FILE__);
    AV *cap = newAV();
    ppk_clos_t *c;
    av_push(cap, newRV_inc((SV *)cfg));
    Newxz(c, 1, ppk_clos_t);
    c->cap = cap;
    sv_magicext((SV *)cv, NULL, PERL_MAGIC_ext, &ppk_clos_vtbl, (char *)c, 0);
    return newRV_noinc((SV *)cv);
}

static HV *ppk_cfg_of(pTHX_ CV *cv) {
    MAGIC *mg = mg_findext((SV *)cv, PERL_MAGIC_ext, &ppk_clos_vtbl);
    AV *cap = mg ? ((ppk_clos_t *)mg->mg_ptr)->cap : NULL;
    SV **e = cap ? av_fetch(cap, 0, 0) : NULL;
    if (!(e && *e && SvROK(*e) && SvTYPE(SvRV(*e)) == SVt_PVHV))
        croak("Punk::Plugin::Passkey: a closure lost its configuration");
    return (HV *)SvRV(*e);
}

/* A closure that also carries the CONTEXT it was made for.
 *
 * The two model-backed callbacks the login ceremony takes need both the
 * frozen configuration and the request they are serving. The context
 * cannot go in the configuration: that hash is built once at boot and
 * shared by every worker and every request, so a context left in it
 * would be one request's context answering another's - which under a
 * prefork server is not a race that shows up in testing, it is a
 * wrong answer that shows up in production. So these closures are
 * built per request and freed with it. */
static SV *ppk_closure_ctx(pTHX_ XSUBADDR_t body, HV *cfg, SV *ctx) {
    CV *cv = (CV *)newXS(NULL, body, (char *)__FILE__);
    AV *cap = newAV();
    ppk_clos_t *c;
    av_push(cap, newRV_inc((SV *)cfg));
    av_push(cap, newSVsv(ctx));
    Newxz(c, 1, ppk_clos_t);
    c->cap = cap;
    sv_magicext((SV *)cv, NULL, PERL_MAGIC_ext, &ppk_clos_vtbl, (char *)c, 0);
    return newRV_noinc((SV *)cv);
}

static SV *ppk_ctx_of(pTHX_ CV *cv) {
    MAGIC *mg = mg_findext((SV *)cv, PERL_MAGIC_ext, &ppk_clos_vtbl);
    AV *cap = mg ? ((ppk_clos_t *)mg->mg_ptr)->cap : NULL;
    SV **e = cap ? av_fetch(cap, 1, 0) : NULL;
    return (e && *e && SvROK(*e)) ? *e : NULL;
}

static HV *PPK_STATE = NULL;

/* ---- small helpers -------------------------------------------------------- */

static SV *ppk_cfg_sv(pTHX_ HV *cfg, const char *k) {
    SV **e = hv_fetch(cfg, k, (I32)strlen(k), 0);
    return (e && *e) ? *e : &PL_sv_undef;
}
static SV *ppk_cfg_code(pTHX_ HV *cfg, const char *k) {
    SV **e = hv_fetch(cfg, k, (I32)strlen(k), 0);
    return (e && *e && SvROK(*e) && SvTYPE(SvRV(*e)) == SVt_PVCV) ? *e : NULL;
}

/* a method call on the app or context that may not exist */
static int ppk_can(pTHX_ SV *obj, const char *meth) {
    SV *m = sv_2mortal(newSVpv(meth, 0));
    SV *r = sv_2mortal(ppk_call(aTHX_ obj, "can", &m, 1));
    return (r && SvTRUE(r)) ? 1 : 0;
}

static void ppk_helper(pTHX_ SV *app, const char *name, XSUBADDR_t body,
                       HV *cfg) {
    SV *argv[2];
    argv[0] = sv_2mortal(newSVpv(name, 0));
    argv[1] = sv_2mortal(ppk_closure(aTHX_ body, cfg));
    SvREFCNT_dec(ppk_call(aTHX_ app, "helper", argv, 2));
}

static void ppk_route(pTHX_ SV *app, const char *method, SV *path,
                      XSUBADDR_t body, HV *cfg) {
    SV *argv[3];
    argv[0] = sv_2mortal(newSVpv(method, 0));
    argv[1] = path;
    argv[2] = sv_2mortal(ppk_closure(aTHX_ body, cfg));
    SvREFCNT_dec(ppk_call(aTHX_ app, "route", argv, 3));
}

/* The current user, as the application defines one: the `user_id`
 * option when given, else $c->auth_id from the auth battery. Undef
 * means nobody is logged in, and the management routes answer 401
 * rather than guessing. */
static SV *ppk_user_id(pTHX_ HV *cfg, SV *c) {
    SV *code = ppk_cfg_code(aTHX_ cfg, "user_id");
    if (code) {
        SV *argv[1];
        argv[0] = c;
        return sv_2mortal(ppk_call_cb(aTHX_ code, argv, 1, NULL));
    }
    if (ppk_can(aTHX_ c, "auth_id"))
        return sv_2mortal(ppk_call(aTHX_ c, "auth_id", NULL, 0));
    return &PL_sv_undef;
}

static SV *ppk_model(pTHX_ HV *cfg, SV *c) {
    SV *name = ppk_cfg_sv(aTHX_ cfg, "model");
    return sv_2mortal(ppk_call(aTHX_ c, "model", &name, 1));
}

/* $c->json($data, $status) */
static SV *ppk_json(pTHX_ SV *c, SV *data, IV status) {
    SV *argv[2];
    argv[0] = data;
    argv[1] = sv_2mortal(newSViv(status));
    return ppk_call(aTHX_ c, "json", argv, status ? 2 : 1);
}

static SV *ppk_json_err(pTHX_ SV *c, const char *msg, IV status) {
    HV *h = newHV();
    (void)hv_stores(h, "error", newSVpv(msg, 0));
    return ppk_json(aTHX_ c, sv_2mortal(newRV_noinc((SV *)h)), status);
}

/* ---- the JS the pages load ------------------------------------------------
 *
 * Served from a route rather than shipped as a file, so it cannot go
 * missing, cannot be served by something else, and can carry a strong
 * ETag computed from the bytes themselves.
 *
 * It references NO external origin - no CDN, no framework, no build
 * step. That is a requirement rather than a preference: an application
 * with a Content-Security-Policy should not have to widen it to let
 * its login page work, and a login page is the last place to invite a
 * third party in.
 */
static const char PPK_JS[] =
"(function (w) {\n"
"  'use strict';\n"
"  function b64uToBuf(s) {\n"
"    s = s.replace(/-/g, '+').replace(/_/g, '/');\n"
"    while (s.length % 4) s += '=';\n"
"    var raw = atob(s), a = new Uint8Array(raw.length), i;\n"
"    for (i = 0; i < raw.length; i++) a[i] = raw.charCodeAt(i);\n"
"    return a.buffer;\n"
"  }\n"
"  function bufToB64u(b) {\n"
"    var a = new Uint8Array(b), s = '', i;\n"
"    for (i = 0; i < a.length; i++) s += String.fromCharCode(a[i]);\n"
"    return btoa(s).replace(/\\+/g, '-').replace(/\\//g, '_')\n"
"                  .replace(/=+$/, '');\n"
"  }\n"
"  function post(url, body) {\n"
"    var h = { 'Content-Type': 'application/json' };\n"
"    var t = w.PunkPasskey.csrfToken();\n"
"    if (t) h[w.PunkPasskey.csrfHeader] = t;\n"
"    return fetch(url, {\n"
"      method: 'POST', headers: h, credentials: 'same-origin',\n"
"      body: JSON.stringify(body || {})\n"
"    }).then(function (r) {\n"
"      return r.json().then(function (j) {\n"
"        if (!r.ok) throw new Error(j && j.error ? j.error : 'request failed');\n"
"        return j;\n"
"      });\n"
"    });\n"
"  }\n"
"  var pending = null;   /* the outstanding conditional request */\n"
"  var PP = {\n"
"    csrfHeader: 'X-CSRF-Token',\n"
"    csrfToken: function () {\n"
"      var m = document.cookie.match(/(?:^|;\\s*)csrf=([^;]*)/);\n"
"      return m ? decodeURIComponent(m[1]) : null;\n"
"    },\n"
"    supported: function () {\n"
"      return !!(w.PublicKeyCredential && w.navigator.credentials);\n"
"    },\n"
"    register: function (base) {\n"
"      return post(base + '/options').then(function (o) {\n"
"        o.challenge = b64uToBuf(o.challenge);\n"
"        o.user.id   = b64uToBuf(o.user.id);\n"
"        (o.excludeCredentials || []).forEach(function (c) {\n"
"          c.id = b64uToBuf(c.id);\n"
"        });\n"
"        return navigator.credentials.create({ publicKey: o });\n"
"      }).then(function (cred) {\n"
"        return post(base, {\n"
"          id: cred.id,\n"
"          clientDataJSON: bufToB64u(cred.response.clientDataJSON),\n"
"          attestationObject: bufToB64u(cred.response.attestationObject),\n"
"          transports: cred.response.getTransports\n"
"            ? cred.response.getTransports() : null\n"
"        });\n"
"      });\n"
"    },\n"
"    login: function (base, opts) {\n"
"      opts = opts || {};\n"
"      /* A browser allows ONE outstanding credential request. The\n"
"         autofill flow leaves one pending from page load, so a button\n"
"         press has to cancel it first - otherwise the second call is\n"
"         refused outright, and the challenge this one is about to mint\n"
"         would replace the pending request's in the session anyway. */\n"
"      if (!opts.conditional && pending) {\n"
"        try { pending.abort(); } catch (e) {}\n"
"        pending = null;\n"
"      }\n"
"      var ctl = w.AbortController ? new w.AbortController() : null;\n"
"      if (opts.conditional) pending = ctl;\n"
"      return post(base + '/options', { username: opts.username })\n"
"        .then(function (o) {\n"
"          o.challenge = b64uToBuf(o.challenge);\n"
"          (o.allowCredentials || []).forEach(function (c) {\n"
"            c.id = b64uToBuf(c.id);\n"
"          });\n"
"          var req = { publicKey: o };\n"
"          if (ctl) req.signal = ctl.signal;\n"
"          if (opts.conditional) req.mediation = 'conditional';\n"
"          return navigator.credentials.get(req);\n"
"        }).then(function (a) {\n"
"          if (pending === ctl) pending = null;\n"
"          return post(base, {\n"
"            id: a.id,\n"
"            clientDataJSON: bufToB64u(a.response.clientDataJSON),\n"
"            authenticatorData: bufToB64u(a.response.authenticatorData),\n"
"            signature: bufToB64u(a.response.signature),\n"
"            userHandle: a.response.userHandle\n"
"              ? bufToB64u(a.response.userHandle) : null\n"
"          });\n"
"        });\n"
"    },\n"
"    /* Conditional UI - the autofill flow. Feature-detected and\n"
"       silent where it is unsupported, which is most of the point:\n"
"       a browser without it simply shows the button instead. */\n"
"    conditional: function (base, onOk) {\n"
"      if (!w.PublicKeyCredential ||\n"
"          !w.PublicKeyCredential.isConditionalMediationAvailable)\n"
"        return;\n"
"      /* Without an AbortController this request could never be\n"
"         cancelled, and it would then block every button press on the\n"
"         page for as long as it waited. A browser too old for\n"
"         AbortController gets the button and no autofill, which works;\n"
"         the other way round does not. */\n"
"      if (!w.AbortController) return;\n"
"      w.PublicKeyCredential.isConditionalMediationAvailable()\n"
"        .then(function (ok) {\n"
"          if (!ok) return;\n"
"          PP.login(base, { conditional: true }).then(onOk, function () {\n"
"            /* aborted by a button press, or dismissed. Either way the\n"
"               request is over and must not be left marked pending, or\n"
"               the next button press would try to abort a dead one. */\n"
"            pending = null;\n"
"          });\n"
"        }, function () {});\n"
"    }\n"
"  };\n"
"  w.PunkPasskey = PP;\n"
"})(window);\n";

/* the ETag, computed once at boot from the bytes above */
static SV *PPK_JS_ETAG = NULL;

static void ppk_js_boot(pTHX) {
    const jws_abi *J = ppk_jws(aTHX);
    SV *sum;
    if (PPK_JS_ETAG) return;
    sum = J->sha256(aTHX_ (const unsigned char *)PPK_JS, sizeof(PPK_JS) - 1);
    if (!sum) return;
    PPK_JS_ETAG = newSVpvs("\"");
    {
        SV *b64 = J->b64url(aTHX_ (const unsigned char *)SvPVX(sum),
                            SvCUR(sum) > 16 ? 16 : SvCUR(sum));
        if (b64) { sv_catsv(PPK_JS_ETAG, b64); SvREFCNT_dec(b64); }
    }
    sv_catpvs(PPK_JS_ETAG, "\"");
    SvREFCNT_dec(sum);
}

/* A triplet built here rather than $c->text, because $c->text stamps
 * its own text/plain over anything already set - and this is the one
 * response in the plugin whose content type is the point. */
static SV *ppk_triplet(pTHX_ IV status, const char *type, SV *body) {
    AV *r = newAV(), *h = newAV(), *b = newAV();
    av_push(h, newSVpvs("Content-Type"));
    av_push(h, newSVpv(type, 0));
    if (PPK_JS_ETAG) {
        av_push(h, newSVpvs("ETag"));
        av_push(h, newSVsv(PPK_JS_ETAG));
    }
    /* `no-cache` means STORE IT BUT REVALIDATE, which is not the same
     * as `no-store` and is the right answer here.
     *
     * The obvious choice is a long max-age, and it is wrong: this URL
     * is stable across versions, so a browser told to keep the file for
     * an hour will not even ask during that hour - and an upgrade that
     * fixes the sign-in script reaches nobody until their cache
     * expires. That is not hypothetical; it is how the fix for the
     * conditional-UI abort failed to reach a user who had already
     * loaded the page once.
     *
     * Revalidating costs one conditional request that answers 304 with
     * no body, because the ETag above is derived from the bytes. For
     * the script that logs people in, that is a trade worth making
     * every time. */
    av_push(h, newSVpvs("Cache-Control"));
    av_push(h, newSVpvs("no-cache"));
    av_push(b, body ? newSVsv(body) : newSVpvs(""));
    av_push(r, newSViv(status));
    av_push(r, newRV_noinc((SV *)h));
    av_push(r, newRV_noinc((SV *)b));
    return newRV_noinc((SV *)r);
}

XS_INTERNAL(ppk_r_js);
XS_INTERNAL(ppk_r_js) {
    dXSARGS;
    SV *c, *body;
    if (items < 1) XSRETURN_EMPTY;
    c = ST(0);
    /* a matching If-None-Match is a 304: the asset never changes for a
     * given build, so a browser should ask once */
    {
        SV *inm = sv_2mortal(ppk_call(aTHX_ c, "req", NULL, 0));
        if (inm && SvROK(inm) && PPK_JS_ETAG) {
            SV *hn = sv_2mortal(newSVpvs("If-None-Match"));
            SV *got = sv_2mortal(ppk_call(aTHX_ inm, "header", &hn, 1));
            if (got && SvOK(got) && sv_eq(got, PPK_JS_ETAG)) {
                ST(0) = sv_2mortal(ppk_triplet(aTHX_ 304,
                            "application/javascript; charset=utf-8", NULL));
                XSRETURN(1);
            }
        }
    }
    body = sv_2mortal(newSVpvn(PPK_JS, sizeof(PPK_JS) - 1));
    ST(0) = sv_2mortal(ppk_triplet(aTHX_ 200,
                "application/javascript; charset=utf-8", body));
    XSRETURN(1);
}

/* ---- the management page --------------------------------------------------
 *
 * `render` is the override, and it is the same shape Punk::Plugin::TOTP
 * uses: a coderef, or the name of a method on the context. An
 * application that wants its own template writes
 *
 *     render => sub { $_[0]->render('account/passkeys', $_[1]) }
 *
 * which is one line and needs no agreement between this distribution
 * and the application about where templates live or which engine
 * renders them. A plugin that shipped .tmpl files would require every
 * application using it to have a view engine configured - including
 * the JSON API that only wants the login endpoint.
 */
static SV *ppk_render_manage(pTHX_ HV *cfg, SV *c, SV *rows) {
    SV *r = ppk_cfg_sv(aTHX_ cfg, "render");
    if (SvOK(r)) {
        if (SvROK(r) && SvTYPE(SvRV(r)) == SVt_PVCV) {
            SV *argv[2];
            argv[0] = c;
            argv[1] = rows;
            return ppk_call_cb(aTHX_ r, argv, 2, NULL);
        }
        return ppk_call(aTHX_ c, SvPV_nolen(r), &rows, 1);
    }
    {
        SV *html = sv_2mortal(newSVpvs(
            "<!doctype html><meta charset=\"utf-8\">\n"
            "<title>Passkeys</title>\n<h1>Your passkeys</h1>\n"));
        AV *av = (rows && SvROK(rows) && SvTYPE(SvRV(rows)) == SVt_PVAV)
               ? (AV *)SvRV(rows) : NULL;
        SSize_t i, n = av ? av_len(av) + 1 : 0;
        if (!n) {
            sv_catpvs(html, "<p>You have no passkeys yet.</p>\n");
        }
        else {
            sv_catpvs(html, "<ul>\n");
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *row;
                SV *lab;
                if (!(e && *e && SvROK(*e) && SvTYPE(SvRV(*e)) == SVt_PVHV))
                    continue;
                row = (HV *)SvRV(*e);
                lab = ppk_hv_get(aTHX_ row, "label");
                sv_catpvs(html, "<li>");
                {   /* the label is the user's own text and is escaped;
                     * everything else on this page is generated */
                    STRLEN ll;
                    const char *lp = lab ? SvPV_const(lab, ll)
                                         : "a passkey";
                    STRLEN k;
                    if (!lab) ll = 9;
                    for (k = 0; k < ll; k++) {
                        char ch = lp[k];
                        if      (ch == '&')  sv_catpvs(html, "&amp;");
                        else if (ch == '<')  sv_catpvs(html, "&lt;");
                        else if (ch == '>')  sv_catpvs(html, "&gt;");
                        else if (ch == '"')  sv_catpvs(html, "&quot;");
                        else if (ch == '\'') sv_catpvs(html, "&#39;");
                        else sv_catpvn(html, &ch, 1);
                    }
                }
                sv_catpvs(html, "</li>\n");
            }
            sv_catpvs(html, "</ul>\n");
        }
        sv_catpvs(html, "<button id=\"punk-passkey-add\">Add a passkey</button>\n");
        sv_catpvs(html, "<script src=\"");
        sv_catsv(html, ppk_cfg_sv(aTHX_ cfg, "asset_path"));
        sv_catpvs(html, "\"></script>\n<script>\n"
            "document.getElementById('punk-passkey-add')"
            ".addEventListener('click', function () {\n"
            "  PunkPasskey.register(");
        sv_catpvs(html, "'");
        sv_catsv(html, ppk_cfg_sv(aTHX_ cfg, "register_path"));
        sv_catpvs(html, "').then(function () { location.reload() },\n"
            "    function (e) { alert(e.message) });\n"
            "});\n</script>\n");
        /* a page listing one person's devices is not a page a shared
         * cache should keep */
        {
            SV *argv[2];
            argv[0] = sv_2mortal(newSVpvs("Cache-Control"));
            argv[1] = sv_2mortal(newSVpvs("private, no-store"));
            SvREFCNT_dec(ppk_call(aTHX_ c, "header", argv, 2));
        }
        return ppk_call(aTHX_ c, "html", &html, 1);
    }
}

/* ---- the routes ----------------------------------------------------------- */

/* GET register_path - the management page */
XS_INTERNAL(ppk_r_manage);
XS_INTERNAL(ppk_r_manage) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    SV *c, *uid, *model, *page, *rows = NULL;
    if (items < 1) XSRETURN_EMPTY;
    c = ST(0);
    uid = ppk_user_id(aTHX_ cfg, c);
    if (!(uid && SvOK(uid))) {
        ST(0) = sv_2mortal(ppk_json_err(aTHX_ c, "not signed in", 401));
        XSRETURN(1);
    }
    model = ppk_model(aTHX_ cfg, c);
    if (model && SvROK(model)) {
        HV *filter = newHV();
        SV *argv[1];
        SV *page_sv;
        (void)hv_stores(filter, "user_id", newSVsv(uid));
        argv[0] = sv_2mortal(newRV_noinc((SV *)filter));
        page_sv = sv_2mortal(ppk_call(aTHX_ model, "search", argv, 1));
        if (page_sv && SvROK(page_sv) && SvTYPE(SvRV(page_sv)) == SVt_PVHV) {
            SV *r = ppk_hv_get(aTHX_ (HV *)SvRV(page_sv), "rows");
            if (r) rows = r;
        }
    }
    if (!rows) rows = sv_2mortal(newRV_noinc((SV *)newAV()));
    page = ppk_render_manage(aTHX_ cfg, c, rows);
    ST(0) = page ? sv_2mortal(page) : &PL_sv_undef;
    XSRETURN(1);
}

/* POST register_path/options */
XS_INTERNAL(ppk_r_reg_options);
XS_INTERNAL(ppk_r_reg_options) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    SV *c, *uid, *model, *opts;
    HV *args;
    if (items < 1) XSRETURN_EMPTY;
    c = ST(0);
    uid = ppk_user_id(aTHX_ cfg, c);
    if (!(uid && SvOK(uid))) {
        ST(0) = sv_2mortal(ppk_json_err(aTHX_ c, "not signed in", 401));
        XSRETURN(1);
    }
    args = (HV *)sv_2mortal((SV *)newHV());
    (void)hv_stores(args, "user_id", newSVsv(uid));
    {
        SV *code = ppk_cfg_code(aTHX_ cfg, "user_name");
        if (code) {
            SV *argv[1];
            argv[0] = c;
            (void)hv_stores(args, "user_name",
                            ppk_call_cb(aTHX_ code, argv, 1, NULL));
        }
    }
    (void)hv_stores(args, "user_verification",
                    newSVsv(ppk_cfg_sv(aTHX_ cfg, "user_verification")));
    /* the ids this user already has, so the platform refuses a repeat
     * registration in its own interface rather than letting it reach
     * the unique constraint */
    model = ppk_model(aTHX_ cfg, c);
    if (model && SvROK(model)) {
        HV *filter = newHV();
        SV *argv[1], *page_sv;
        (void)hv_stores(filter, "user_id", newSVsv(uid));
        argv[0] = sv_2mortal(newRV_noinc((SV *)filter));
        page_sv = sv_2mortal(ppk_call(aTHX_ model, "search", argv, 1));
        if (page_sv && SvROK(page_sv) && SvTYPE(SvRV(page_sv)) == SVt_PVHV) {
            SV *r = ppk_hv_get(aTHX_ (HV *)SvRV(page_sv), "rows");
            AV *ex = newAV();
            if (r && SvROK(r) && SvTYPE(SvRV(r)) == SVt_PVAV) {
                AV *av = (AV *)SvRV(r);
                SSize_t i, n = av_len(av) + 1;
                for (i = 0; i < n; i++) {
                    SV **e = av_fetch(av, i, 0);
                    SV *id;
                    if (!(e && *e && SvROK(*e))) continue;
                    id = ppk_hv_get(aTHX_ (HV *)SvRV(*e), "credential_id");
                    if (id) av_push(ex, newSVsv(id));
                }
            }
            (void)hv_stores(args, "exclude", newRV_noinc((SV *)ex));
        }
    }
    opts = ppk_register_options(aTHX_ c, args);
    ST(0) = sv_2mortal(ppk_json(aTHX_ c, sv_2mortal(opts), 0));
    XSRETURN(1);
}

/* POST register_path */
XS_INTERNAL(ppk_r_register);
XS_INTERNAL(ppk_r_register) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    SV *c, *uid, *body, *cred, *model;
    const char *why = NULL;
    if (items < 1) XSRETURN_EMPTY;
    c = ST(0);
    uid = ppk_user_id(aTHX_ cfg, c);
    if (!(uid && SvOK(uid))) {
        ST(0) = sv_2mortal(ppk_json_err(aTHX_ c, "not signed in", 401));
        XSRETURN(1);
    }
    {
        SV *req = sv_2mortal(ppk_call(aTHX_ c, "req", NULL, 0));
        body = req && SvROK(req)
             ? sv_2mortal(ppk_call(aTHX_ req, "json", NULL, 0)) : NULL;
    }
    if (!ppk_is_hash(body)) {
        ST(0) = sv_2mortal(ppk_json_err(aTHX_ c, "expected a JSON body", 400));
        XSRETURN(1);
    }
    {
        HV *args = (HV *)sv_2mortal((SV *)newHV());
        (void)hv_stores(args, "user_verification",
                        newSVsv(ppk_cfg_sv(aTHX_ cfg, "user_verification")));
        cred = ppk_register(aTHX_ c, (HV *)SvRV(body), args, &why);
    }
    if (!cred) {
        SV *line = sv_2mortal(newSVpvs("passkey registration refused: "));
        sv_catpv(line, (char *)(why ? why : "unknown"));
        ppk_warn(aTHX_ c, SvPVX(line));
        ST(0) = sv_2mortal(ppk_json_err(aTHX_ c, "registration failed", 400));
        XSRETURN(1);
    }
    sv_2mortal(cred);

    model = ppk_model(aTHX_ cfg, c);
    if (model && SvROK(model)) {
        HV *row = newHV();
        HV *ch = (HV *)SvRV(cred);
        SV *argv[1], *made;
        SV *lab;
        (void)hv_stores(row, "user_id", newSVsv(uid));
        (void)hv_stores(row, "credential_id",
                        newSVsv(ppk_hv_get(aTHX_ ch, "credential_id")));
        (void)hv_stores(row, "public_key",
                        newSVsv(ppk_hv_get(aTHX_ ch, "public_key")));
        (void)hv_stores(row, "sign_count",
                        newSVsv(ppk_hv_get(aTHX_ ch, "sign_count")));
        {
            SV *g = ppk_hv_get(aTHX_ ch, "aaguid");
            if (g) (void)hv_stores(row, "aaguid", newSVsv(g));
        }
        (void)hv_stores(row, "created_at", newSViv((IV)time(NULL)));
        /* a label the user typed, if the client sent one */
        lab = ppk_hv_get(aTHX_ (HV *)SvRV(body), "label");
        if (lab) (void)hv_stores(row, "label", newSVsv(lab));
        argv[0] = sv_2mortal(newRV_noinc((SV *)row));
        made = ppk_call(aTHX_ model, "create", argv, 1);
        if (made) sv_2mortal(made);
        /* A create that failed is almost always the unique constraint -
         * this credential is already registered, here or to somebody
         * else - and either way the answer is the same refusal. */
        if (!made || !SvOK(made)) {
            ppk_warn(aTHX_ c, "passkey registration could not be stored "
                              "(already registered?)");
            ST(0) = sv_2mortal(ppk_json_err(aTHX_ c,
                        "that passkey is already registered", 409));
            XSRETURN(1);
        }
    }
    {
        HV *out = newHV();
        (void)hv_stores(out, "ok", newSViv(1));
        (void)hv_stores(out, "credential_id",
            newSVsv(ppk_hv_get(aTHX_ (HV *)SvRV(cred), "credential_id")));
        ST(0) = sv_2mortal(ppk_json(aTHX_ c,
                    sv_2mortal(newRV_noinc((SV *)out)), 0));
    }
    XSRETURN(1);
}

/* DELETE register_path/:id
 *
 * The last means of entry is not removable. A user who deletes their
 * only passkey with no other factor configured has locked themselves
 * out, and discovering that is a support ticket at best. Whether
 * another factor exists is the application's knowledge, so it arrives
 * as a coderef; without one, "no other factor" is assumed, which is
 * the safe direction.
 */
XS_INTERNAL(ppk_r_delete);
XS_INTERNAL(ppk_r_delete) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    SV *c, *uid, *model, *idsv;
    IV count = 0;
    if (items < 1) XSRETURN_EMPTY;
    c = ST(0);
    uid = ppk_user_id(aTHX_ cfg, c);
    if (!(uid && SvOK(uid))) {
        ST(0) = sv_2mortal(ppk_json_err(aTHX_ c, "not signed in", 401));
        XSRETURN(1);
    }
    {
        SV *pname = sv_2mortal(newSVpvs("id"));
        idsv = sv_2mortal(ppk_call(aTHX_ c, "param", &pname, 1));
    }
    if (!(idsv && SvOK(idsv) && SvCUR(idsv))) {
        ST(0) = sv_2mortal(ppk_json_err(aTHX_ c, "no credential named", 400));
        XSRETURN(1);
    }
    model = ppk_model(aTHX_ cfg, c);
    if (!(model && SvROK(model))) {
        ST(0) = sv_2mortal(ppk_json_err(aTHX_ c, "no passkey model", 500));
        XSRETURN(1);
    }
    {   /* how many this user has */
        HV *filter = newHV();
        SV *argv[1], *n;
        (void)hv_stores(filter, "user_id", newSVsv(uid));
        argv[0] = sv_2mortal(newRV_noinc((SV *)filter));
        n = sv_2mortal(ppk_call(aTHX_ model, "count", argv, 1));
        count = (n && SvOK(n)) ? SvIV(n) : 0;
    }
    if (count <= 1) {
        int other = 0;
        SV *code = ppk_cfg_code(aTHX_ cfg, "has_other_factor");
        if (code) {
            SV *argv[2], *r;
            argv[0] = c;
            argv[1] = uid;
            r = sv_2mortal(ppk_call_cb(aTHX_ code, argv, 2, NULL));
            other = (r && SvTRUE(r)) ? 1 : 0;
        }
        if (!other) {
            ST(0) = sv_2mortal(ppk_json_err(aTHX_ c,
                "this is your last passkey and you have no other way to "
                "sign in - add another before removing this one", 409));
            XSRETURN(1);
        }
    }
    {
        SV *argv[4], *r;
        argv[0] = sv_2mortal(newSVpvs("credential_id"));
        argv[1] = idsv;
        argv[2] = sv_2mortal(newSVpvs("user_id"));
        argv[3] = uid;
        /* scoped to the user: a credential id is not a capability, and
         * deleting by id alone would let one account remove another's */
        r = sv_2mortal(ppk_call(aTHX_ model, "delete", argv, 4));
        {
            HV *out = newHV();
            (void)hv_stores(out, "ok", newSViv(r && SvTRUE(r) ? 1 : 0));
            ST(0) = sv_2mortal(ppk_json(aTHX_ c,
                        sv_2mortal(newRV_noinc((SV *)out)), 0));
        }
    }
    XSRETURN(1);
}

/* POST login_path/options */
XS_INTERNAL(ppk_r_login_options);
XS_INTERNAL(ppk_r_login_options) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    SV *c, *opts;
    HV *args;
    if (items < 1) XSRETURN_EMPTY;
    c = ST(0);
    args = (HV *)sv_2mortal((SV *)newHV());
    (void)hv_stores(args, "user_verification",
                    newSVsv(ppk_cfg_sv(aTHX_ cfg, "user_verification")));
    /* A username narrows the credential list, for authenticators that
     * hold no resident credential. It is NOT an existence check: an
     * unknown username produces an empty list and the ceremony fails
     * the same way a wrong one does, so this endpoint does not report
     * who has an account. */
    {
        SV *code = ppk_cfg_code(aTHX_ cfg, "credentials_for");
        SV *body = NULL;
        SV *req = sv_2mortal(ppk_call(aTHX_ c, "req", NULL, 0));
        if (req && SvROK(req))
            body = sv_2mortal(ppk_call(aTHX_ req, "json", NULL, 0));
        if (code && ppk_is_hash(body)) {
            SV *user = ppk_hv_get(aTHX_ (HV *)SvRV(body), "username");
            if (user && SvOK(user) && SvCUR(user)) {
                SV *argv[2], *list;
                argv[0] = c;
                argv[1] = user;
                list = sv_2mortal(ppk_call_cb(aTHX_ code, argv, 2, NULL));
                if (list && SvROK(list) && SvTYPE(SvRV(list)) == SVt_PVAV)
                    (void)hv_stores(args, "allow", newSVsv(list));
            }
        }
    }
    opts = ppk_challenge_options(aTHX_ c, args);
    ST(0) = sv_2mortal(ppk_json(aTHX_ c, sv_2mortal(opts), 0));
    XSRETURN(1);
}

/* The two callbacks the ceremony takes, backed by the configured
 * model. They exist as closures rather than as engine code because
 * the engine owns no storage on purpose - an application with its own
 * table calls Punk::Passkey::verify directly and passes its own.
 *
 * The lookup is scoped by credential id ALONE, deliberately: at login
 * nobody has said who they are yet, and the credential id is what
 * identifies the row. The user id comes back out of it. */
XS_INTERNAL(ppk_cb_lookup);
XS_INTERNAL(ppk_cb_lookup) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    SV *c, *model, *row = NULL;
    if (items < 1) XSRETURN_UNDEF;
    /* the ceremony passes the credential id; the context is the one
     * this closure was built for, reached through the config's stash */
    c = ppk_ctx_of(aTHX_ cv);
    if (!c) XSRETURN_UNDEF;
    model = ppk_model(aTHX_ cfg, c);
    if (!(model && SvROK(model))) XSRETURN_UNDEF;
    {
        SV *argv[2];
        argv[0] = sv_2mortal(newSVpvs("credential_id"));
        argv[1] = ST(0);
        row = sv_2mortal(ppk_call(aTHX_ model, "get", argv, 2));
    }
    ST(0) = (row && SvROK(row)) ? row : &PL_sv_undef;
    XSRETURN(1);
}

XS_INTERNAL(ppk_cb_used);
XS_INTERNAL(ppk_cb_used) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    SV *c, *model, *row;
    if (items < 2) XSRETURN_EMPTY;
    row = ST(0);
    c = ppk_ctx_of(aTHX_ cv);
    if (!c || !ppk_is_hash(row)) XSRETURN_EMPTY;
    model = ppk_model(aTHX_ cfg, c);
    if (!(model && SvROK(model))) XSRETURN_EMPTY;
    {
        HV *chg = newHV();
        SV *argv[1], *r;
        SV *id = ppk_hv_get(aTHX_ (HV *)SvRV(row), "id");
        if (!id) id = ppk_hv_get(aTHX_ (HV *)SvRV(row), "credential_id");
        if (!id) XSRETURN_EMPTY;
        (void)hv_stores(chg, "id", newSVsv(id));
        (void)hv_stores(chg, "sign_count", newSVsv(ST(1)));
        (void)hv_stores(chg, "last_used_at", newSViv((IV)time(NULL)));
        argv[0] = sv_2mortal(newRV_noinc((SV *)chg));
        r = ppk_call(aTHX_ model, "update", argv, 1);
        if (r) SvREFCNT_dec(r);
    }
    XSRETURN_EMPTY;
}

/* POST login_path */
XS_INTERNAL(ppk_r_login);
XS_INTERNAL(ppk_r_login) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    SV *c, *body, *ok;
    const char *why = NULL;
    if (items < 1) XSRETURN_EMPTY;
    c = ST(0);
    {
        SV *req = sv_2mortal(ppk_call(aTHX_ c, "req", NULL, 0));
        body = req && SvROK(req)
             ? sv_2mortal(ppk_call(aTHX_ req, "json", NULL, 0)) : NULL;
    }
    if (!ppk_is_hash(body)) {
        ST(0) = sv_2mortal(ppk_json_err(aTHX_ c, "expected a JSON body", 400));
        XSRETURN(1);
    }
    {
        HV *args = (HV *)sv_2mortal((SV *)newHV());
        SV *code;
        (void)hv_stores(args, "user_verification",
                        newSVsv(ppk_cfg_sv(aTHX_ cfg, "user_verification")));
        (void)hv_stores(args, "lookup",
            ppk_closure_ctx(aTHX_ ppk_cb_lookup, cfg, c));
        (void)hv_stores(args, "on_used",
            ppk_closure_ctx(aTHX_ ppk_cb_used, cfg, c));
        if ((code = ppk_cfg_code(aTHX_ cfg, "on_clone_signal")))
            (void)hv_stores(args, "on_clone_signal", newSVsv(code));
        ok = ppk_verify(aTHX_ c, (HV *)SvRV(body), args, &why);
    }
    if (!ok) {
        SV *line = sv_2mortal(newSVpvs("passkey login refused: "));
        sv_catpv(line, (char *)(why ? why : "unknown"));
        ppk_warn(aTHX_ c, SvPVX(line));
        /* one answer for every failure - see ppk_auth.h */
        ST(0) = sv_2mortal(ppk_json_err(aTHX_ c, "authentication failed", 401));
        XSRETURN(1);
    }
    sv_2mortal(ok);
    {   /* the hand-off: this plugin does not decide what logging in
         * means. sign_in is where session rotation and redirect policy
         * already live for every other factor. */
        SV *uid = ppk_hv_get(aTHX_ (HV *)SvRV(ok), "user_id");
        if (ppk_can(aTHX_ c, "sign_in")) {
            SV *r = ppk_call(aTHX_ c, "sign_in", &uid, 1);
            ST(0) = r ? sv_2mortal(r) : &PL_sv_undef;
            XSRETURN(1);
        }
        {   /* no sign_in helper: answer the id and let the caller act,
             * rather than inventing a session shape */
            HV *out = newHV();
            (void)hv_stores(out, "ok", newSViv(1));
            (void)hv_stores(out, "user_id", newSVsv(uid));
            ST(0) = sv_2mortal(ppk_json(aTHX_ c,
                        sv_2mortal(newRV_noinc((SV *)out)), 0));
        }
    }
    XSRETURN(1);
}

/* ---- the helpers ----------------------------------------------------------
 *
 * $c->passkey_register_options, ->passkey_register, ->passkey_challenge
 * and ->passkey_verify: the ceremonies with the plugin's configuration
 * already applied, for an application that wants its own routes but not
 * its own configuration. ST(0) is the context. */

XS_INTERNAL(ppk_h_reg_options);
XS_INTERNAL(ppk_h_reg_options) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    HV *args;
    SV *c;
    if (items < 1) XSRETURN_UNDEF;
    c = ST(0);
    args = (items > 1 && ppk_is_hash(ST(1)))
         ? (HV *)SvRV(ST(1)) : (HV *)sv_2mortal((SV *)newHV());
    if (!hv_exists(args, "user_verification", 17))
        (void)hv_stores(args, "user_verification",
                        newSVsv(ppk_cfg_sv(aTHX_ cfg, "user_verification")));
    if (!hv_exists(args, "user_id", 7)) {
        SV *uid = ppk_user_id(aTHX_ cfg, c);
        if (uid && SvOK(uid)) (void)hv_stores(args, "user_id", newSVsv(uid));
    }
    ST(0) = sv_2mortal(ppk_register_options(aTHX_ c, args));
    XSRETURN(1);
}

XS_INTERNAL(ppk_h_register);
XS_INTERNAL(ppk_h_register) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    const char *why = NULL;
    SV *out, *c;
    HV *args;
    if (items < 2 || !ppk_is_hash(ST(1)))
        croak("passkey_register needs the browser's response as a hashref");
    c = ST(0);
    args = (items > 2 && ppk_is_hash(ST(2)))
         ? (HV *)SvRV(ST(2)) : (HV *)sv_2mortal((SV *)newHV());
    if (!hv_exists(args, "user_verification", 17))
        (void)hv_stores(args, "user_verification",
                        newSVsv(ppk_cfg_sv(aTHX_ cfg, "user_verification")));
    out = ppk_register(aTHX_ c, (HV *)SvRV(ST(1)), args, &why);
    sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD), why ? why : "");
    if (!out) {
        SV *line = sv_2mortal(newSVpvs("passkey registration refused: "));
        sv_catpv(line, (char *)(why ? why : "unknown"));
        ppk_warn(aTHX_ c, SvPVX(line));
        XSRETURN_UNDEF;
    }
    ST(0) = sv_2mortal(out);
    XSRETURN(1);
}

XS_INTERNAL(ppk_h_challenge);
XS_INTERNAL(ppk_h_challenge) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    HV *args;
    if (items < 1) XSRETURN_UNDEF;
    args = (items > 1 && ppk_is_hash(ST(1)))
         ? (HV *)SvRV(ST(1)) : (HV *)sv_2mortal((SV *)newHV());
    if (!hv_exists(args, "user_verification", 17))
        (void)hv_stores(args, "user_verification",
                        newSVsv(ppk_cfg_sv(aTHX_ cfg, "user_verification")));
    ST(0) = sv_2mortal(ppk_challenge_options(aTHX_ ST(0), args));
    XSRETURN(1);
}

XS_INTERNAL(ppk_h_verify);
XS_INTERNAL(ppk_h_verify) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    const char *why = NULL;
    SV *out, *c, *code;
    HV *args;
    if (items < 2 || !ppk_is_hash(ST(1)))
        croak("passkey_verify needs the browser's assertion as a hashref");
    c = ST(0);
    args = (items > 2 && ppk_is_hash(ST(2)))
         ? (HV *)SvRV(ST(2)) : (HV *)sv_2mortal((SV *)newHV());
    if (!hv_exists(args, "user_verification", 17))
        (void)hv_stores(args, "user_verification",
                        newSVsv(ppk_cfg_sv(aTHX_ cfg, "user_verification")));
    /* the model-backed callbacks, unless the caller brought its own */
    if (!hv_exists(args, "lookup", 6))
        (void)hv_stores(args, "lookup",
                        ppk_closure_ctx(aTHX_ ppk_cb_lookup, cfg, c));
    if (!hv_exists(args, "on_used", 7))
        (void)hv_stores(args, "on_used",
                        ppk_closure_ctx(aTHX_ ppk_cb_used, cfg, c));
    if (!hv_exists(args, "on_clone_signal", 15)
        && (code = ppk_cfg_code(aTHX_ cfg, "on_clone_signal")))
        (void)hv_stores(args, "on_clone_signal", newSVsv(code));
    out = ppk_verify(aTHX_ c, (HV *)SvRV(ST(1)), args, &why);
    sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD), why ? why : "");
    if (!out) {
        SV *line = sv_2mortal(newSVpvs("passkey login refused: "));
        sv_catpv(line, (char *)(why ? why : "unknown"));
        ppk_warn(aTHX_ c, SvPVX(line));
        XSRETURN_UNDEF;
    }
    ST(0) = sv_2mortal(out);
    XSRETURN(1);
}

/* ---- the boot check -------------------------------------------------------
 *
 * Run through on_compile, which fires at to_app after every keyword has
 * recorded - so `plugin 'Passkey'` above or below `session` and `host`
 * behaves identically, and the application is not made to care about
 * declaration order.
 *
 * Both of these are refusals to start rather than warnings. A passkey
 * ceremony without a session cannot remember a challenge, and one
 * without `host` has no origin to check against except the request's,
 * which is the check being skipped. Neither degrades into something
 * partly working; they degrade into something that looks like it works.
 */
/* Make sure the model the ceremonies read exists by the time a request
 * asks for it.
 *
 * When the application registered one under the configured name, or has
 * one discoverable in its own Model namespace, that is the one. Otherwise
 * the class shipped here is registered under its full name, which Punk
 * takes as a class rather than as a name in the application's namespace.
 *
 * The trap: naming ANY model turns auto-discovery off unless it was asked
 * for explicitly (punk_compile.h: autoflag = explicit ? explicit :
 * !named), so an application relying on a bare `model;` to find its own
 * classes would lose them the moment this plugin named one. Put it back
 * first.
 */
static void ppk_ensure_model(pTHX_ SV *app, HV *cfg, const char *shipped) {
    SV *name = ppk_hv_get(aTHX_ cfg, "model");
    HV *apph;
    SV *models, *auto_sv;
    STRLEN nl;
    const char *np;
    int named = 0;

    if (!(name && SvOK(name))) return;
    np = SvPV_const(name, nl);
    if (memchr(np, ':', nl)) return;        /* already a class: the app's */

    apph = SvROK(app) ? (HV *)SvRV(app) : NULL;
    if (!apph) return;

    models = ppk_hv_get(aTHX_ apph, "models");
    if (models && SvROK(models) && SvTYPE(SvRV(models)) == SVt_PVAV) {
        AV *av = (AV *)SvRV(models);
        SSize_t i, n = av_len(av) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(av, i, 0);
            if (!(e && *e && SvOK(*e))) continue;
            if (sv_eq(*e, name)) return;    /* the application named it */
            named++;
        }
    }

    {   /* <App>::Model::<Name>, theirs if it exists at all */
        SV *caller = sv_2mortal(ppk_call(aTHX_ app, "caller_class", NULL, 0));
        SV *full = sv_2mortal(newSVsv(caller));
        SV *req;
        sv_catpvs(full, "::Model::");
        sv_catsv(full, name);
        /* Already in the symbol table: a model class declared inline rather
         * than in a file of its own. `require` cannot see one - it looks for
         * a file - and answering "they have none" here would register the
         * shipped class over the top of theirs, which is the silent wrong
         * table rather than an error. Punk's own discovery has the same
         * case (punk_compile.h) and it is checked the same way. */
        if (sv_derived_from(full, "Punk::Model")) return;
        req = sv_2mortal(newSVpvs("require "));
        sv_catsv(req, full);
        sv_catpvs(req, "; 1");
        eval_pv(SvPV_nolen(req), FALSE);
        if (!SvTRUE(ERRSV)) return;
    }

    auto_sv = ppk_hv_get(aTHX_ apph, "model_auto");
    if (!named && !(auto_sv && SvOK(auto_sv))) {
        SV *one = sv_2mortal(newSViv(1));
        SvREFCNT_dec(ppk_call(aTHX_ app, "model_auto", &one, 1));
    }
    {
        SV *req = sv_2mortal(newSVpvs("require "));
        SV *cls = sv_2mortal(newSVpv(shipped, 0));
        SV *argv[1];
        sv_catpv(req, shipped);
        sv_catpvs(req, "; 1");
        eval_pv(SvPV_nolen(req), TRUE);
        argv[0] = cls;
        SvREFCNT_dec(ppk_call(aTHX_ app, "model_class", argv, 1));
        (void)hv_stores(cfg, "model", newSVpv(shipped, 0));
    }
}

XS_INTERNAL(ppk_oc_check);
XS_INTERNAL(ppk_oc_check) {
    dXSARGS;
    HV *cfg = ppk_cfg_of(aTHX_ cv);
    SV *app;
    if (items < 1) XSRETURN_EMPTY;
    app = ST(0);
    if (!(app && SvROK(app) && SvTYPE(SvRV(app)) == SVt_PVHV)) XSRETURN_EMPTY;
    if (!hv_exists((HV *)SvRV(app), "session", 7))
        croak("plugin 'Passkey' needs the `session` keyword - a passkey "
              "ceremony issues a challenge in one request and checks it in "
              "the next, and the challenge cannot be kept anywhere the "
              "client can reach");
    if (!hv_exists((HV *)SvRV(app), "host", 4))
        croak("plugin 'Passkey' needs the `host` keyword - the relying "
              "party id and the origin check come from the application's "
              "declared origin, and taking them from the request would let "
              "a caller choose which site's credentials it is presenting");
    ppk_ensure_model(aTHX_ app, cfg, "Punk::Model::Passkey");
    XSRETURN_EMPTY;
}

/* ---- registration --------------------------------------------------------- */

static SV *ppk_opt_or(pTHX_ HV *opts, const char *k, SV *dflt) {
    SV **e = hv_fetch(opts, k, (I32)strlen(k), 0);
    if (e && *e && SvOK(*e)) { if (dflt) SvREFCNT_dec(dflt); return newSVsv(*e); }
    return dflt;
}

static void ppk_plugin_register(pTHX_ SV *app, SV *optsv) {
    static const char *const known[] = {
        "register_path", "login_path", "asset_path", "model",
        "user_verification", "resident_key", "on_clone_signal",
        "has_other_factor", "user_id", "user_name", "credentials_for",
        "render", "rp_name", "sqitch"
    };
    HV *opts, *cfg;
    SV *pkgsv, *v;
    STRLEN pl;
    const char *pkg;
    int i;

    if (!PPK_STATE) PPK_STATE = newHV();
    if (SvOK(optsv) && !ppk_is_hash(optsv))
        croak("plugin 'Passkey' takes a hashref of options");
    opts = ppk_is_hash(optsv) ? (HV *)SvRV(optsv)
                              : (HV *)sv_2mortal((SV *)newHV());

    pkgsv = sv_2mortal(ppk_call(aTHX_ app, "caller_class", NULL, 0));
    pkg   = SvPV_const(pkgsv, pl);
    if (hv_exists(PPK_STATE, pkg, (I32)pl))
        croak("plugin 'Passkey' already registered for %s", pkg);

    /* unknown options croak at boot, sorted so the message is
     * deterministic when several are wrong at once */
    {
        AV *keys = (AV *)sv_2mortal((SV *)newAV());
        HE *he;
        SSize_t ki, kn;
        hv_iterinit(opts);
        while ((he = hv_iternext(opts))) av_push(keys, newSVsv(hv_iterkeysv(he)));
        if (av_len(keys) > 0)
            sortsv(AvARRAY(keys), (size_t)(av_len(keys) + 1), Perl_sv_cmp);
        kn = av_len(keys) + 1;
        for (ki = 0; ki < kn; ki++) {
            const char *k = SvPV_nolen_const(*av_fetch(keys, ki, 0));
            int found = 0;
            for (i = 0; i < (int)(sizeof known / sizeof known[0]); i++)
                if (strEQ(k, known[i])) { found = 1; break; }
            if (!found) croak("unknown Passkey plugin option '%s'", k);
        }
    }

    cfg = (HV *)sv_2mortal((SV *)newHV());
    (void)hv_stores(cfg, "register_path",
        ppk_opt_or(aTHX_ opts, "register_path", newSVpvs("/account/passkeys")));
    (void)hv_stores(cfg, "login_path",
        ppk_opt_or(aTHX_ opts, "login_path", newSVpvs("/login/passkey")));
    (void)hv_stores(cfg, "asset_path",
        ppk_opt_or(aTHX_ opts, "asset_path", newSVpvs("/punk-passkey.js")));
    (void)hv_stores(cfg, "model",
        ppk_opt_or(aTHX_ opts, "model", newSVpvs("Passkey")));
    (void)hv_stores(cfg, "rp_name", ppk_opt_or(aTHX_ opts, "rp_name", NULL));
    (void)hv_stores(cfg, "render",  ppk_opt_or(aTHX_ opts, "render",  NULL));

    {   /* preferences, and only two spellings are meaningful */
        SV *uv = ppk_opt_or(aTHX_ opts, "user_verification",
                            newSVpvs("preferred"));
        const char *s = SvPV_nolen(uv);
        if (!strEQ(s, "preferred") && !strEQ(s, "required")
            && !strEQ(s, "discouraged"))
            croak("Passkey user_verification must be preferred, required "
                  "or discouraged, not '%s'", s);
        (void)hv_stores(cfg, "user_verification", uv);
    }
    (void)hv_stores(cfg, "resident_key",
        ppk_opt_or(aTHX_ opts, "resident_key", newSVpvs("preferred")));

    /* the coderef options, each checked so a typo is a boot error
     * rather than a callback that silently never fires */
    {
        static const char *const codes[] = {
            "on_clone_signal", "has_other_factor", "user_id", "user_name",
            "credentials_for"
        };
        for (i = 0; i < (int)(sizeof codes / sizeof codes[0]); i++) {
            SV **e = hv_fetch(opts, codes[i], (I32)strlen(codes[i]), 0);
            if (!(e && *e && SvOK(*e))) continue;
            if (!(SvROK(*e) && SvTYPE(SvRV(*e)) == SVt_PVCV))
                croak("Passkey %s must be a coderef", codes[i]);
            (void)hv_store(cfg, codes[i], (I32)strlen(codes[i]),
                           newSVsv(*e), 0);
        }
    }

    (void)hv_store(PPK_STATE, pkg, (I32)pl, newRV_inc((SV *)cfg), 0);

    /* the JS ETag, and the ABI resolution behind it: fail at boot */
    ppk_js_boot(aTHX);

    /* sqitch => 1: the credential table, shipped as the punk_passkey
     * project and registered with Punk-Sqitch, which deploys it after
     * Punk::Auth's users table and before the application's own. Opt-in,
     * because an application may keep credentials in a table of its own
     * shape; asking without Punk-Sqitch installed is an error, not a
     * silence. */
    if ((v = hv_fetchs(opts, "sqitch", 0) ? *hv_fetchs(opts, "sqitch", 0)
                                          : NULL) && SvTRUE(v)) {
        SV **pm = hv_fetchs(GvHV(PL_incgv), "Punk/Passkey.pm", 0);
        SV *dir, *cls, *r;
        AV *eng;
        eval_pv("require Punk::Plugin::Sqitch; 1", FALSE);
        if (SvTRUE(ERRSV))
            croak("plugin 'Passkey': sqitch => 1 needs Punk-Sqitch "
                  "(Punk::Plugin::Sqitch) installed: %s", SvPV_nolen(ERRSV));
        if (!(pm && *pm && SvOK(*pm)))
            croak("plugin 'Passkey': cannot find Punk/Passkey.pm in %%INC "
                  "to locate the punk_passkey Sqitch project");
        dir = sv_2mortal(newSVsv(*pm));
        {   /* .../Punk/Passkey.pm -> .../Punk/Plugin/Passkey/sqitch */
            STRLEN dl;
            const char *dp = SvPV_const(dir, dl);
            if (dl >= 10 && memEQ(dp + dl - 10, "Passkey.pm", 10))
                SvCUR_set(dir, dl - 10);
        }
        sv_catpvs(dir, "Plugin/Passkey/sqitch");
        eng = newAV();
        av_push(eng, newSVpvs("sqlite"));
        av_push(eng, newSVpvs("pg"));
        av_push(eng, newSVpvs("mysql"));
        cls = sv_2mortal(newSVpvs("Punk::Plugin::Sqitch"));
        {
            SV *argv[5];
            argv[0] = app;
            argv[1] = sv_2mortal(newSVpvs("punk_passkey"));
            argv[2] = dir;
            argv[3] = sv_2mortal(newSVpvs("engines"));
            argv[4] = sv_2mortal(newRV_noinc((SV *)eng));
            r = ppk_call(aTHX_ cls, "project", argv, 5);
        }
        if (r) SvREFCNT_dec(r);
    }

    /* the routes */
    {
        SV *reg   = ppk_cfg_sv(aTHX_ cfg, "register_path");
        SV *login = ppk_cfg_sv(aTHX_ cfg, "login_path");
        SV *asset = ppk_cfg_sv(aTHX_ cfg, "asset_path");
        SV *sub;

        ppk_route(aTHX_ app, "GET",  reg, ppk_r_manage, cfg);
        sub = sv_2mortal(newSVsv(reg));
        sv_catpvs(sub, "/options");
        ppk_route(aTHX_ app, "POST", sub, ppk_r_reg_options, cfg);
        ppk_route(aTHX_ app, "POST", reg, ppk_r_register, cfg);
        sub = sv_2mortal(newSVsv(reg));
        sv_catpvs(sub, "/:id");
        ppk_route(aTHX_ app, "DELETE", sub, ppk_r_delete, cfg);

        sub = sv_2mortal(newSVsv(login));
        sv_catpvs(sub, "/options");
        ppk_route(aTHX_ app, "POST", sub, ppk_r_login_options, cfg);
        ppk_route(aTHX_ app, "POST", login, ppk_r_login, cfg);

        ppk_route(aTHX_ app, "GET", asset, ppk_r_js, cfg);

        /* Per-address limits on the two unauthenticated endpoints, the
         * ones an attacker retries. On top of anything the application
         * sets, not instead of it. */
        if (ppk_can(aTHX_ app, "rate_limit")) {
            SV *argv[6];
            argv[0] = sv_2mortal(newSVpvs("for"));    argv[1] = login;
            argv[2] = sv_2mortal(newSVpvs("limit"));  argv[3] = sv_2mortal(newSViv(30));
            argv[4] = sv_2mortal(newSVpvs("window")); argv[5] = sv_2mortal(newSViv(60));
            SvREFCNT_dec(ppk_call(aTHX_ app, "rate_limit", argv, 6));
        }
    }

    /* the helpers, so an application can drive the ceremonies from its
     * own routes without reaching for the package functions */
    ppk_helper(aTHX_ app, "passkey_register_options", ppk_h_reg_options, cfg);
    ppk_helper(aTHX_ app, "passkey_register",         ppk_h_register,    cfg);
    ppk_helper(aTHX_ app, "passkey_challenge",        ppk_h_challenge,   cfg);
    ppk_helper(aTHX_ app, "passkey_verify",           ppk_h_verify,      cfg);

    /* The boot check and the model, both at to_app: `session`, `host` and
     * `model` may each be declared after this line, so none of them can be
     * settled at `plugin`. On a Punk too old to have on_compile the model
     * is still settled here, which is right whenever the application
     * declared its own before the plugin line. */
    if (ppk_can(aTHX_ app, "on_compile")) {
        SV *argv[2];
        argv[0] = sv_2mortal(ppk_closure(aTHX_ ppk_oc_check, cfg));
        argv[1] = sv_2mortal(newSVpvs("Punk::Plugin::Passkey"));
        SvREFCNT_dec(ppk_call(aTHX_ app, "on_compile", argv, 2));
    }
    else {
        ppk_ensure_model(aTHX_ app, cfg, "Punk::Model::Passkey");
    }
}

#endif /* PPK_PLUGIN_H */
