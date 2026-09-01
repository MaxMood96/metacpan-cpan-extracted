#ifndef PAK_CLOS_H
#define PAK_CLOS_H

/* Closures, calls into Perl, and the small predicates both plugins use.
 *
 * This is Punk-TOTP's pp_closure device (ptotp/ptotp_plugin.h:70-107), which
 * is itself a copy of Punk's private punk_closure: a CV built with newXS
 * carrying captured SVs in PERL_MAGIC_ext. Punk does not export it - pk_abi.h
 * is an observer interface and says so - so a plugin that wants a body with
 * state carries its own.
 *
 * The capture has two slots rather than TOTP's one: slot 0 is the
 * configuration hash every body needs, slot 1 an optional argument frozen at
 * the point the closure was made. `feature_guard('beta_ui')` is the whole
 * reason: the flag name belongs to the guard, not to the plugin.
 */

typedef struct { AV *cap; } pak_clos_t;

static int pak_clos_free(pTHX_ SV *sv, MAGIC *mg)
{
    pak_clos_t *c = (pak_clos_t *)mg->mg_ptr;
    PERL_UNUSED_ARG(sv);
    if (c) {
        if (c->cap) SvREFCNT_dec((SV *)c->cap);
        Safefree(c);
    }
    return 0;
}

static MGVTBL pak_clos_vtbl = { NULL, NULL, NULL, NULL, pak_clos_free,
                                 NULL, NULL, NULL };

/* extra may be NULL; it is copied, so the caller keeps its own. */
static SV *pak_closure(pTHX_ XSUBADDR_t body, HV *cfg, SV *extra)
{
    CV *cv = (CV *)newXS(NULL, body, (char *)__FILE__);
    AV *cap = newAV();
    pak_clos_t *c;

    av_push(cap, newRV_inc((SV *)cfg));
    av_push(cap, extra ? newSVsv(extra) : newSV(0));
    Newxz(c, 1, pak_clos_t);
    c->cap = cap;
    sv_magicext((SV *)cv, NULL, PERL_MAGIC_ext, &pak_clos_vtbl, (char *)c, 0);
    return newRV_noinc((SV *)cv);
}

static AV *pak_cap_of(pTHX_ CV *cv)
{
    MAGIC *mg = mg_findext((SV *)cv, PERL_MAGIC_ext, &pak_clos_vtbl);
    AV *cap = mg ? ((pak_clos_t *)mg->mg_ptr)->cap : NULL;
    if (!cap) croak("Punk::APIKey: a closure lost its capture");
    return cap;
}

static HV *pak_cfg_of(pTHX_ CV *cv)
{
    AV *cap = pak_cap_of(aTHX_ cv);
    SV **e = av_fetch(cap, 0, 0);
    if (!(e && *e && SvROK(*e) && SvTYPE(SvRV(*e)) == SVt_PVHV))
        croak("Punk::APIKey: a closure lost its configuration");
    return (HV *)SvRV(*e);
}

/* The frozen argument, or NULL when the closure was made without one. */
static SV *pak_arg_of(pTHX_ CV *cv)
{
    AV *cap = pak_cap_of(aTHX_ cv);
    SV **e = av_fetch(cap, 1, 0);
    return (e && *e && SvOK(*e)) ? *e : NULL;
}

/* ---- calling back into Perl -------------------------------------------------
 * Every call is scalar context and hands back a NEW SV (+1) - a copy of the
 * result, undef when there was none - so a caller owns what it holds and
 * mortalises it. */

static SV *pak_call_common(pTHX_ SV *inv, const char *meth, SV *code,
                            SV **argv, int argc)
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
    if (code)      count = call_sv(code, G_SCALAR);
    else if (inv)  count = call_method(meth, G_SCALAR);
    else           count = call_pv(meth, G_SCALAR);
    SPAGAIN;
    if (count > 0) {
        SV *top = POPs;
        ret = newSVsv(top);
    } else {
        ret = newSV(0);
    }
    PUTBACK; FREETMPS; LEAVE;
    return ret;
}

/* $inv->$meth(@argv) */
static SV *pak_call(pTHX_ SV *inv, const char *meth, SV **argv, int argc)
{
    return pak_call_common(aTHX_ inv, meth, NULL, argv, argc);
}

/* The same, under G_EVAL: the value, or NULL with *failed set and the reason
 * in ERRSV.
 *
 * This exists because a die inside a call made WITHOUT G_EVAL longjmps past
 * the ENTER/SAVETMPS above, leaving the Perl stack short. The damage does not
 * show up where it happened - it shows up later, as garbage read out of an
 * unrelated array, in a place that has nothing to do with the call that
 * died. JMPENV_PUSH is not a substitute: catching the jump is not the
 * problem, unwinding the stack bookkeeping is, and only G_EVAL does that.
 *
 * Anywhere this distribution has to survive a database being away, it calls
 * through here.
 */
static SV *pak_try(pTHX_ SV *inv, const char *meth, SV *code,
                    SV **argv, int argc, int *failed)
{
    dSP;
    int count, i;
    SV *ret = NULL;

    *failed = 0;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    EXTEND(SP, argc + 1);
    if (inv) PUSHs(inv);
    for (i = 0; i < argc; i++) PUSHs(argv[i]);
    PUTBACK;
    if (code)     count = call_sv(code, G_SCALAR | G_EVAL);
    else if (inv) count = call_method(meth, G_SCALAR | G_EVAL);
    else          count = call_pv(meth, G_SCALAR | G_EVAL);
    SPAGAIN;
    /* every returned value comes off, however many there are */
    while (count-- > 0) {
        SV *top = POPs;
        if (count == 0 && !ret) ret = newSVsv(top);
    }
    PUTBACK;
    if (SvTRUE(ERRSV)) {
        *failed = 1;
        if (ret) { SvREFCNT_dec(ret); ret = NULL; }
    }
    FREETMPS; LEAVE;
    return ret;
}

/* Punk::Auth::_await($c, $v) for a value that may be a future; a plain value,
 * or a Punk without the seam, passes straight through. */
static SV *pak_await(pTHX_ SV *c, SV *v)
{
    SV *argv[2];
    if (!v) return newSV(0);
    if (!SvROK(v) || !get_cv("Punk::Auth::_await", 0))
        return newSVsv(v);
    argv[0] = c;
    argv[1] = v;
    return pak_call_common(aTHX_ NULL, "Punk::Auth::_await", NULL, argv, 2);
}

/* ---- predicates and small readers -------------------------------------- */

static int pak_is_hash(SV *sv)
{
    return sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV;
}

static int pak_is_array(SV *sv)
{
    return sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV;
}

/* One key of a hash, or NULL. Borrowed, not owned. */
static SV *pak_hget(pTHX_ HV *h, const char *k)
{
    SV **e = h ? hv_fetch(h, k, (I32)strlen(k), 0) : NULL;
    return (e && *e) ? *e : NULL;
}

static IV pak_hiv(pTHX_ HV *h, const char *k, IV dflt)
{
    SV *v = pak_hget(aTHX_ h, k);
    return (v && SvOK(v)) ? SvIV(v) : dflt;
}

/* A context is a blessed AV; these are its slots. Punk's own layout
 * (punk/punk_context.h), which pk_abi.h exposes as env_of/app_of/stash_of -
 * the three accessors it does offer, and the reason this file reads them
 * directly rather than paying a method call per flag.
 *
 * Fixed by Punk's ABI rather than by this file: PCX_APP moving would be a
 * change pk_abi's version guards would have to announce. */
enum { PAK_CX_ENV = 0, PAK_CX_APP = 1, PAK_CX_STASH = 4 };

static SV *pak_cx_slot(pTHX_ SV *c, I32 slot)
{
    AV *av;
    SV **e;
    if (!(c && SvROK(c) && SvTYPE(SvRV(c)) == SVt_PVAV)) return NULL;
    av = (AV *)SvRV(c);
    e = av_fetch(av, slot, 0);
    return (e && *e && SvOK(*e)) ? *e : NULL;
}



/* The per-request stash, for memoising within one request. Through the
 * method, not the slot: the stash is built lazily and the slot is empty
 * until something asks. */
static HV *pak_stash_of(pTHX_ SV *c)
{
    SV *s;
    SV *have = pak_cx_slot(aTHX_ c, PAK_CX_STASH);
    if (pak_is_hash(have)) return (HV *)SvRV(have);
    s = sv_2mortal(pak_call(aTHX_ c, "stash", NULL, 0));
    return pak_is_hash(s) ? (HV *)SvRV(s) : NULL;
}

#endif /* PAK_CLOS_H */
