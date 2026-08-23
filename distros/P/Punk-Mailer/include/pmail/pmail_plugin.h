#ifndef PMAIL_PLUGIN_H
#define PMAIL_PLUGIN_H

#include <dirent.h>

/* pmail_plugin.h - Punk::Plugin::Mailer, the C half.
 *
 * Registration builds the engine (so every transport option croaks at
 * boot), reads the template directory, wires `later` to Punk::Queue, and
 * installs the helpers on the context. Each helper is an XS closure over
 * the application's configuration hash - the Punk-TOTP shape - and the
 * configuration is kept per application class in PM_PLUGIN_STATE.
 *
 * Templates render through Template::Stencil's C ABI (st_abi.h), two
 * engines per application: one escaping, for the HTML alternative, and
 * one not, for the text part - escaping is a constructor option there.
 * The queue hand-off and the token issue go through the context's own
 * methods (enqueue, issue_token), called from C. */

static HV *PM_PLUGIN_STATE = NULL;     /* app class => cfg */
static const st_abi *PM_ST = NULL;

/* ---- closures: a CV carrying captured SVs ------------------------------ */

typedef struct { AV *cap; } pm_clos_t;

static int pm_clos_free(pTHX_ SV *sv, MAGIC *mg)
{
    pm_clos_t *c = (pm_clos_t *)mg->mg_ptr;
    PERL_UNUSED_ARG(sv);
    if (c) {
        if (c->cap) SvREFCNT_dec((SV *)c->cap);
        Safefree(c);
    }
    return 0;
}

static MGVTBL pm_clos_vtbl = { NULL, NULL, NULL, NULL, pm_clos_free, NULL, NULL, NULL };

/* slot 0 is a reference to the configuration; `extra`, if given, is slot 1 */
static SV *pm_closure(pTHX_ XSUBADDR_t body, HV *cfg, SV *extra)
{
    CV *cv = (CV *)newXS(NULL, body, (char *)__FILE__);
    AV *cap = newAV();
    pm_clos_t *c;
    av_push(cap, newRV_inc((SV *)cfg));
    if (extra) av_push(cap, newSVsv(extra));
    Newxz(c, 1, pm_clos_t);
    c->cap = cap;
    sv_magicext((SV *)cv, NULL, PERL_MAGIC_ext, &pm_clos_vtbl, (char *)c, 0);
    return newRV_noinc((SV *)cv);
}

static AV *pm_cap_of(pTHX_ CV *cv)
{
    MAGIC *mg = mg_findext((SV *)cv, PERL_MAGIC_ext, &pm_clos_vtbl);
    AV *cap = mg ? ((pm_clos_t *)mg->mg_ptr)->cap : NULL;
    if (!cap) croak("Punk::Plugin::Mailer: a closure lost its configuration");
    return cap;
}

static HV *pm_cfg_of(pTHX_ CV *cv)
{
    AV *cap = pm_cap_of(aTHX_ cv);
    SV **e = av_fetch(cap, 0, 0);
    if (!(e && *e && SvROK(*e) && SvTYPE(SvRV(*e)) == SVt_PVHV))
        croak("Punk::Plugin::Mailer: a closure lost its configuration");
    return (HV *)SvRV(*e);
}

/* ---- calling back into Perl ------------------------------------------------
 * scalar context, a NEW SV (+1) the caller owns - undef when nothing came
 * back */

static SV *pm_call(pTHX_ SV *inv, const char *meth, SV **argv, int argc)
{
    dSP;
    int count, i;
    SV *ret;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    EXTEND(SP, argc + 1);
    if (inv) PUSHs(inv);
    for (i = 0; i < argc; i++) PUSHs(argv[i]);
    PUTBACK;
    count = inv ? call_method(meth, G_SCALAR) : call_pv(meth, G_SCALAR);
    SPAGAIN;
    if (count > 0) { SV *top = POPs; ret = newSVsv(top); }
    else ret = newSV(0);
    PUTBACK; FREETMPS; LEAVE;
    return ret;
}

static int pm_can(pTHX_ SV *obj, const char *meth)
{
    SV *name = sv_2mortal(newSVpv(meth, 0));
    SV *r = sv_2mortal(pm_call(aTHX_ obj, "can", &name, 1));
    return SvTRUE(r);
}

static int pm_is_hash(SV *sv)  { return sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV; }
static int pm_is_array(SV *sv) { return sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV; }

static SV *pm_hget(pTHX_ HV *h, const char *k)
{
    SV **e = hv_fetch(h, k, (I32)strlen(k), 0);
    return (e && *e && SvOK(*e)) ? *e : NULL;
}

static SV *pm_cfg_sv(pTHX_ HV *cfg, const char *k)
{
    SV *v = pm_hget(aTHX_ cfg, k);
    if (!v) croak("Punk::Plugin::Mailer: configuration lost '%s'", k);
    return v;
}

/* key/value pairs from ST(from) onward, or one hashref, into a mortal HV */
static HV *pm_pairs(pTHX_ const char *what, SV **base, I32 from, I32 items)
{
    HV *hv = (HV *)sv_2mortal((SV *)newHV());
    I32 i;
    if (items - from == 1 && pm_is_hash(base[from])) {
        HV *given = (HV *)SvRV(base[from]);
        HE *he;
        hv_iterinit(given);
        while ((he = hv_iternext(given)))
            (void)hv_store_ent(hv, hv_iterkeysv(he), newSVsv(HeVAL(he)), 0);
        return hv;
    }
    if ((items - from) % 2) croak("%s takes key/value pairs or a hashref", what);
    for (i = from; i + 1 < items; i += 2) {
        STRLEN kl;
        const char *k = SvPV_const(base[i], kl);
        (void)hv_store(hv, k, (I32)kl, newSVsv(base[i + 1]), 0);
    }
    return hv;
}

/* ---- Template::Stencil, through its C ABI ---------------------------------- */

static void pm_st_boot(pTHX)
{
    IV p = 0;
    dSP;
    if (PM_ST) return;
    ENTER; SAVETMPS;
    eval_pv("require Template::Stencil;", FALSE);
    SPAGAIN;
    if (SvTRUE(ERRSV))
        croak("Punk::Plugin::Mailer: mail_dir needs Template::Stencil, which did "
              "not load: %s", SvPV_nolen(ERRSV));
    PUSHMARK(SP); PUTBACK;
    if (call_pv("Template::Stencil::_abi_ptr", G_SCALAR | G_EVAL) > 0) {
        SPAGAIN;
        p = POPi;
        PUTBACK;
    }
    FREETMPS; LEAVE;
    PM_ST = p ? INT2PTR(const st_abi *, p) : NULL;
    if (!PM_ST || PM_ST->abi_version < ST_ABI_VERSION) {
        PM_ST = NULL;
        croak("Punk::Plugin::Mailer: Template::Stencil with a C ABI of version %d "
              "or newer is required for mail templates", ST_ABI_VERSION);
    }
}

/* Template::Stencil->new(template_dir => $dir, stat_ttl => -1, auto_escape => $esc) */
static SV *pm_st_new(pTHX_ SV *dir, int escape)
{
    SV *argv[6];
    SV *klass = sv_2mortal(newSVpvs("Template::Stencil"));
    SV *obj;
    argv[0] = sv_2mortal(newSVpvs("template_dir")); argv[1] = dir;
    argv[2] = sv_2mortal(newSVpvs("stat_ttl"));     argv[3] = sv_2mortal(newSViv(-1));
    argv[4] = sv_2mortal(newSVpvs("auto_escape"));  argv[5] = sv_2mortal(newSViv(escape));
    obj = pm_call(aTHX_ klass, "new", argv, 6);
    if (!sv_isobject(obj)) { SvREFCNT_dec(obj); croak("Punk::Plugin::Mailer: Template::Stencil->new returned nothing"); }
    return obj;
}

/* render `name` (a file under mail_dir) with data through one of the two
 * engines; a Stencil error is the app's croak, naming the template */
static SV *pm_st_render(pTHX_ SV *engine_obj, const char *name, HV *data)
{
    void *engine;
    SV *tmpl = sv_2mortal(newSVpv(name, 0));
    SV *err = NULL, *out;
    pm_st_boot(aTHX);
    engine = PM_ST->engine_of(aTHX_ engine_obj);
    if (!engine) croak("Punk::Plugin::Mailer: the template engine is gone");
    out = PM_ST->render(aTHX_ engine, tmpl, data, NULL, &err);
    if (!out) croak("Punk::Plugin::Mailer: rendering %s: %s", name,
                    err ? SvPV_nolen(err) : "failed");
    /* Stencil hands back wire-ready UTF-8 BYTES with the flag off. The
     * builder reads every string with perl's semantics (SvPVutf8), which
     * would upgrade those bytes as latin-1 and double-encode every
     * non-ASCII character. Decode them into the character string they
     * spell; Stencil's output is guaranteed well-formed, so this cannot
     * fail on it. */
    (void)sv_utf8_decode(out);
    return out;
}

/* the template files: name => { txt => 1, html => 1 } */
static HV *pm_scan_templates(pTHX_ const char *dir)
{
    HV *out = newHV();
    DIR *d = opendir(dir);
    struct dirent *e;
    if (!d) { SvREFCNT_dec((SV *)out); croak("Punk::Plugin::Mailer: cannot read mail_dir %s: %s", dir, strerror(errno)); }
    while ((e = readdir(d))) {
        const char *n = e->d_name;
        size_t l = strlen(n);
        const char *kind = NULL;
        size_t base;
        if (l > 9 && memEQ(n + l - 9, ".txt.tmpl", 9)) { kind = "txt"; base = l - 9; }
        else if (l > 10 && memEQ(n + l - 10, ".html.tmpl", 10)) { kind = "html"; base = l - 10; }
        else continue;
        if (base == 0) continue;
        {
            SV **slot = hv_fetch(out, n, (I32)base, 1);
            HV *kinds;
            if (!SvROK(*slot)) {
                kinds = newHV();
                sv_setsv(*slot, sv_2mortal(newRV_noinc((SV *)kinds)));
            }
            else kinds = (HV *)SvRV(*slot);
            (void)hv_store(kinds, kind, (I32)strlen(kind), newSViv(1), 0);
        }
    }
    closedir(d);
    return out;
}

static int pm_has_template(pTHX_ HV *cfg, const char *name, STRLEN nl, const char *kind)
{
    SV *t = pm_hget(aTHX_ cfg, "templates");
    SV **e;
    if (!pm_is_hash(t)) return 0;
    e = hv_fetch((HV *)SvRV(t), name, (I32)nl, 0);
    if (!(e && *e && pm_is_hash(*e))) return 0;
    return hv_fetch((HV *)SvRV(*e), kind, (I32)strlen(kind), 0) != NULL;
}

static SV *pm_template_list(pTHX_ HV *cfg)
{
    SV *t = pm_hget(aTHX_ cfg, "templates");
    SV *out = newSVpvs("");
    AV *names = (AV *)sv_2mortal((SV *)newAV());
    HE *he;
    SSize_t i, n;
    if (!pm_is_hash(t)) { sv_setpvs(out, "(no mail_dir)"); return out; }
    hv_iterinit((HV *)SvRV(t));
    while ((he = hv_iternext((HV *)SvRV(t)))) av_push(names, newSVsv(hv_iterkeysv(he)));
    n = av_len(names) + 1;
    if (n > 1) sortsv(AvARRAY(names), (size_t)n, Perl_sv_cmp);
    for (i = 0; i < n; i++) {
        if (i) sv_catpvs(out, ", ");
        sv_catsv(out, *av_fetch(names, i, 0));
    }
    if (n == 0) sv_setpvs(out, "(none)");
    return out;
}

/* ---- rendering a mail -------------------------------------------------------
 * data = the caller's data + base, subject, to, locale; then the layout,
 * if one exists for the kind, with the body as `content`. One kind; NULL
 * when the template has no file of that kind. */

static SV *pm_render_kind(pTHX_ HV *cfg, SV *c, const char *name, STRLEN nl,
                          const char *kind, HV *caller_data, SV *subject, SV *to)
{
    HV *data = (HV *)sv_2mortal((SV *)newHV());
    SV *engine = pm_cfg_sv(aTHX_ cfg, strEQ(kind, "html") ? "stencil_html" : "stencil_text");
    SV *base = pm_hget(aTHX_ cfg, "base");
    SV *layout = pm_hget(aTHX_ cfg, "layout");
    SV *file, *body, *out;
    HE *he;

    if (!pm_has_template(aTHX_ cfg, name, nl, kind)) return NULL;
    if (caller_data) {
        hv_iterinit(caller_data);
        while ((he = hv_iternext(caller_data)))
            (void)hv_store_ent(data, hv_iterkeysv(he), newSVsv(HeVAL(he)), 0);
    }
    (void)hv_stores(data, "base", base ? newSVsv(base) : newSV(0));
    (void)hv_stores(data, "subject", subject ? newSVsv(subject) : newSV(0));
    (void)hv_stores(data, "to", to ? newSVsv(to) : newSV(0));
    if (c && pm_can(aTHX_ c, "locale"))
        (void)hv_stores(data, "locale", pm_call(aTHX_ c, "locale", NULL, 0));
    else (void)hv_stores(data, "locale", newSV(0));

    file = sv_2mortal(newSVpvf("%.*s.%s.tmpl", (int)nl, name, kind));
    body = pm_st_render(aTHX_ engine, SvPV_nolen(file), data);
    if (layout) {
        STRLEN ll; const char *lp = SvPV_const(layout, ll);
        if (pm_has_template(aTHX_ cfg, lp, ll, kind)) {
            SV *lfile = sv_2mortal(newSVpvf("%.*s.%s.tmpl", (int)ll, lp, kind));
            /* `body`, not `content`: Stencil reserves {% content %} for its
             * own wrapper mechanism and croaks on it as plain data */
            (void)hv_stores(data, "body", body);         /* owned by data now */
            out = pm_st_render(aTHX_ engine, SvPV_nolen(lfile), data);
            return out;
        }
    }
    return body;
}

/* the plugin's own keys, taken off the spec before the engine sees it */
static const char *const PM_SPEC_PLUGIN_KEYS[] = { "template", "data", "later" };

/* render `template` into text/html on the spec when present; strips the
 * plugin keys. Returns the later flag. */
static int pm_prepare(pTHX_ HV *cfg, SV *c, HV *spec)
{
    SV *tmpl = pm_hget(aTHX_ spec, "template");
    SV *data = pm_hget(aTHX_ spec, "data");
    SV *later = pm_hget(aTHX_ spec, "later");
    int want_later = later ? (SvTRUE(later) ? 1 : 0) : 0;
    if (data && !pm_is_hash(data)) croak("Punk::Plugin::Mailer: 'data' must be a hashref");
    if (tmpl) {
        STRLEN nl; const char *np = SvPV_const(tmpl, nl);
        SV *subject = pm_hget(aTHX_ spec, "subject");
        SV *to = pm_hget(aTHX_ spec, "to");
        SV *text, *html;
        HV *dh = data ? (HV *)SvRV(data) : NULL;
        if (!pm_hget(aTHX_ cfg, "templates"))
            croak("Punk::Plugin::Mailer: template => '%.*s' but plugin 'Mailer' has no "
                  "mail_dir", (int)nl, np);
        if (!pm_has_template(aTHX_ cfg, np, nl, "txt") && !pm_has_template(aTHX_ cfg, np, nl, "html")) {
            SV *list = sv_2mortal(pm_template_list(aTHX_ cfg));
            croak("Punk::Plugin::Mailer: no template '%.*s' in mail_dir (have: %s)",
                  (int)nl, np, SvPV_nolen(list));
        }
        text = pm_render_kind(aTHX_ cfg, c, np, nl, "txt", dh, subject, to);
        html = pm_render_kind(aTHX_ cfg, c, np, nl, "html", dh, subject, to);
        if (text && !pm_hget(aTHX_ spec, "text")) (void)hv_stores(spec, "text", text);
        else if (text) SvREFCNT_dec(text);
        if (html && !pm_hget(aTHX_ spec, "html")) (void)hv_stores(spec, "html", html);
        else if (html) SvREFCNT_dec(html);
    }
    (void)hv_delete(spec, "template", 8, G_DISCARD);
    (void)hv_delete(spec, "data", 4, G_DISCARD);
    (void)hv_delete(spec, "later", 5, G_DISCARD);
    return want_later;
}

/* ---- later: durable attachments, then enqueue ------------------------------ */

/* a Punk::Upload (any object with path/filename/type) vanishes when the
 * request ends: with Blob registered it is stored by contents and named
 * by path; otherwise it is read into the spec, up to later_inline_max */
static void pm_durable_attachments(pTHX_ HV *cfg, SV *c, HV *spec)
{
    SV *atts = pm_hget(aTHX_ spec, "attachments");
    AV *av;
    SSize_t i, n;
    NV max = SvNV(pm_cfg_sv(aTHX_ cfg, "later_inline_max"));
    if (!pm_is_array(atts)) return;
    av = (AV *)SvRV(atts);
    n = av_len(av) + 1;
    for (i = 0; i < n; i++) {
        SV **e = av_fetch(av, i, 0);
        SV *obj, *filename, *type, *path;
        HV *rep;
        if (!(e && *e && sv_isobject(*e))) continue;
        obj = *e;
        filename = sv_2mortal(pm_call(aTHX_ obj, "filename", NULL, 0));
        type = pm_can(aTHX_ obj, "type") ? sv_2mortal(pm_call(aTHX_ obj, "type", NULL, 0)) : NULL;
        rep = newHV();
        (void)hv_stores(rep, "filename", newSVsv(filename));
        if (type && SvOK(type)) (void)hv_stores(rep, "type", newSVsv(type));
        if (pm_can(aTHX_ c, "blob_put") && pm_can(aTHX_ c, "blob_path")) {
            SV *id = sv_2mortal(pm_call(aTHX_ c, "blob_put", &obj, 1));
            SV *bp = sv_2mortal(pm_call(aTHX_ c, "blob_path", &id, 1));
            (void)hv_stores(rep, "path", newSVsv(bp));
        }
        else {
            SV *content = NULL;
            path = pm_can(aTHX_ obj, "path") ? sv_2mortal(pm_call(aTHX_ obj, "path", NULL, 0)) : NULL;
            if (path && SvOK(path)) {
                struct stat st;
                const char *pp = SvPV_nolen(path);
                int fd;
                if (stat(pp, &st) != 0)
                    croak("Punk::Plugin::Mailer: cannot read attachment '%s': %s", pp, strerror(errno));
                if ((NV)st.st_size > max)
                    croak("Punk::Plugin::Mailer: attachment '%s' is %llu bytes, over "
                          "later_inline_max (%.0" NVff "); register Punk::Plugin::Blob to keep "
                          "it on disk for the job", SvPV_nolen(filename),
                          (unsigned long long)st.st_size, max);
                fd = open(pp, O_RDONLY);
                if (fd < 0) croak("Punk::Plugin::Mailer: cannot open attachment '%s': %s", pp, strerror(errno));
                content = newSV((STRLEN)st.st_size + 1);
                SvPOK_on(content);
                {
                    STRLEN got = 0;
                    for (;;) {
                        ssize_t r = read(fd, SvPVX(content) + got, (size_t)st.st_size - got);
                        if (r < 0 && errno == EINTR) continue;
                        if (r <= 0) break;
                        got += (STRLEN)r;
                        if (got >= (STRLEN)st.st_size) break;
                    }
                    close(fd);
                    SvCUR_set(content, got);
                }
            }
            else {
                SV *bytes = pm_can(aTHX_ obj, "content") ? pm_call(aTHX_ obj, "content", NULL, 0) : NULL;
                if (!bytes || !SvOK(bytes)) {
                    if (bytes) SvREFCNT_dec(bytes);
                    SvREFCNT_dec((SV *)rep);
                    croak("Punk::Plugin::Mailer: attachment %d has neither a path nor content", (int)i);
                }
                if ((NV)SvCUR(bytes) > max) {
                    SvREFCNT_dec(bytes); SvREFCNT_dec((SV *)rep);
                    croak("Punk::Plugin::Mailer: attachment '%s' is %lu bytes, over "
                          "later_inline_max (%.0" NVff ")", SvPV_nolen(filename),
                          (unsigned long)SvCUR(bytes), max);
                }
                content = bytes;
            }
            (void)hv_stores(rep, "content", content);
        }
        av_store(av, i, newRV_noinc((SV *)rep));
    }
}

static SV *pm_enqueue(pTHX_ HV *cfg, SV *c, HV *spec)
{
    SV *later = pm_hget(aTHX_ cfg, "later");
    SV *task, *klass, *args_ref, *argv[2], *id;
    AV *args;
    if (!pm_is_hash(later))
        croak("Punk::Plugin::Mailer: later was not configured - give plugin 'Mailer' "
              "a later => {...} and register plugin 'Queue' before it");
    if (!pm_can(aTHX_ c, "enqueue"))
        croak("Punk::Plugin::Mailer: later needs plugin 'Queue' (no enqueue helper)");
    task = pm_cfg_sv(aTHX_ (HV *)SvRV(later), "task");
    klass = pm_cfg_sv(aTHX_ cfg, "class");
    pm_durable_attachments(aTHX_ cfg, c, spec);
    args = newAV();
    av_push(args, newSVsv(klass));
    av_push(args, newRV_inc((SV *)spec));
    args_ref = sv_2mortal(newRV_noinc((SV *)args));
    argv[0] = task;
    argv[1] = args_ref;
    id = pm_call(aTHX_ c, "enqueue", argv, 2);
    return id;
}

/* the common body of mail / mail_later: returns a Result, or a job id */
static SV *pm_do_mail(pTHX_ HV *cfg, SV *c, HV *given, int force_later)
{
    HV *spec = newHVhv(given);
    SV *spec_ref = sv_2mortal(newRV_noinc((SV *)spec));
    SV *engine = pm_cfg_sv(aTHX_ cfg, "engine");
    int later = pm_prepare(aTHX_ cfg, c, spec) || force_later;
    if (later) return pm_enqueue(aTHX_ cfg, c, spec);
    return pm_call(aTHX_ engine, "send", &spec_ref, 1);
}

/* ---- the helpers --------------------------------------------------------------- */

/* $c->mail(%spec) */
XS_INTERNAL(pm_h_mail);
XS_INTERNAL(pm_h_mail)
{
    dXSARGS;
    HV *cfg = pm_cfg_of(aTHX_ cv);
    HV *spec;
    if (items < 2) croak("mail takes a message");
    spec = pm_pairs(aTHX_ "mail", &ST(0), 1, items);
    ST(0) = sv_2mortal(pm_do_mail(aTHX_ cfg, ST(0), spec, 0));
    XSRETURN(1);
}

/* $c->mail_later(%spec) */
XS_INTERNAL(pm_h_mail_later);
XS_INTERNAL(pm_h_mail_later)
{
    dXSARGS;
    HV *cfg = pm_cfg_of(aTHX_ cv);
    HV *spec;
    if (items < 2) croak("mail_later takes a message");
    spec = pm_pairs(aTHX_ "mail_later", &ST(0), 1, items);
    ST(0) = sv_2mortal(pm_do_mail(aTHX_ cfg, ST(0), spec, 1));
    XSRETURN(1);
}

/* $c->mail_template($name, \%data, %spec_bits) -> { text, html } */
XS_INTERNAL(pm_h_mail_template);
XS_INTERNAL(pm_h_mail_template)
{
    dXSARGS;
    HV *cfg = pm_cfg_of(aTHX_ cv);
    SV *c, *name, *data = NULL;
    HV *out, *dh = NULL;
    STRLEN nl; const char *np;
    SV *text, *html;
    if (items < 2) croak("mail_template takes a template name");
    c = ST(0); name = ST(1);
    if (items > 2) data = ST(2);
    if (data && !pm_is_hash(data)) croak("mail_template takes a data hashref");
    if (data) dh = (HV *)SvRV(data);
    np = SvPV_const(name, nl);
    if (!pm_has_template(aTHX_ cfg, np, nl, "txt") && !pm_has_template(aTHX_ cfg, np, nl, "html")) {
        SV *list = sv_2mortal(pm_template_list(aTHX_ cfg));
        croak("Punk::Plugin::Mailer: no template '%.*s' in mail_dir (have: %s)",
              (int)nl, np, SvPV_nolen(list));
    }
    out = newHV();
    text = pm_render_kind(aTHX_ cfg, c, np, nl, "txt", dh, NULL, NULL);
    html = pm_render_kind(aTHX_ cfg, c, np, nl, "html", dh, NULL, NULL);
    (void)hv_stores(out, "text", text ? text : newSV(0));
    (void)hv_stores(out, "html", html ? html : newSV(0));
    ST(0) = sv_2mortal(newRV_noinc((SV *)out));
    XSRETURN(1);
}

static SV *pm_url(pTHX_ HV *cfg, SV *path)
{
    SV *base = pm_hget(aTHX_ cfg, "base");
    STRLEN pl; const char *pp;
    SV *out;
    if (!base)
        croak("Punk::Plugin::Mailer: mail_url needs a base - give plugin 'Mailer' "
              "base => 'https://...' or declare the host keyword");
    pp = SvPV_const(path, pl);
    if (pl == 0 || pp[0] != '/')
        croak("Punk::Plugin::Mailer: mail_url takes a path starting with '/'");
    out = newSVsv(base);
    sv_catpvn(out, pp, pl);
    return out;
}

/* $c->mail_url($path) */
XS_INTERNAL(pm_h_mail_url);
XS_INTERNAL(pm_h_mail_url)
{
    dXSARGS;
    HV *cfg = pm_cfg_of(aTHX_ cv);
    if (items < 2) croak("mail_url takes a path");
    ST(0) = sv_2mortal(pm_url(aTHX_ cfg, ST(1)));
    XSRETURN(1);
}

/* $c->mail_token($user, kind => ..., %opt) -> ($result_or_jobid, $link) */
XS_INTERNAL(pm_h_mail_token);
XS_INTERNAL(pm_h_mail_token)
{
    dXSARGS;
    HV *cfg = pm_cfg_of(aTHX_ cv);
    static const char *const ok[] = {
        "kind", "ttl", "path", "template", "subject", "to", "later", "data",
        "email_field", "text", "html", "headers", "attachments", "from", "reply_to",
    };
    SV *c, *user, *kind, *ttl, *path, *to, *data, *token, *link, *id, *out;
    HV *opt, *uh, *spec, *dh;
    HE *he;
    STRLEN pl; const char *pp;

    if (items < 2 || !pm_is_hash(ST(1)) || !(id = pm_hget(aTHX_ (HV *)SvRV(ST(1)), "id")))
        croak("mail_token takes a user hashref with an id");
    c = ST(0); user = ST(1); uh = (HV *)SvRV(user);
    opt = pm_pairs(aTHX_ "mail_token", &ST(0), 2, items);
    hv_iterinit(opt);
    while ((he = hv_iternext(opt))) {
        STRLEN kl; const char *k = HePV(he, kl);
        if (!pmail_str_in(k, kl, ok, sizeof ok / sizeof *ok, 0))
            croak("Punk::Plugin::Mailer: unknown mail_token option '%.*s'", (int)kl, k);
    }
    if (!pm_can(aTHX_ c, "issue_token"))
        croak("Punk::Plugin::Mailer: mail_token needs the auth keyword (no issue_token)");
    kind = pm_hget(aTHX_ opt, "kind");
    if (!kind) croak("Punk::Plugin::Mailer: mail_token needs a kind");
    if (!pm_hget(aTHX_ opt, "template") && !pm_hget(aTHX_ opt, "text") && !pm_hget(aTHX_ opt, "html"))
        croak("Punk::Plugin::Mailer: mail_token needs a template (the link is in its data)");
    if (!pm_hget(aTHX_ opt, "subject"))
        croak("Punk::Plugin::Mailer: mail_token needs a subject");
    ttl = pm_hget(aTHX_ opt, "ttl");
    if (!ttl) ttl = sv_2mortal(newSViv(2 * 24 * 60 * 60));
    path = pm_hget(aTHX_ opt, "path");
    if (!path) path = sv_2mortal(newSVpvs("/verify/%s"));
    to = pm_hget(aTHX_ opt, "to");
    if (!to) {
        SV *field = pm_hget(aTHX_ opt, "email_field");
        SV **e = hv_fetch(uh, field ? SvPV_nolen(field) : "email",
                          field ? (I32)SvCUR(field) : 5, 0);
        if (!(e && *e && SvOK(*e)))
            croak("Punk::Plugin::Mailer: mail_token: the user has no email (give to => ...)");
        to = *e;
    }

    {
        SV *argv[3];
        argv[0] = id; argv[1] = kind; argv[2] = ttl;
        token = sv_2mortal(pm_call(aTHX_ c, "issue_token", argv, 3));
    }
    if (!SvOK(token) || !SvCUR(token))
        croak("Punk::Plugin::Mailer: issue_token returned nothing");

    /* the link: base + path with the first %s replaced by the token */
    pp = SvPV_const(path, pl);
    {
        SV *filled = sv_2mortal(newSVpvs(""));
        const char *at = NULL;
        STRLEN i;
        for (i = 0; i + 1 < pl; i++) if (pp[i] == '%' && pp[i + 1] == 's') { at = pp + i; break; }
        if (!at) croak("Punk::Plugin::Mailer: mail_token's path needs a %%s for the token");
        sv_catpvn(filled, pp, (STRLEN)(at - pp));
        sv_catsv(filled, token);
        sv_catpvn(filled, at + 2, pl - (STRLEN)(at - pp) - 2);
        link = sv_2mortal(pm_url(aTHX_ cfg, filled));
    }

    spec = (HV *)sv_2mortal((SV *)newHV());
    hv_iterinit(opt);
    while ((he = hv_iternext(opt))) {
        STRLEN kl; const char *k = HePV(he, kl);
        if ((kl == 4 && memEQ(k, "kind", 4)) || (kl == 3 && memEQ(k, "ttl", 3))
            || (kl == 4 && memEQ(k, "path", 4)) || (kl == 11 && memEQ(k, "email_field", 11))
            || (kl == 4 && memEQ(k, "data", 4)))
            continue;
        (void)hv_store(spec, k, (I32)kl, newSVsv(HeVAL(he)), 0);
    }
    (void)hv_stores(spec, "to", newSVsv(to));
    dh = newHV();
    data = pm_hget(aTHX_ opt, "data");
    if (data) {
        if (!pm_is_hash(data)) croak("Punk::Plugin::Mailer: mail_token's data must be a hashref");
        hv_iterinit((HV *)SvRV(data));
        while ((he = hv_iternext((HV *)SvRV(data))))
            (void)hv_store_ent(dh, hv_iterkeysv(he), newSVsv(HeVAL(he)), 0);
    }
    (void)hv_stores(dh, "link", newSVsv(link));
    (void)hv_stores(dh, "token", newSVsv(token));
    (void)hv_stores(dh, "user", newSVsv(user));
    (void)hv_stores(spec, "data", newRV_noinc((SV *)dh));

    out = sv_2mortal(pm_do_mail(aTHX_ cfg, c, spec, 0));
    if (GIMME_V == G_LIST) {
        EXTEND(SP, 2);
        ST(0) = out;
        ST(1) = link;
        XSRETURN(2);
    }
    ST(0) = out;
    XSRETURN(1);
}

/* ---- the to_app step: base defaults to the host keyword ----------------------- */

XS_INTERNAL(pm_mw);
XS_INTERNAL(pm_mw)
{
    dXSARGS;
    AV *cap = pm_cap_of(aTHX_ cv);
    HV *cfg = pm_cfg_of(aTHX_ cv);
    SV **appp = av_fetch(cap, 1, 0);
    if (items < 1) croak("middleware takes the inner app");
    if (!pm_hget(aTHX_ cfg, "base") && appp && *appp && SvROK(*appp)) {
        SV *host = sv_2mortal(pm_call(aTHX_ *appp, "host", NULL, 0));
        if (SvOK(host) && SvCUR(host)) (void)hv_stores(cfg, "base", newSVsv(host));
    }
    ST(0) = ST(0);      /* the inner app, unchanged */
    XSRETURN(1);
}

/* ---- the task body ------------------------------------------------------------ */

/* Punk::Mailer::Job::send($job, $class, \%spec) */
static SV *pm_job_send(pTHX_ SV *job, SV *klass, SV *spec)
{
    STRLEN kl; const char *kp;
    SV **e;
    HV *cfg;
    SV *engine, *result, *status, *message, *argv[2];
    const char *st;
    if (!klass || !SvOK(klass) || !pm_is_hash(spec))
        croak("Punk::Mailer::Job::send takes the application class and a message");
    kp = SvPV_const(klass, kl);
    e = PM_PLUGIN_STATE ? hv_fetch(PM_PLUGIN_STATE, kp, (I32)kl, 0) : NULL;
    if (!(e && *e && pm_is_hash(*e)))
        croak("Punk::Mailer::Job: plugin 'Mailer' is not registered for %.*s in this "
              "process - does the worker boot the application class?", (int)kl, kp);
    cfg = (HV *)SvRV(*e);
    engine = pm_cfg_sv(aTHX_ cfg, "engine");
    result = sv_2mortal(pm_call(aTHX_ engine, "send", &spec, 1));
    status = sv_2mortal(pm_call(aTHX_ result, "status", NULL, 0));
    message = sv_2mortal(pm_call(aTHX_ result, "message", NULL, 0));
    st = SvPV_nolen(status);
    if (strEQ(st, PMAIL_ST_ACCEPTED)) {
        HV *out = newHV();
        (void)hv_stores(out, "id", pm_call(aTHX_ result, "id", NULL, 0));
        (void)hv_stores(out, "code", pm_call(aTHX_ result, "code", NULL, 0));
        (void)hv_stores(out, "message", newSVsv(message));
        return newRV_noinc((SV *)out);
    }
    if (job && pm_can(aTHX_ job, "note")) {
        argv[0] = sv_2mortal(newSVpvs("mail")); argv[1] = message;
        SvREFCNT_dec(pm_call(aTHX_ job, "note", argv, 2));
        if (strEQ(st, PMAIL_ST_REJECTED)) {
            argv[0] = sv_2mortal(newSVpvs("final")); argv[1] = sv_2mortal(newSViv(1));
            SvREFCNT_dec(pm_call(aTHX_ job, "note", argv, 2));
        }
    }
    if (strEQ(st, PMAIL_ST_REJECTED))
        croak("rejected (no retry will help): %s", SvPV_nolen(message));
    croak("%s: %s", st, SvPV_nolen(message));
    return NULL;
}

/* ---- registration ------------------------------------------------------------- */

static void pm_helper(pTHX_ SV *app, const char *name, XSUBADDR_t body, HV *cfg)
{
    SV *argv[3];
    argv[0] = sv_2mortal(newSVpv(name, 0));
    argv[1] = sv_2mortal(pm_closure(aTHX_ body, cfg, NULL));
    argv[2] = sv_2mortal(newSVpvs("Punk::Plugin::Mailer"));
    SvREFCNT_dec(pm_call(aTHX_ app, "helper", argv, 3));
}

static void pm_register(pTHX_ SV *app, SV *optsv)
{
    static const char *const known[] = {
        "transport", "from", "reply_to", "message_id_domain",
        "base", "mail_dir", "layout", "later", "later_inline_max",
        "capture", "log", "sendmail", "resend", "smtp", "options",
    };
    static const char *const engine_keys[] = {
        "transport", "from", "reply_to", "message_id_domain",
        "capture", "log", "sendmail", "resend", "smtp", "options",
    };
    HV *opts, *cfg, *ekeys;
    SV *pkgsv, *v, *engine, *eref, *klass;
    STRLEN pl;
    const char *pkg;
    size_t i;

    if (!PM_PLUGIN_STATE) PM_PLUGIN_STATE = newHV();
    if (SvOK(optsv) && !pm_is_hash(optsv))
        croak("plugin 'Mailer' takes a hashref of options");
    opts = pm_is_hash(optsv) ? (HV *)SvRV(optsv) : (HV *)sv_2mortal((SV *)newHV());

    pkgsv = sv_2mortal(pm_call(aTHX_ app, "caller_class", NULL, 0));
    pkg = SvPV_const(pkgsv, pl);
    if (hv_exists(PM_PLUGIN_STATE, pkg, (I32)pl))
        croak("plugin 'Mailer' already registered for %.*s", (int)pl, pkg);

    pmail_opts_check(aTHX_ "plugin 'Mailer'", opts, known, sizeof known / sizeof *known);
    if (!pm_hget(aTHX_ opts, "transport"))
        croak("plugin 'Mailer' needs a transport (smtp, resend, sendmail, capture, log)");

    cfg = (HV *)sv_2mortal((SV *)newHV());
    (void)hv_stores(cfg, "class", newSVpvn(pkg, pl));

    /* the engine: every transport option is checked by its new */
    ekeys = (HV *)sv_2mortal((SV *)newHV());
    for (i = 0; i < sizeof engine_keys / sizeof *engine_keys; i++)
        if ((v = pm_hget(aTHX_ opts, engine_keys[i])))
            (void)hv_store(ekeys, engine_keys[i], (I32)strlen(engine_keys[i]), newSVsv(v), 0);
    eref = sv_2mortal(newRV_inc((SV *)ekeys));
    klass = sv_2mortal(newSVpvs("Punk::Mailer"));
    engine = pm_call(aTHX_ klass, "new", &eref, 1);
    if (!sv_isobject(engine)) { SvREFCNT_dec(engine); croak("plugin 'Mailer': Punk::Mailer->new returned nothing"); }
    (void)hv_stores(cfg, "engine", engine);
    (void)hv_stores(cfg, "transport_name", newSVsv(pm_hget(aTHX_ opts, "transport")));

    /* base: an absolute origin, kept without a trailing slash */
    if ((v = pm_hget(aTHX_ opts, "base"))) {
        STRLEN bl; const char *bp = SvPV_const(v, bl);
        SV *b;
        if (!((bl > 8 && memEQ(bp, "https://", 8)) || (bl > 7 && memEQ(bp, "http://", 7))))
            croak("plugin 'Mailer': base must be an absolute origin (https://example.com), "
                  "not '%.*s'", (int)bl, bp);
        while (bl > 8 && bp[bl - 1] == '/') bl--;
        b = newSVpvn(bp, bl);
        pmail_hdr_assert_clean(aTHX_ "base", bp, bl);
        (void)hv_stores(cfg, "base", b);
    }

    /* templates */
    if ((v = pm_hget(aTHX_ opts, "mail_dir"))) {
        struct stat st;
        const char *dp = SvPV_nolen(v);
        HV *templates;
        if (stat(dp, &st) != 0 || !S_ISDIR(st.st_mode))
            croak("plugin 'Mailer': mail_dir '%s' is not a directory", dp);
        templates = pm_scan_templates(aTHX_ dp);
        if (!HvUSEDKEYS(templates)) {
            SvREFCNT_dec((SV *)templates);
            croak("plugin 'Mailer': mail_dir '%s' holds no *.txt.tmpl or *.html.tmpl", dp);
        }
        pm_st_boot(aTHX);
        (void)hv_stores(cfg, "mail_dir", newSVsv(v));
        (void)hv_stores(cfg, "templates", newRV_noinc((SV *)templates));
        (void)hv_stores(cfg, "stencil_html", pm_st_new(aTHX_ v, 1));
        (void)hv_stores(cfg, "stencil_text", pm_st_new(aTHX_ v, 0));
        if ((v = pm_hget(aTHX_ opts, "layout"))) {
            STRLEN ll; const char *lp = SvPV_const(v, ll);
            if (!pm_has_template(aTHX_ cfg, lp, ll, "txt") && !pm_has_template(aTHX_ cfg, lp, ll, "html"))
                croak("plugin 'Mailer': layout '%.*s' has no %.*s.txt.tmpl or %.*s.html.tmpl "
                      "in mail_dir", (int)ll, lp, (int)ll, lp, (int)ll, lp);
            (void)hv_stores(cfg, "layout", newSVsv(v));
        }
    }
    else if (pm_hget(aTHX_ opts, "layout"))
        croak("plugin 'Mailer': layout needs a mail_dir");

    /* later: a Punk::Queue task, declared now through the task keyword the
     * Queue plugin installed when it was used - so Queue must come first */
    v = pm_hget(aTHX_ opts, "later_inline_max");
    (void)hv_stores(cfg, "later_inline_max", newSVnv(v ? SvNV(v) : 1048576.0));
    if ((v = pm_hget(aTHX_ opts, "later"))) {
        HV *lh, *defaults;
        SV *task, *kwname, *target, *dref;
        CV *kw;
        HE *he;
        if (!pm_is_hash(v)) croak("plugin 'Mailer': later takes a hashref");
        lh = (HV *)SvRV(v);
        task = pm_hget(aTHX_ lh, "task");
        kwname = sv_2mortal(newSVpvf("%.*s::task", (int)pl, pkg));
        kw = get_cv(SvPV_nolen(kwname), 0);
        if (!kw)
            croak("plugin 'Mailer': later needs plugin 'Queue' - `use Punk::Plugin::Queue` "
                  "and register plugin 'Queue' before plugin 'Mailer'");
        defaults = newHV();
        hv_iterinit(lh);
        while ((he = hv_iternext(lh))) {
            STRLEN kl; const char *k = HePV(he, kl);
            if (kl == 4 && memEQ(k, "task", 4)) continue;
            (void)hv_store(defaults, k, (I32)kl, newSVsv(HeVAL(he)), 0);
        }
        dref = sv_2mortal(newRV_noinc((SV *)defaults));
        target = sv_2mortal(newSVpvs("+Punk::Mailer::Job#send"));
        {
            dSP;
            ENTER; SAVETMPS;
            PUSHMARK(SP);
            XPUSHs(task ? task : sv_2mortal(newSVpvs("mail.send")));
            XPUSHs(target);
            XPUSHs(dref);
            PUTBACK;
            call_sv((SV *)kw, G_DISCARD);
            FREETMPS; LEAVE;
        }
        {
            HV *later_cfg = newHV();
            (void)hv_stores(later_cfg, "task", task ? newSVsv(task) : newSVpvs("mail.send"));
            (void)hv_stores(cfg, "later", newRV_noinc((SV *)later_cfg));
        }
    }

    (void)hv_store(PM_PLUGIN_STATE, pkg, (I32)pl, newRV_inc((SV *)cfg), 0);

    pm_helper(aTHX_ app, "mail",          pm_h_mail,          cfg);
    pm_helper(aTHX_ app, "mail_later",    pm_h_mail_later,    cfg);
    pm_helper(aTHX_ app, "mail_template", pm_h_mail_template, cfg);
    pm_helper(aTHX_ app, "mail_url",      pm_h_mail_url,      cfg);
    pm_helper(aTHX_ app, "mail_token",    pm_h_mail_token,    cfg);

    {   /* at to_app: base from the host keyword, which may be declared after us */
        SV *mw = sv_2mortal(pm_closure(aTHX_ pm_mw, cfg, app));
        SvREFCNT_dec(pm_call(aTHX_ app, "middleware", &mw, 1));
    }
}

#endif /* PMAIL_PLUGIN_H */
