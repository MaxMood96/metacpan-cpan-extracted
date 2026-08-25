/* ptotp_plugin.h - Punk::Plugin::TOTP, the C half.
 *
 * Everything the plugin does at registration and per request lives here:
 * the helpers it installs on the context, the challenge routes, the
 * step-up guard, and the enrolment QR rendered through QR::Code's C ABI
 * (qr_abi.h) rather than a Perl call per enrolment. xs/plugin.xs is the
 * thin XS surface over it - register, state_for and _recovery_digest.
 *
 * Included from TOTP.xs AFTER the engine's static helpers (pt_alg_of,
 * pt_secret_of, pt_pairs ...), which it reuses directly: one dist, one
 * translation unit, one bootstrap.
 *
 * The configuration is an ordinary hash per application class, read at
 * each use rather than frozen into C integers - state_for hands it back,
 * and a test may localise a value in it and expect the next request to
 * see the change.
 */

#ifndef PTOTP_PLUGIN_H
#define PTOTP_PLUGIN_H

/* the kind recovery rows carry in the token table - fixed, not config:
 * a configurable kind is a second place the same decision lives */
#define PP_RKIND "totp_recovery"

/* the secret burned when an account has none: fixed bytes, so
 * verification costs the same whether 2FA is enabled or not */
static const unsigned char PP_DUMMY[] = "punk.totp.dummy.....";

/* per-class configuration: class name => { ... } */
static HV *PP_STATE = NULL;

/* ---- the QR::Code C ABI ---------------------------------------------------
 * Resolved once, at the first registration - so a box without QR::Code
 * fails at boot rather than at the first enrolment. svg_styled is a
 * version-2 member, hence the floor. */

#define PP_QR_NEED 2

static const qr_abi_t *PP_QR = NULL;

static void pp_qr_boot(pTHX)
{
    UV p = 0;
    dSP;

    if (PP_QR)
        return;
    ENTER; SAVETMPS;
    eval_pv("require QR::Code;", TRUE);
    PUSHMARK(SP); PUTBACK;
    if (call_pv("QR::Code::_abi_ptr", G_SCALAR | G_EVAL) > 0) {
        SPAGAIN;
        p = POPu;
        PUTBACK;
    }
    FREETMPS; LEAVE;

    PP_QR = p ? INT2PTR(const qr_abi_t *, p) : NULL;
    if (!PP_QR || PP_QR->version < PP_QR_NEED) {
        PP_QR = NULL;
        croak("Punk::Plugin::TOTP: QR::Code with qr_abi version %d or "
              "newer is required", PP_QR_NEED);
    }
}

/* ---- closures: a CV carrying captured SVs ---------------------------------
 * Slot 0 of the capture is a reference to the configuration hash. */

typedef struct { AV *cap; } pp_clos_t;

static int pp_clos_free(pTHX_ SV *sv, MAGIC *mg)
{
    pp_clos_t *c = (pp_clos_t *)mg->mg_ptr;
    PERL_UNUSED_ARG(sv);
    if (c) {
        if (c->cap) SvREFCNT_dec((SV *)c->cap);
        Safefree(c);
    }
    return 0;
}

static MGVTBL pp_clos_vtbl = { NULL, NULL, NULL, NULL, pp_clos_free,
                               NULL, NULL, NULL };

static SV *pp_closure(pTHX_ XSUBADDR_t body, HV *cfg)
{
    CV *cv = (CV *)newXS(NULL, body, (char *)__FILE__);
    AV *cap = newAV();
    pp_clos_t *c;

    av_push(cap, newRV_inc((SV *)cfg));
    Newxz(c, 1, pp_clos_t);
    c->cap = cap;
    sv_magicext((SV *)cv, NULL, PERL_MAGIC_ext, &pp_clos_vtbl, (char *)c, 0);
    return newRV_noinc((SV *)cv);
}

static HV *pp_cfg_of(pTHX_ CV *cv)
{
    MAGIC *mg = mg_findext((SV *)cv, PERL_MAGIC_ext, &pp_clos_vtbl);
    AV *cap = mg ? ((pp_clos_t *)mg->mg_ptr)->cap : NULL;
    SV **e = cap ? av_fetch(cap, 0, 0) : NULL;
    if (!(e && *e && SvROK(*e) && SvTYPE(SvRV(*e)) == SVt_PVHV))
        croak("Punk::Plugin::TOTP: a closure lost its configuration");
    return (HV *)SvRV(*e);
}

/* ---- calling back into Perl ----------------------------------------------
 * Every call is scalar context and hands back a NEW SV (+1) - a copy of
 * the result, undef when there was none - so a caller owns what it
 * holds and mortalises it. */

/* `threw`, when given, catches a die instead of letting it out: the only
 * caller that wants this is the attempt counter, which must not turn a
 * failed sign-in into a 500 on a database missing its columns. */
static SV *pp_call_common(pTHX_ SV *inv, const char *meth, SV *code,
                          SV **argv, int argc, int *threw)
{
    dSP;
    I32 flags = G_SCALAR | (threw ? G_EVAL : 0);
    int count, i;
    SV *ret;

    ENTER; SAVETMPS;
    PUSHMARK(SP);
    EXTEND(SP, argc + 1);
    if (inv) PUSHs(inv);
    for (i = 0; i < argc; i++) PUSHs(argv[i]);
    PUTBACK;
    if (code)      count = call_sv(code, flags);
    else if (inv)  count = call_method(meth, flags);
    else           count = call_pv(meth, flags);
    SPAGAIN;
    if (count > 0) {
        SV *top = POPs;
        ret = newSVsv(top);
    } else {
        ret = newSV(0);
    }
    if (threw) *threw = SvTRUE(ERRSV) ? 1 : 0;
    PUTBACK; FREETMPS; LEAVE;
    return ret;
}

/* $inv->$meth(@argv) */
static SV *pp_call(pTHX_ SV *inv, const char *meth, SV **argv, int argc)
{
    return pp_call_common(aTHX_ inv, meth, NULL, argv, argc, NULL);
}

/* $code->(@argv) */
static SV *pp_call_code(pTHX_ SV *code, SV **argv, int argc)
{
    return pp_call_common(aTHX_ NULL, NULL, code, argv, argc, NULL);
}

/* Punk::Auth::_await($c, $v) for a value that may be a future; a plain
 * value, or a Punk without the seam, passes straight through. */
static SV *pp_await_ev(pTHX_ SV *c, SV *v, int *threw)
{
    SV *argv[2];
    if (!v) return newSV(0);
    if (!SvROK(v) || !get_cv("Punk::Auth::_await", 0))
        return newSVsv(v);
    argv[0] = c;
    argv[1] = v;
    return pp_call_common(aTHX_ NULL, "Punk::Auth::_await", NULL, argv, 2, threw);
}

static SV *pp_await(pTHX_ SV *c, SV *v)
{
    return pp_await_ev(aTHX_ c, v, NULL);
}

static int pp_is_hash(SV *sv)
{
    return sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV;
}

static int pp_is_array(SV *sv)
{
    return sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV;
}

static SV *pp_hget(pTHX_ HV *h, const char *k)
{
    SV **e = hv_fetch(h, k, (I32)strlen(k), 0);
    return (e && *e && SvOK(*e)) ? *e : NULL;
}

/* ---- configuration --------------------------------------------------------- */

static IV pp_cfg_iv(pTHX_ HV *cfg, const char *k, IV dflt)
{
    SV *v = pp_hget(aTHX_ cfg, k);
    return v ? SvIV(v) : dflt;
}

/* a cfg value as an SV that is never NULL - the config is validated at
 * registration, so a missing key is a corrupted state hash */
static SV *pp_cfg_sv(pTHX_ HV *cfg, const char *k)
{
    SV *v = pp_hget(aTHX_ cfg, k);
    if (!v) croak("Punk::Plugin::TOTP: configuration lost '%s'", k);
    return v;
}

/* the column name behind a logical field (secret, counter, enabled,
 * email) */
static SV *pp_field(pTHX_ HV *cfg, const char *which)
{
    SV *f = pp_hget(aTHX_ cfg, "fields");
    SV *v = pp_is_hash(f) ? pp_hget(aTHX_ (HV *)SvRV(f), which) : NULL;
    if (!v) croak("Punk::Plugin::TOTP: configuration lost field '%s'", which);
    return v;
}

static SV *pp_user_get(pTHX_ HV *cfg, HV *user, const char *which)
{
    STRLEN nl;
    const char *np = SvPV_const(pp_field(aTHX_ cfg, which), nl);
    SV **e = hv_fetch(user, np, (I32)nl, 0);
    return (e && *e && SvOK(*e)) ? *e : NULL;
}

/* $c->model($cfg{$which}), mortal */
static SV *pp_model(pTHX_ HV *cfg, SV *c, const char *which)
{
    SV *name = pp_cfg_sv(aTHX_ cfg, which);
    return sv_2mortal(pp_call(aTHX_ c, "model", &name, 1));
}

/* ---- the session ---------------------------------------------------------- */

static HV *pp_session(pTHX_ SV *c)
{
    SV *s = sv_2mortal(pp_call(aTHX_ c, "session", NULL, 0));
    if (!pp_is_hash(s))
        croak("Punk::Plugin::TOTP needs the session keyword");
    return (HV *)SvRV(s);
}

/* the pending marker while it is live; an expired one is removed, so a
 * stale half-state cannot be resumed */
static HV *pp_pending(pTHX_ SV *c)
{
    HV *s = pp_session(aTHX_ c);
    SV **e = hv_fetchs(s, "totp_pending", 0);
    SV *exp;
    if (!(e && *e && pp_is_hash(*e)))
        return NULL;
    exp = pp_hget(aTHX_ (HV *)SvRV(*e), "exp");
    if (exp && (NV)time(NULL) < SvNV(exp))
        return (HV *)SvRV(*e);
    (void)hv_delete(s, "totp_pending", 12, G_DISCARD);
    return NULL;
}

static void pp_set_pending(pTHX_ HV *cfg, HV *s, SV *id, SV *to)
{
    HV *p = newHV();
    (void)hv_stores(p, "id",    newSVsv(id));
    (void)hv_stores(p, "exp",   newSViv((IV)time(NULL)
                                        + pp_cfg_iv(aTHX_ cfg, "pending_ttl", 300)));
    (void)hv_stores(p, "to",    (to && SvOK(to)) ? newSVsv(to) : newSVpvs("/"));
    (void)hv_stores(s, "totp_pending", newRV_noinc((SV *)p));
}

/* ---- the attempt counter ---------------------------------------------------
 *
 * On the user row, and NOT in the session, which is the whole point: a Punk
 * session without a store is a signed cookie and nothing more, so a client
 * that keeps a copy from before its failures and presents it again gets its
 * counter back and the limit never fires. Counting in state the client holds
 * is counting in state the client chooses.
 *
 * Per account rather than per pending marker for the same reason one level
 * up: re-running the password step mints a fresh marker, so a per-marker
 * count never bounded guessing of the second factor either - it only made an
 * attacker repeat a step they had already passed.
 *
 * The window makes it self-healing. A permanent lock would hand anyone who
 * knows a password a way to keep the account's owner out for good, which is
 * a worse bargain than the guessing it prevents. */

static IV pp_user_iv(pTHX_ HV *cfg, HV *uh, const char *which)
{
    SV *v = pp_user_get(aTHX_ cfg, uh, which);
    return v ? SvIV(v) : 0;
}

/* the failures that still count: a window that has lapsed counts as none */
static IV pp_fail_count(pTHX_ HV *cfg, HV *uh)
{
    IV n  = pp_user_iv(aTHX_ cfg, uh, "failed");
    IV at = pp_user_iv(aTHX_ cfg, uh, "failed_at");
    IV w  = pp_cfg_iv(aTHX_ cfg, "attempt_window", 900);
    if (n <= 0) return 0;
    if (at && (IV)time(NULL) - at >= w) return 0;
    return n;
}

/* said once per process: a limit that is silently not running is the bug
 * this release exists to fix, so it does not get to be quiet */
static void pp_counter_broken(pTHX)
{
    static int said = 0;
    if (said) return;
    said = 1;
    warn("Punk::Plugin::TOTP: the second-factor attempt count could not be "
         "written to the user row - the user table needs the totp_failed and "
         "totp_failed_at columns (or whatever `fields` names them). Every "
         "failed attempt un-answers the first factor until it does.");
}

/* write columns to the user row, mirroring them into the hash the caller
 * holds; 0 when the write did not land */
static int pp_user_write(pTHX_ HV *cfg, SV *c, HV *uh,
                         const char *const *which, IV *vals, int n)
{
    SV *model = pp_model(aTHX_ cfg, c, "model");
    HV *data  = newHV();
    SV *dref, *ret, *id = pp_hget(aTHX_ uh, "id");
    int i, threw = 0;

    (void)hv_stores(data, "id", id ? newSVsv(id) : newSV(0));
    for (i = 0; i < n; i++) {
        STRLEN fl;
        const char *fp = SvPV_const(pp_field(aTHX_ cfg, which[i]), fl);
        (void)hv_store(data, fp, (I32)fl, newSViv(vals[i]), 0);
    }
    dref = sv_2mortal(newRV_noinc((SV *)data));
    ret  = pp_call_common(aTHX_ model, "update", NULL, &dref, 1, &threw);
    if (!threw && SvROK(ret))
        SvREFCNT_dec(pp_await_ev(aTHX_ c, ret, &threw));
    SvREFCNT_dec(ret);
    if (threw) {
        pp_counter_broken(aTHX);
        return 0;
    }
    for (i = 0; i < n; i++) {
        STRLEN fl;
        const char *fp = SvPV_const(pp_field(aTHX_ cfg, which[i]), fl);
        (void)hv_store(uh, fp, (I32)fl, newSViv(vals[i]), 0);
    }
    return 1;
}

static const char *const PP_FAILF[2] = { "failed", "failed_at" };

static int pp_fail_bump(pTHX_ HV *cfg, SV *c, HV *uh, IV n)
{
    IV vals[2];
    vals[0] = n + 1;
    vals[1] = (IV)time(NULL);
    return pp_user_write(aTHX_ cfg, c, uh, PP_FAILF, vals, 2);
}

static void pp_fail_clear(pTHX_ HV *cfg, SV *c, HV *uh)
{
    IV vals[2];
    /* nothing to clear: the pass costs no write on the ordinary path */
    if (!pp_user_iv(aTHX_ cfg, uh, "failed")
        && !pp_user_iv(aTHX_ cfg, uh, "failed_at"))
        return;
    vals[0] = 0;
    vals[1] = 0;
    (void)pp_user_write(aTHX_ cfg, c, uh, PP_FAILF, vals, 2);
}

static SV *pp_redirect(pTHX_ SV *c, SV *where)
{
    return pp_call(aTHX_ c, "redirect", &where, 1);
}

/* ---- the recovery digest --------------------------------------------------
 * Case folded and grouping stripped before digesting: people type what
 * the drawer's paper shows, in whatever case their keyboard chose.
 * Lowercase sha256 hex - pwd_token_digest's wire form - so the rows are
 * interchangeable with the auth battery's own tokens. */

static SV *pp_recovery_digest(pTHX_ SV *code)
{
    static const char hexd[] = "0123456789abcdef";
    STRLEN n, i, j = 0;
    const char *p = SvPV_const(code, n);
    const frh_algo_t *a = PT_FRH->algo_by_id(PT_ALGS[1].frh_id);
    unsigned char sum[64];
    char hex[129];
    char *buf;

    Newx(buf, n + 1, char);
    SAVEFREEPV(buf);
    for (i = 0; i < n; i++) {
        unsigned char ch = (unsigned char)p[i];
        if (isSPACE(ch) || ch == '-') continue;
        buf[j++] = (char)toUPPER(ch);
    }
    if (!a || a->digest_size > sizeof sum
        || PT_FRH->digest(a->id, (const unsigned char *)buf, j, sum) != 0)
        croak("Punk::Plugin::TOTP: sha256 failed");
    for (i = 0; i < a->digest_size; i++) {
        hex[2 * i]     = hexd[sum[i] >> 4];
        hex[2 * i + 1] = hexd[sum[i] & 15];
    }
    return newSVpvn(hex, a->digest_size * 2);
}

/* ---- the enrolment QR, through qr_abi -------------------------------------
 * The same option surface QR::Code->svg takes - ecc, version, quiet, logo,
 * style - mapped onto the ABI's structs, with H as the default level: an
 * enrolment QR is scanned once, from a screen, by every phone the user
 * will ever own, so it gets maximum margin. */

static int pp_ecc_of(pTHX_ SV *sv, int dflt)
{
    STRLEN n;
    const char *p;
    if (!sv) return dflt;
    p = SvPV_const(sv, n);
    if (n == 1)
        switch (*p) {
        case 'L': case 'l': return QR_ABI_ECC_L;
        case 'M': case 'm': return QR_ABI_ECC_M;
        case 'Q': case 'q': return QR_ABI_ECC_Q;
        case 'H': case 'h': return QR_ABI_ECC_H;
        }
    croak("ecc must be L, M, Q or H, not '%.*s'", (int)n, p);
    return -1;
}

static int pp_range_of(pTHX_ SV *sv, const char *what, IV lo, IV hi, int dflt)
{
    IV v;
    if (!sv) return dflt;
    v = SvIV(sv);
    if (v < lo || v > hi)
        croak("%s must be %" IVdf " to %" IVdf ", not %" IVdf, what, lo, hi, v);
    return (int)v;
}

static void pp_color_copy(pTHX_ SV *sv, char *dst, size_t dstlen)
{
    STRLEN n;
    const char *p = SvPV_const(sv, n);
    if (n >= dstlen) n = dstlen - 1;
    memcpy(dst, p, n);
    dst[n] = '\0';
}

static SV *pp_slurp(pTHX_ const char *path)
{
    PerlIO *f = PerlIO_open(path, "rb");
    SV *out;
    char buf[65536];
    SSize_t n;
    if (!f) croak("logo file '%s': %s", path, Strerror(errno));
    out = sv_2mortal(newSVpvs(""));
    while ((n = PerlIO_read(f, buf, sizeof buf)) > 0)
        sv_catpvn(out, buf, (STRLEN)n);
    PerlIO_close(f);
    return out;
}

/* Fills *lg. The bytes it borrows belong to SVs that live to the end of
 * the XSUB, which outlives the render. */
static void pp_logo_of(pTHX_ SV *sv, qr_abi_logo_t *lg)
{
    static const char *const ok[] =
        { "text", "svg", "image", "file", "scale", "em" };
    HV *h;
    SV *text, *markup, *image, *file, *bytes;
    STRLEN n;

    memset(lg, 0, sizeof *lg);
    lg->size = sizeof *lg;

    if (!SvROK(sv)) {
        lg->text = SvPV_const(sv, n);
        lg->text_len = n;
        if (!n) croak("logo text is empty");
        lg->kind = QR_ABI_LOGO_TEXT;
        return;
    }
    if (!pp_is_hash(sv))
        croak("logo must be a string or a hashref");
    h = (HV *)SvRV(sv);
    pt_check_keys(aTHX_ "logo", h, ok, 6);

    text   = pp_hget(aTHX_ h, "text");
    markup = pp_hget(aTHX_ h, "svg");
    image  = pp_hget(aTHX_ h, "image");
    file   = pp_hget(aTHX_ h, "file");
    if (!!text + !!markup + !!image + !!file != 1)
        croak("logo needs exactly one of text, svg, image or file");
    {
        SV *v;
        if ((v = pp_hget(aTHX_ h, "scale"))) lg->scale = SvNV(v);
        if ((v = pp_hget(aTHX_ h, "em")))    lg->em    = SvNV(v);
    }
    if (text) {
        lg->text = SvPV_const(text, n);
        lg->text_len = n;
        if (!n) croak("logo text is empty");
        lg->kind = QR_ABI_LOGO_TEXT;
        return;
    }
    if (markup) {
        lg->markup = SvPV_const(markup, n);
        lg->markup_len = n;
        lg->kind = QR_ABI_LOGO_SVG;
        return;
    }

    /* image bytes, or a file holding any of the three formats; the
     * format comes from the bytes, never from the name */
    bytes = image ? image : pp_slurp(aTHX_ SvPV_nolen_const(file));
    {
        const unsigned char *p = (const unsigned char *)SvPVbyte(bytes, n);
        STRLEN i = 0;
        if (n >= 8 && memcmp(p, "\x89PNG\r\n\x1a\n", 8) == 0) {
            lg->kind = QR_ABI_LOGO_IMAGE; lg->img = p; lg->img_len = n;
            lg->img_fmt = QR_ABI_IMG_PNG;
            return;
        }
        if (n >= 3 && p[0] == 0xFF && p[1] == 0xD8 && p[2] == 0xFF) {
            lg->kind = QR_ABI_LOGO_IMAGE; lg->img = p; lg->img_len = n;
            lg->img_fmt = QR_ABI_IMG_JPEG;
            return;
        }
        while (i < n && isSPACE(p[i])) i++;
        if (i < n && p[i] == '<') {
            lg->kind = QR_ABI_LOGO_SVG;
            lg->markup = (const char *)p;
            lg->markup_len = n;
            return;
        }
        croak("logo image must be PNG, JPEG or SVG");
    }
}

static void pp_style_of(pTHX_ SV *sv, qr_abi_style_t *st)
{
    static const char *const ok[] =
        { "shape", "radius", "finder", "dark", "light", "finder_dark",
          "gradient" };
    HV *h;
    SV *v;

    memset(st, 0, sizeof *st);
    st->size = sizeof *st;
    if (!pp_is_hash(sv)) croak("style must be a hashref");
    h = (HV *)SvRV(sv);
    pt_check_keys(aTHX_ "style", h, ok, 7);

    if ((v = pp_hget(aTHX_ h, "shape"))) {
        const char *p = SvPV_nolen_const(v);
        if      (strEQ(p, "square"))  st->shape = QR_ABI_SHAPE_SQUARE;
        else if (strEQ(p, "rounded")) st->shape = QR_ABI_SHAPE_ROUNDED;
        else if (strEQ(p, "dot"))     st->shape = QR_ABI_SHAPE_DOT;
        else croak("style shape must be square, rounded or dot, not '%s'", p);
    }
    if ((v = pp_hget(aTHX_ h, "finder"))) {
        const char *p = SvPV_nolen_const(v);
        if      (strEQ(p, "square"))  st->finder = QR_ABI_FINDER_SQUARE;
        else if (strEQ(p, "rounded")) st->finder = QR_ABI_FINDER_ROUNDED;
        else if (strEQ(p, "circle"))  st->finder = QR_ABI_FINDER_CIRCLE;
        else croak("style finder must be square, rounded or circle, "
                   "not '%s'", p);
    }
    if ((v = pp_hget(aTHX_ h, "radius")))      st->radius = SvNV(v);
    if ((v = pp_hget(aTHX_ h, "dark")))        pp_color_copy(aTHX_ v, st->dark, sizeof st->dark);
    if ((v = pp_hget(aTHX_ h, "light")))       pp_color_copy(aTHX_ v, st->light, sizeof st->light);
    if ((v = pp_hget(aTHX_ h, "finder_dark"))) pp_color_copy(aTHX_ v, st->finder_dark, sizeof st->finder_dark);

    if ((v = pp_hget(aTHX_ h, "gradient"))) {
        static const char *const gok[] = { "type", "angle", "stops" };
        HV *g;
        SV *t, *stops;
        if (!pp_is_hash(v)) croak("style gradient must be a hashref");
        g = (HV *)SvRV(v);
        pt_check_keys(aTHX_ "gradient", g, gok, 3);
        if ((t = pp_hget(aTHX_ g, "type"))) {
            const char *p = SvPV_nolen_const(t);
            if      (strEQ(p, "none"))   st->grad_type = QR_ABI_GRAD_NONE;
            else if (strEQ(p, "linear")) st->grad_type = QR_ABI_GRAD_LINEAR;
            else if (strEQ(p, "radial")) st->grad_type = QR_ABI_GRAD_RADIAL;
            else croak("gradient type must be none, linear or radial, "
                       "not '%s'", p);
        }
        if ((t = pp_hget(aTHX_ g, "angle"))) st->grad_angle = SvNV(t);
        if ((stops = pp_hget(aTHX_ g, "stops"))) {
            AV *av;
            SSize_t i, n;
            if (!pp_is_array(stops)) croak("gradient stops must be an arrayref");
            av = (AV *)SvRV(stops);
            n = av_len(av) + 1;
            if (n > QR_ABI_MAX_STOPS)
                croak("gradient takes at most %d stops", QR_ABI_MAX_STOPS);
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                if (e && *e && SvOK(*e))
                    pp_color_copy(aTHX_ *e, st->stops[i], sizeof st->stops[i]);
            }
            st->nstops = (int)n;
        }
    }
}

/* the otpauth:// URI as an SVG document (+1) */
static SV *pp_render_qr(pTHX_ SV *uri, HV *opt)
{
    static const char *const ok[] = { "ecc", "version", "quiet", "logo", "style" };
    qr_abi_style_t st;
    qr_abi_logo_t  lg;
    SV *osv;
    int ecc, version, quiet, has_logo = 0, has_style = 0;
    STRLEN n;
    const unsigned char *data;
    char err[256];
    char *out;
    SV *svg;

    pp_qr_boot(aTHX);
    pt_check_keys(aTHX_ "totp_qr", opt, ok, 5);

    if ((osv = pp_hget(aTHX_ opt, "logo"))) {
        /* a logo is erasures, and erasures need budget: Q or H only */
        ecc = pp_ecc_of(aTHX_ pp_hget(aTHX_ opt, "ecc"), QR_ABI_ECC_H);
        if (ecc < QR_ABI_ECC_Q)
            croak("a centre logo needs ECC level Q or H");
        pp_logo_of(aTHX_ osv, &lg);
        has_logo = 1;
    } else {
        ecc = pp_ecc_of(aTHX_ pp_hget(aTHX_ opt, "ecc"), QR_ABI_ECC_H);
    }
    if ((osv = pp_hget(aTHX_ opt, "style"))) {
        pp_style_of(aTHX_ osv, &st);
        has_style = 1;
    }
    version = pp_range_of(aTHX_ pp_hget(aTHX_ opt, "version"), "version", 1, 15, 0);
    quiet   = pp_range_of(aTHX_ pp_hget(aTHX_ opt, "quiet"),   "quiet",   0, 16, 4);

    data = (const unsigned char *)SvPVbyte(uri, n);
    err[0] = '\0';
    out = PP_QR->svg_styled(data, (int)n, ecc, version, quiet,
                            has_style ? &st : NULL,
                            has_logo  ? &lg : NULL,
                            NULL, err, sizeof err);
    if (!out)
        croak("totp_qr: %s", err[0] ? err : "QR::Code could not render the symbol");
    svg = newSVpv(out, 0);
    PP_QR->free_fn(out);
    return svg;
}

/* ---- the helpers ------------------------------------------------------------
 * Each is an XS closure over the configuration, installed on the context
 * through $app->helper. ST(0) is the context. */

/* $c->totp_secret */
XS_INTERNAL(pp_h_secret);
XS_INTERNAL(pp_h_secret)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    const pt_alg_t *alg = pt_alg_of(aTHX_ pp_hget(aTHX_ cfg, "algorithm"));
    unsigned char raw[64];
    char b32[((sizeof raw + 4) / 5) * 8 + 1];
    PERL_UNUSED_VAR(items);

    if (ptotp_random_bytes(raw, alg->secret_bytes) != 0)
        croak("Punk::TOTP: the entropy source failed; refusing to degrade");
    ptotp_b32_encode(b32, raw, alg->secret_bytes);
    ST(0) = sv_2mortal(newSVpv(b32, 0));
    XSRETURN(1);
}

/* the otpauth:// URI (+1): issuer and parameters from config, account
 * from %opt or the signed-in user's email */
static SV *pp_uri(pTHX_ HV *cfg, SV *c, SV *secret, HV *opt)
{
    AV *args = (AV *)sv_2mortal((SV *)newAV());
    SV *account = NULL;
    SV *v;
    SV *klass = sv_2mortal(newSVpvs("Punk::TOTP"));
    HE *he;

    if ((v = pp_hget(aTHX_ opt, "account"))) {
        account = sv_2mortal(newSVsv(v));
        (void)hv_delete(opt, "account", 7, G_DISCARD);
    }
    if (!account) {
        SV *user = sv_2mortal(pp_call(aTHX_ c, "current_user", NULL, 0));
        SV *em = pp_is_hash(user)
                 ? pp_user_get(aTHX_ cfg, (HV *)SvRV(user), "email") : NULL;
        if (em) account = sv_2mortal(newSVsv(em));
    }
    if (!account)
        croak("totp_uri needs an account (or a signed-in user with an email)");

    av_push(args, newSVsv(secret));
    av_push(args, newSVpvs("issuer"));    av_push(args, newSVsv(pp_cfg_sv(aTHX_ cfg, "issuer")));
    av_push(args, newSVpvs("account"));   av_push(args, newSVsv(account));
    av_push(args, newSVpvs("algorithm")); av_push(args, newSVsv(pp_cfg_sv(aTHX_ cfg, "algorithm")));
    av_push(args, newSVpvs("digits"));    av_push(args, newSVsv(pp_cfg_sv(aTHX_ cfg, "digits")));
    av_push(args, newSVpvs("period"));    av_push(args, newSVsv(pp_cfg_sv(aTHX_ cfg, "period")));
    hv_iterinit(opt);
    while ((he = hv_iternext(opt))) {
        av_push(args, newSVsv(hv_iterkeysv(he)));
        av_push(args, newSVsv(hv_iterval(opt, he)));
    }
    return pp_call(aTHX_ klass, "uri", AvARRAY(args), (int)(av_len(args) + 1));
}

/* $c->totp_uri($secret, %opt) */
XS_INTERNAL(pp_h_uri);
XS_INTERNAL(pp_h_uri)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    HV *opt;
    if (items < 2) croak("totp_uri takes a secret");
    opt = pt_pairs(aTHX_ "totp_uri", &ST(0), 2, items);
    ST(0) = sv_2mortal(pp_uri(aTHX_ cfg, ST(0), ST(1), opt));
    XSRETURN(1);
}

/* $c->totp_qr($secret, %opt) */
XS_INTERNAL(pp_h_qr);
XS_INTERNAL(pp_h_qr)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    HV *opt, *uri_opt;
    SV *v, *uri;
    if (items < 2) croak("totp_qr takes a secret");
    opt     = pt_pairs(aTHX_ "totp_qr", &ST(0), 2, items);
    uri_opt = (HV *)sv_2mortal((SV *)newHV());
    if ((v = pp_hget(aTHX_ opt, "account"))) {
        (void)hv_stores(uri_opt, "account", newSVsv(v));
        (void)hv_delete(opt, "account", 7, G_DISCARD);
    }
    uri = sv_2mortal(pp_uri(aTHX_ cfg, ST(0), ST(1), uri_opt));
    ST(0) = sv_2mortal(pp_render_qr(aTHX_ uri, opt));
    XSRETURN(1);
}

/* $c->totp_verify($user, $code) */
XS_INTERNAL(pp_h_verify);
XS_INTERNAL(pp_h_verify)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    SV *c, *user, *code, *secret, *last;
    HV *uh;
    const pt_alg_t *alg;
    int digits;
    unsigned period, skew;
    STRLEN cn = 0;
    const char *cp = "";
    ptotp_u64 now, lastc, matched = 0;
    unsigned char *sec;
    size_t slen;

    if (items < 2 || !pp_is_hash(ST(1)))
        croak("totp_verify takes a user hashref and a code");
    c    = ST(0);
    user = ST(1);
    code = items > 2 ? ST(2) : NULL;
    uh   = (HV *)SvRV(user);

    alg    = pt_alg_of(aTHX_ pp_hget(aTHX_ cfg, "algorithm"));
    digits = (int)pp_cfg_iv(aTHX_ cfg, "digits", 6);
    period = (unsigned)pp_cfg_iv(aTHX_ cfg, "period", 30);
    skew   = (unsigned)pp_cfg_iv(aTHX_ cfg, "skew", 1);
    now    = (ptotp_u64)time(NULL);
    if (code && SvOK(code)) cp = SvPV_const(code, cn);

    secret = pp_user_get(aTHX_ cfg, uh, "secret");
    if (!secret || !SvCUR(secret)) {
        /* equal work, then refuse: response time must not report
         * whether this account has 2FA enabled */
        (void)ptotp_verify(PT_FRH, alg->frh_id, PP_DUMMY, sizeof PP_DUMMY - 1,
                           now, period, digits, cp, (size_t)cn, skew,
                           (ptotp_u64)-1, &matched);
        XSRETURN_IV(0);
    }

    sec   = pt_secret_of(aTHX_ secret, &slen);
    last  = pp_user_get(aTHX_ cfg, uh, "counter");
    lastc = last ? (ptotp_u64)SvNV(last) : (ptotp_u64)-1;
    if (!ptotp_verify(PT_FRH, alg->frh_id, sec, slen, now, period, digits,
                      cp, (size_t)cn, skew, lastc, &matched))
        XSRETURN_IV(0);

    {   /* the counter write IS the replay protection; without it a
         * shoulder-surfed code stays valid for the rest of its window */
        SV *model = pp_model(aTHX_ cfg, c, "model");
        HV *data  = newHV();
        SV *dref, *ret, *id;
        STRLEN fl;
        const char *fp = SvPV_const(pp_field(aTHX_ cfg, "counter"), fl);
        id = pp_hget(aTHX_ uh, "id");
        (void)hv_stores(data, "id", id ? newSVsv(id) : newSV(0));
        (void)hv_store(data, fp, (I32)fl, newSVnv((NV)matched), 0);
        dref = sv_2mortal(newRV_noinc((SV *)data));
        ret  = pp_call(aTHX_ model, "update", &dref, 1);
        if (SvROK(ret)) SvREFCNT_dec(pp_await(aTHX_ c, ret));
        SvREFCNT_dec(ret);
        (void)hv_store(uh, fp, (I32)fl, newSVnv((NV)matched), 0);
    }
    XSRETURN_IV(1);
}

/* $c->totp_recovery_codes($user, count => $n) */
XS_INTERNAL(pp_h_recovery_codes);
XS_INTERNAL(pp_h_recovery_codes)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    SV *c, *id, *m, *v, *res, *rows;
    HV *opt;
    IV n = 10, i;
    AV *codes;

    if (items < 2 || !pp_is_hash(ST(1))
        || !(id = pp_hget(aTHX_ (HV *)SvRV(ST(1)), "id")))
        croak("totp_recovery_codes takes a user hashref");
    c   = ST(0);
    opt = pt_pairs(aTHX_ "totp_recovery_codes", &ST(0), 2, items);
    if ((v = pp_hget(aTHX_ opt, "count"))) n = SvIV(v);
    if (n < 1 || n > 20) croak("count must be 1 to 20");

    m = pp_model(aTHX_ cfg, c, "recovery_model");

    {   /* a new set revokes the old set: partial invalidation is how a
         * drawer ends up holding codes that half-work */
        HV *f = newHV();
        SV *fref;
        (void)hv_stores(f, "user_id", newSVsv(id));
        (void)hv_stores(f, "kind", newSVpvs(PP_RKIND));
        fref = sv_2mortal(newRV_noinc((SV *)f));
        res  = sv_2mortal(pp_await(aTHX_ c,
                   sv_2mortal(pp_call(aTHX_ m, "search", &fref, 1))));
        rows = pp_is_hash(res) ? pp_hget(aTHX_ (HV *)SvRV(res), "rows") : NULL;
        if (pp_is_array(rows)) {
            AV *av = (AV *)SvRV(rows);
            SSize_t ri, rn = av_len(av) + 1;
            for (ri = 0; ri < rn; ri++) {
                SV **e = av_fetch(av, ri, 0);
                SV *rid = (e && *e && pp_is_hash(*e))
                          ? pp_hget(aTHX_ (HV *)SvRV(*e), "id") : NULL;
                SV *argv[2];
                if (!rid) continue;
                argv[0] = sv_2mortal(newSVpvs("id"));
                argv[1] = rid;
                SvREFCNT_dec(pp_await(aTHX_ c,
                    sv_2mortal(pp_call(aTHX_ m, "delete", argv, 2))));
            }
        }
    }

    codes = newAV();
    for (i = 0; i < n; i++) {
        /* 16 base32 symbols (80 bits) in an alphabet with no 0/1/8/9 to
         * mistype, grouped for humans */
        unsigned char raw[16];
        char b32[((sizeof raw + 4) / 5) * 8 + 1];
        SV *code, *digest, *rref;
        HV *row;
        if (ptotp_random_bytes(raw, sizeof raw) != 0)
            croak("Punk::TOTP: the entropy source failed; refusing to degrade");
        ptotp_b32_encode(b32, raw, sizeof raw);
        code = newSVpvn(b32, 8);
        sv_catpvs(code, "-");
        sv_catpvn(code, b32 + 8, 8);
        av_push(codes, code);

        digest = pp_recovery_digest(aTHX_ code);
        row = newHV();
        (void)hv_stores(row, "user_id", newSVsv(id));
        (void)hv_stores(row, "kind",    newSVpvs(PP_RKIND));
        (void)hv_stores(row, "digest",  digest);
        (void)hv_stores(row, "expires", newSViv(0));   /* a drawer has no clock */
        rref = sv_2mortal(newRV_noinc((SV *)row));
        SvREFCNT_dec(pp_await(aTHX_ c,
            sv_2mortal(pp_call(aTHX_ m, "create", &rref, 1))));
    }
    ST(0) = sv_2mortal(newRV_noinc((SV *)codes));
    XSRETURN(1);
}

/* $c->totp_use_recovery($user, $code) */
XS_INTERNAL(pp_h_use_recovery);
XS_INTERNAL(pp_h_use_recovery)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    SV *c, *code, *id, *m, *res, *rows, *row, *rid, *gone, *v;
    HV *f, *rh;
    SV *fref, *argv[2];

    if (items < 2 || !pp_is_hash(ST(1))
        || !(id = pp_hget(aTHX_ (HV *)SvRV(ST(1)), "id")))
        croak("totp_use_recovery takes a user hashref and a code");
    c    = ST(0);
    code = items > 2 ? ST(2) : NULL;
    if (!(code && SvOK(code) && SvCUR(code))) XSRETURN_IV(0);

    m = pp_model(aTHX_ cfg, c, "recovery_model");
    f = newHV();
    (void)hv_stores(f, "digest", pp_recovery_digest(aTHX_ code));
    /* scoped to the challenged account: a search on the digest alone walks
     * every user's rows, which leaves the ownership test below as the only
     * thing binding a code to the account it was issued to */
    (void)hv_stores(f, "user_id", newSVsv(id));
    fref = sv_2mortal(newRV_noinc((SV *)f));
    res  = sv_2mortal(pp_await(aTHX_ c,
               sv_2mortal(pp_call(aTHX_ m, "search", &fref, 1))));
    rows = pp_is_hash(res) ? pp_hget(aTHX_ (HV *)SvRV(res), "rows") : NULL;
    if (!pp_is_array(rows) || av_len((AV *)SvRV(rows)) < 0) XSRETURN_IV(0);
    row = *av_fetch((AV *)SvRV(rows), 0, 0);
    if (!pp_is_hash(row)) XSRETURN_IV(0);
    rh  = (HV *)SvRV(row);
    rid = pp_hget(aTHX_ rh, "id");
    if (!rid) XSRETURN_IV(0);

    /* THE ORDER IS THE FEATURE: delete first, validate after. A code is
     * spent whether or not it turns out valid, so a wrong-kind probe
     * burns the row it hit rather than leaving it live for its real
     * endpoint - take_token's discipline. */
    argv[0] = sv_2mortal(newSVpvs("id"));
    argv[1] = rid;
    gone = sv_2mortal(pp_await(aTHX_ c,
               sv_2mortal(pp_call(aTHX_ m, "delete", argv, 2))));
    if (!SvTRUE(gone)) XSRETURN_IV(0);                 /* raced; the other take won */
    v = pp_hget(aTHX_ rh, "kind");
    if (!v || !strEQ(SvPV_nolen_const(v), PP_RKIND)) XSRETURN_IV(0);
    /* as bytes, not as integers: a user model may be keyed on a username, an
     * email address or a UUID, and every one of those coerces to 0, which
     * makes any two of them compare equal - one account's recovery code then
     * passes another account's challenge. The filter above should mean this
     * never fires; it stays because a model that ignores a filter key must
     * not be the difference between accounts. */
    v = pp_hget(aTHX_ rh, "user_id");
    if (!v || !sv_eq(v, id)) XSRETURN_IV(0);
    v = pp_hget(aTHX_ rh, "expires");
    if (v && SvIV(v) && SvIV(v) < (IV)time(NULL)) XSRETURN_IV(0);
    XSRETURN_IV(1);
}

/* ---- the auth seam -----------------------------------------------------------
 * A half-authenticated session writes `totp_pending` and NOT the auth
 * session key. That is the whole mechanism: the auth battery reads
 * exactly one key, so a pending session has no identity as far as every
 * existing auth_guard is concerned. */

/* $c->totp_challenge($user, to => $path) */
XS_INTERNAL(pp_h_challenge);
XS_INTERNAL(pp_h_challenge)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    SV *c, *id;
    HV *opt, *s;

    if (items < 2 || !pp_is_hash(ST(1))
        || !(id = pp_hget(aTHX_ (HV *)SvRV(ST(1)), "id")))
        croak("totp_challenge takes a user hashref");
    c   = ST(0);
    opt = pt_pairs(aTHX_ "totp_challenge", &ST(0), 2, items);
    s   = pp_session(aTHX_ c);
    pp_set_pending(aTHX_ cfg, s, id, pp_hget(aTHX_ opt, "to"));
    ST(0) = sv_2mortal(pp_redirect(aTHX_ c, pp_cfg_sv(aTHX_ cfg, "challenge_path")));
    XSRETURN(1);
}

/* $c->totp_complete: the marker becomes a login */
XS_INTERNAL(pp_h_complete);
XS_INTERNAL(pp_h_complete)
{
    dXSARGS;
    SV *c, *pref, *id, *to, *can, *name;
    HV *s, *p;
    SV **e;

    if (items < 1) croak("totp_complete takes the context");
    c = ST(0);
    s = pp_session(aTHX_ c);
    e = hv_fetchs(s, "totp_pending", 0);
    if (!(e && *e && pp_is_hash(*e))) XSRETURN_UNDEF;
    pref = sv_2mortal(newSVsv(*e));           /* keeps the hash alive */
    (void)hv_delete(s, "totp_pending", 12, G_DISCARD);
    p  = (HV *)SvRV(pref);
    id = pp_hget(aTHX_ p, "id");
    to = pp_hget(aTHX_ p, "to");

    if (id) SvREFCNT_dec(pp_call(aTHX_ c, "login", &id, 1));
    s = pp_session(aTHX_ c);                  /* login may have replaced it */
    (void)hv_stores(s, "totp_at", newSViv((IV)time(NULL)));

    /* the moment the second factor passes is where rotation belongs:
     * with a session store this closes the fixation window; without one
     * it is Punk's documented no-op, and before 0.26 it does not exist */
    name = sv_2mortal(newSVpvs("session_rotate"));
    can  = sv_2mortal(pp_call(aTHX_ c, "can", &name, 1));
    if (SvTRUE(can)) SvREFCNT_dec(pp_call(aTHX_ c, "session_rotate", NULL, 0));

    ST(0) = to ? sv_2mortal(newSVsv(to)) : &PL_sv_undef;
    XSRETURN(1);
}

/* ---- the challenge route -------------------------------------------------- */

/* the challenge page: whatever `render` names, or the self-contained
 * default so the plugin works out of the box */
static SV *pp_render(pTHX_ HV *cfg, SV *c, int error)
{
    SV *r = pp_hget(aTHX_ cfg, "render");
    SV *errsv = sv_2mortal(newSViv(error ? 1 : 0));
    if (r) {
        if (SvROK(r) && SvTYPE(SvRV(r)) == SVt_PVCV) {
            SV *argv[2];
            argv[0] = c;
            argv[1] = errsv;
            return pp_call_code(aTHX_ r, argv, 2);
        }
        return pp_call(aTHX_ c, SvPV_nolen_const(r), &errsv, 1);
    }
    {
        SV *html = sv_2mortal(newSVpvs(
            "<!doctype html><title>Two-factor code</title>\n"
            "<h1>Enter your code</h1>"));
        if (error)
            sv_catpvs(html, "<p class=\"error\">That code did not work. "
                            "Try again, or use a recovery code.</p>");
        sv_catpvs(html, "\n<form method=\"post\" action=\"");
        sv_catsv(html, pp_cfg_sv(aTHX_ cfg, "challenge_path"));
        sv_catpvs(html, "\">\n"
            "<input name=\"code\" autofocus autocomplete=\"one-time-code\"\n"
            "       inputmode=\"numeric\" pattern=\"[0-9A-Za-z-]*\">\n"
            "<button>Verify</button>\n"
            "</form>\n");
        return pp_call(aTHX_ c, "html", &html, 1);
    }
}

/* GET challenge_path */
XS_INTERNAL(pp_r_get);
XS_INTERNAL(pp_r_get)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    SV *c;
    if (items < 1) XSRETURN_EMPTY;
    c = ST(0);
    if (!pp_pending(aTHX_ c)) {
        ST(0) = sv_2mortal(pp_redirect(aTHX_ c, pp_cfg_sv(aTHX_ cfg, "login_path")));
        XSRETURN(1);
    }
    ST(0) = sv_2mortal(pp_render(aTHX_ cfg, c, 0));
    XSRETURN(1);
}

/* POST challenge_path */
XS_INTERNAL(pp_r_post);
XS_INTERNAL(pp_r_post)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    SV *c, *id, *model, *user, *code, *ok, *argv[2], *name;
    HV *p;
    IV tries, limit;

    if (items < 1) XSRETURN_EMPTY;
    c = ST(0);
    p = pp_pending(aTHX_ c);
    if (!p) {
        ST(0) = sv_2mortal(pp_redirect(aTHX_ c, pp_cfg_sv(aTHX_ cfg, "login_path")));
        XSRETURN(1);
    }
    id = pp_hget(aTHX_ p, "id");

    model   = pp_model(aTHX_ cfg, c, "model");
    argv[0] = sv_2mortal(newSVpvs("id"));
    argv[1] = id ? id : &PL_sv_undef;
    user    = sv_2mortal(pp_call(aTHX_ model, "get", argv, 2));
    if (SvROK(user) && !pp_is_hash(user))
        user = sv_2mortal(pp_await(aTHX_ c, user));
    if (!pp_is_hash(user)) {
        (void)hv_delete(pp_session(aTHX_ c), "totp_pending", 12, G_DISCARD);
        ST(0) = sv_2mortal(pp_redirect(aTHX_ c, pp_cfg_sv(aTHX_ cfg, "login_path")));
        XSRETURN(1);
    }

    /* the count is read BEFORE the code is judged, and an account over the
     * limit is refused without judging it: a limit that still tells you
     * whether the guess was right is not a limit */
    limit = pp_cfg_iv(aTHX_ cfg, "attempts", 5);
    tries = pp_fail_count(aTHX_ cfg, (HV *)SvRV(user));
    if (tries >= limit) {
        (void)hv_delete(pp_session(aTHX_ c), "totp_pending", 12, G_DISCARD);
        ST(0) = sv_2mortal(pp_redirect(aTHX_ c, pp_cfg_sv(aTHX_ cfg, "login_path")));
        XSRETURN(1);
    }

    name = sv_2mortal(newSVpvs("code"));
    code = sv_2mortal(pp_call(aTHX_ c, "param", &name, 1));
    if (!SvOK(code)) sv_setpvs(code, "");

    argv[0] = user;
    argv[1] = code;
    ok = sv_2mortal(pp_call(aTHX_ c, "totp_verify", argv, 2));
    if (!SvTRUE(ok))
        ok = sv_2mortal(pp_call(aTHX_ c, "totp_use_recovery", argv, 2));
    if (SvTRUE(ok)) {
        SV *to;
        pp_fail_clear(aTHX_ cfg, c, (HV *)SvRV(user));
        to = sv_2mortal(pp_call(aTHX_ c, "totp_complete", NULL, 0));
        if (!SvOK(to)) sv_setpvs(to, "/");
        ST(0) = sv_2mortal(pp_redirect(aTHX_ c, to));
        XSRETURN(1);
    }

    /* repeated failure clears the pending state entirely, dropping the
     * attacker back to needing the password again - a limit that only
     * delays is a limit a patient script waits out */
    /* a count that cannot be written is a limit that is not running, so the
     * failure spends the marker instead: safe, and loud enough to notice */
    tries = pp_fail_bump(aTHX_ cfg, c, (HV *)SvRV(user), tries) ? tries + 1
                                                                : limit;
    p = pp_pending(aTHX_ c);                  /* re-read: Perl ran in between */
    if (!p || tries >= limit) {
        (void)hv_delete(pp_session(aTHX_ c), "totp_pending", 12, G_DISCARD);
        ST(0) = sv_2mortal(pp_redirect(aTHX_ c, pp_cfg_sv(aTHX_ cfg, "login_path")));
        XSRETURN(1);
    }
    ST(0) = sv_2mortal(pp_render(aTHX_ cfg, c, 1));
    XSRETURN(1);
}

/* ---- the step-up guard -------------------------------------------------------
 * totp_guard() hands back a guard for an `under` chain. It sits AFTER
 * auth_guard, which established identity; it asks whether THIS session
 * satisfied the factor. */

XS_INTERNAL(pp_guard);
XS_INTERNAL(pp_guard)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    SV *c, *at, *id;
    HV *s;

    if (items < 1) XSRETURN_EMPTY;
    c  = ST(0);
    s  = pp_session(aTHX_ c);
    at = pp_hget(aTHX_ s, "totp_at");
    if (at && SvTRUE(at)) XSRETURN_EMPTY;              /* continue */

    id = sv_2mortal(pp_call(aTHX_ c, "auth_id", NULL, 0));
    if (SvOK(id)) {
        /* signed in without the factor: step up, and come back here */
        SV *req  = sv_2mortal(pp_call(aTHX_ c, "req", NULL, 0));
        SV *path = sv_2mortal(pp_call(aTHX_ req, "path", NULL, 0));
        pp_set_pending(aTHX_ cfg, pp_session(aTHX_ c), id, path);
    }
    ST(0) = sv_2mortal(pp_redirect(aTHX_ c,
        pp_cfg_sv(aTHX_ cfg, SvOK(id) ? "challenge_path" : "login_path")));
    XSRETURN(1);
}

/* the `totp_guard` keyword: returns a fresh guard closure */
XS_INTERNAL(pp_kw_guard);
XS_INTERNAL(pp_kw_guard)
{
    dXSARGS;
    HV *cfg = pp_cfg_of(aTHX_ cv);
    PERL_UNUSED_VAR(items);
    ST(0) = sv_2mortal(pp_closure(aTHX_ pp_guard, cfg));
    XSRETURN(1);
}

/* ---- registration ------------------------------------------------------------ */

static void pp_helper(pTHX_ SV *app, const char *name, XSUBADDR_t body, HV *cfg)
{
    SV *argv[2];
    argv[0] = sv_2mortal(newSVpv(name, 0));
    argv[1] = sv_2mortal(pp_closure(aTHX_ body, cfg));
    SvREFCNT_dec(pp_call(aTHX_ app, "helper", argv, 2));
}

static void pp_route(pTHX_ SV *app, const char *method, SV *path,
                     XSUBADDR_t body, HV *cfg)
{
    SV *argv[3];
    argv[0] = sv_2mortal(newSVpv(method, 0));
    argv[1] = path;
    argv[2] = sv_2mortal(pp_closure(aTHX_ body, cfg));
    SvREFCNT_dec(pp_call(aTHX_ app, "route", argv, 3));
}

/* a config value: the option if given, else the default (which may be
 * NULL for "no default") */
static SV *pp_opt_or(pTHX_ HV *opts, const char *k, SV *dflt)
{
    SV *v = pp_hget(aTHX_ opts, k);
    if (v) {
        if (dflt) SvREFCNT_dec(dflt);
        return newSVsv(v);
    }
    return dflt;
}

static void pp_register(pTHX_ SV *app, SV *optsv)
{
    static const char *const known[] = {
        "issuer", "algorithm", "digits", "period", "skew", "model",
        "fields", "recovery_model", "challenge_path", "login_path",
        "attempts", "attempt_window", "pending_ttl", "render", "sqitch" };
    static const char *const fkeys[] = { "secret", "counter", "enabled", "email",
                                         "failed", "failed_at" };
    HV *opts, *cfg, *fields;
    SV *pkgsv, *v;
    STRLEN pl;
    const char *pkg;
    char lower[8];
    int i;

    if (!PP_STATE) PP_STATE = newHV();
    if (SvOK(optsv) && !pp_is_hash(optsv))
        croak("plugin 'TOTP' takes a hashref of options");
    opts = pp_is_hash(optsv) ? (HV *)SvRV(optsv)
                             : (HV *)sv_2mortal((SV *)newHV());

    pkgsv = sv_2mortal(pp_call(aTHX_ app, "caller_class", NULL, 0));
    pkg   = SvPV_const(pkgsv, pl);
    if (hv_exists(PP_STATE, pkg, (I32)pl))
        croak("plugin 'TOTP' already registered for %s", pkg);

    /* unknown options croak at boot, in sorted order so the message is
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
            if (!found) croak("unknown TOTP plugin option '%s'", k);
        }
    }

    cfg = (HV *)sv_2mortal((SV *)newHV());     /* owned by PP_STATE below */
    v = pp_opt_or(aTHX_ opts, "issuer", NULL);
    if (!v)
        croak("TOTP issuer is required - it names the account in the "
              "authenticator app");
    (void)hv_stores(cfg, "issuer", v);

    /* algorithm, lowercased: the engine accepts any case, the
     * configuration stores one spelling */
    {
        SV *a = pp_hget(aTHX_ opts, "algorithm");
        STRLEN al = 4, j;
        const char *ap = a ? SvPV_const(a, al) : "sha1";
        if (al >= sizeof lower)
            croak("TOTP algorithm must be sha1, sha256 or sha512, not '%.*s'",
                  (int)al, ap);
        for (j = 0; j < al; j++) lower[j] = (char)toLOWER(ap[j]);
        lower[al] = '\0';
        if (!strEQ(lower, "sha1") && !strEQ(lower, "sha256")
            && !strEQ(lower, "sha512"))
            croak("TOTP algorithm must be sha1, sha256 or sha512, not '%s'",
                  lower);
        (void)hv_stores(cfg, "algorithm", newSVpv(lower, 0));
    }
    {
        IV d = (v = pp_hget(aTHX_ opts, "digits")) ? SvIV(v) : 6;
        if (d < 6 || d > 8) croak("TOTP digits must be 6, 7 or 8");
        (void)hv_stores(cfg, "digits", newSViv(d));
    }
    (void)hv_stores(cfg, "period",         pp_opt_or(aTHX_ opts, "period",         newSViv(30)));
    (void)hv_stores(cfg, "skew",           pp_opt_or(aTHX_ opts, "skew",           newSViv(1)));
    (void)hv_stores(cfg, "model",          pp_opt_or(aTHX_ opts, "model",          newSVpvs("User")));
    (void)hv_stores(cfg, "recovery_model", pp_opt_or(aTHX_ opts, "recovery_model", newSVpvs("Token")));
    (void)hv_stores(cfg, "challenge_path", pp_opt_or(aTHX_ opts, "challenge_path", newSVpvs("/login/totp")));
    (void)hv_stores(cfg, "login_path",     pp_opt_or(aTHX_ opts, "login_path",     newSVpvs("/login")));
    /* both are checked because both fail in a direction that is easy to miss:
     * no attempts locks every account out for good, and no window means every
     * failure has already lapsed, which is a limit that never counts */
    {
        IV a = (v = pp_hget(aTHX_ opts, "attempts")) ? SvIV(v) : 5;
        IV w = (v = pp_hget(aTHX_ opts, "attempt_window")) ? SvIV(v) : 900;
        if (a < 1) croak("TOTP attempts must be 1 or more");
        if (w < 1) croak("TOTP attempt_window must be 1 second or more");
        (void)hv_stores(cfg, "attempts",       newSViv(a));
        (void)hv_stores(cfg, "attempt_window", newSViv(w));
    }
    (void)hv_stores(cfg, "pending_ttl",    pp_opt_or(aTHX_ opts, "pending_ttl",    newSViv(300)));
    if ((v = pp_hget(aTHX_ opts, "render")))
        (void)hv_stores(cfg, "render", newSVsv(v));

    /* the fields map onto the application's own column names */
    fields = newHV();
    (void)hv_stores(fields, "secret",  newSVpvs("totp_secret"));
    (void)hv_stores(fields, "counter", newSVpvs("totp_last_counter"));
    (void)hv_stores(fields, "enabled", newSVpvs("totp_enabled"));
    (void)hv_stores(fields, "email",     newSVpvs("email"));
    (void)hv_stores(fields, "failed",    newSVpvs("totp_failed"));
    (void)hv_stores(fields, "failed_at", newSVpvs("totp_failed_at"));
    (void)hv_stores(cfg, "fields", newRV_noinc((SV *)fields));
    if ((v = pp_hget(aTHX_ opts, "fields"))) {
        HE *he;
        if (!pp_is_hash(v)) croak("TOTP fields must be a hashref");
        hv_iterinit((HV *)SvRV(v));
        while ((he = hv_iternext((HV *)SvRV(v)))) {
            const char *k = SvPV_nolen_const(hv_iterkeysv(he));
            int found = 0;
            for (i = 0; i < (int)(sizeof fkeys / sizeof fkeys[0]); i++)
                if (strEQ(k, fkeys[i])) { found = 1; break; }
            if (!found) croak("unknown TOTP fields key '%s'", k);
            (void)hv_store(fields, k, (I32)strlen(k),
                           newSVsv(hv_iterval((HV *)SvRV(v), he)), 0);
        }
    }

    (void)hv_store(PP_STATE, pkg, (I32)pl, newRV_inc((SV *)cfg), 0);

    /* sqitch => 1: the three columns, shipped as the Sqitch project
     * `punk_totp` under lib/Punk/Plugin/TOTP/sqitch - one change requiring
     * punk_auth:users - and registered with Punk-Sqitch, which deploys it
     * after Punk::Auth's project and before the application's. Opt-in, as
     * `fields` exists for rows with other column names; asking without
     * Punk-Sqitch installed is an error, not a silence. */
    if ((v = pp_hget(aTHX_ opts, "sqitch")) && SvTRUE(v)) {
        /* Located from Punk/TOTP.pm, the module this XS always loads through:
         * Punk/Plugin/TOTP.pm may never be in %INC at all, since Punk skips
         * the require when the package already has a register - which it
         * does the moment Punk::TOTP is loaded by anything. */
        SV **totppm = hv_fetchs(GvHV(PL_incgv), "Punk/TOTP.pm", 0);
        SV *dir, *argv[4], *cls, *r;
        AV *eng;
        eval_pv("require Punk::Plugin::Sqitch; 1", FALSE);
        if (SvTRUE(ERRSV))
            croak("plugin 'TOTP': sqitch => 1 needs Punk-Sqitch "
                  "(Punk::Plugin::Sqitch) installed: %s", SvPV_nolen(ERRSV));
        if (!(totppm && *totppm && SvOK(*totppm)))
            croak("plugin 'TOTP': cannot find Punk/TOTP.pm in %%INC to "
                  "locate the punk_totp Sqitch project");
        dir = sv_2mortal(newSVsv(*totppm));
        {   /* .../Punk/TOTP.pm -> .../Punk/Plugin/TOTP/sqitch */
            STRLEN dl; const char *dp = SvPV_const(dir, dl);
            if (dl >= 7 && memEQ(dp + dl - 7, "TOTP.pm", 7)) SvCUR_set(dir, dl - 7);
        }
        sv_catpvs(dir, "Plugin/TOTP/sqitch");
        eng = newAV();
        av_push(eng, newSVpvs("sqlite"));
        av_push(eng, newSVpvs("pg"));
        av_push(eng, newSVpvs("mysql"));
        cls = sv_2mortal(newSVpvs("Punk::Plugin::Sqitch"));
        argv[0] = app;
        argv[1] = sv_2mortal(newSVpvs("punk_totp"));
        argv[2] = dir;
        argv[3] = sv_2mortal(newSVpvs("engines"));
        {
            SV *argv5[5] = { argv[0], argv[1], argv[2], argv[3],
                             sv_2mortal(newRV_noinc((SV *)eng)) };
            r = pp_call(aTHX_ cls, "project", argv5, 5);
        }
        if (r) SvREFCNT_dec(r);
        (void)hv_delete(cfg, "sqitch", 6, G_DISCARD);
    }

    /* the QR renderer, resolved now: fail at boot, not at enrolment */
    pp_qr_boot(aTHX);

    pp_helper(aTHX_ app, "totp_secret",         pp_h_secret,         cfg);
    pp_helper(aTHX_ app, "totp_uri",            pp_h_uri,            cfg);
    pp_helper(aTHX_ app, "totp_qr",             pp_h_qr,             cfg);
    pp_helper(aTHX_ app, "totp_verify",         pp_h_verify,         cfg);
    pp_helper(aTHX_ app, "totp_recovery_codes", pp_h_recovery_codes, cfg);
    pp_helper(aTHX_ app, "totp_use_recovery",   pp_h_use_recovery,   cfg);
    pp_helper(aTHX_ app, "totp_challenge",      pp_h_challenge,      cfg);
    pp_helper(aTHX_ app, "totp_complete",       pp_h_complete,       cfg);

    {
        SV *path = pp_cfg_sv(aTHX_ cfg, "challenge_path");
        SV *argv[6];
        pp_route(aTHX_ app, "GET",  path, pp_r_get,  cfg);
        pp_route(aTHX_ app, "POST", path, pp_r_post, cfg);
        /* per-address, on top of (not instead of) the tries clear */
        argv[0] = sv_2mortal(newSVpvs("for"));    argv[1] = path;
        argv[2] = sv_2mortal(newSVpvs("limit"));  argv[3] = sv_2mortal(newSViv(30));
        argv[4] = sv_2mortal(newSVpvs("window")); argv[5] = sv_2mortal(newSViv(60));
        SvREFCNT_dec(pp_call(aTHX_ app, "rate_limit", argv, 6));
    }
    {
        SV *argv[3];
        argv[0] = sv_2mortal(newSVpvs("totp_guard"));
        argv[1] = sv_2mortal(pp_closure(aTHX_ pp_kw_guard, cfg));
        argv[2] = sv_2mortal(newSVpvs("Punk::Plugin::TOTP"));
        SvREFCNT_dec(pp_call(aTHX_ app, "install_kw", argv, 3));
    }
}

#endif /* PTOTP_PLUGIN_H */
