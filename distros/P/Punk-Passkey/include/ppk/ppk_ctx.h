/* ppk_ctx.h - what the ceremonies need from the request context.
 *
 * Four things, and each one is somewhere the design could go wrong
 * quietly, so they are gathered here rather than spread through the
 * ceremony code:
 *
 *   the ORIGIN and the rpId, which must come from the application's
 *   declared `host` and never from the request;
 *
 *   the SESSION, where a challenge lives between the two halves of a
 *   ceremony;
 *
 *   the LOG, because every refusal is invisible to the caller by
 *   design and has to be visible to the operator;
 *
 *   calling back into Perl at all, which is one function so the
 *   context-stack discipline is written once.
 */

#ifndef PPK_CTX_H
#define PPK_CTX_H

/* One method call on the context, scalar context, returning a NEW SV
 * (+1) or NULL if the call died. The result is copied out before
 * FREETMPS, because a mortal built inside the ENTER/LEAVE window is
 * freed by the LEAVE - the trap this workspace has paid for before. */
static SV *ppk_call(pTHX_ SV *obj, const char *meth, SV **argv, int argc) {
    dSP;
    int count, i;
    SV *out = NULL;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    EXTEND(SP, argc + 1);
    PUSHs(obj);
    for (i = 0; i < argc; i++) PUSHs(argv[i]);
    PUTBACK;
    count = call_method(meth, G_SCALAR | G_EVAL);
    SPAGAIN;
    if (count > 0) {
        SV *r = POPs;
        if (!SvTRUE(ERRSV)) out = newSVsv(r);
    }
    PUTBACK; FREETMPS; LEAVE;
    return out;
}

static int ppk_is_hash(SV *sv) {
    return sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV;
}

/* The session, which a passkey ceremony cannot do without: the
 * challenge has to outlive the response that issued it and cannot be
 * kept anywhere the client controls. */
static HV *ppk_session(pTHX_ SV *c) {
    SV *s = sv_2mortal(ppk_call(aTHX_ c, "session", NULL, 0));
    if (!ppk_is_hash(s))
        croak("Punk::Passkey: a passkey ceremony needs the session "
              "keyword - the challenge has to be remembered between the "
              "two halves, and it cannot be remembered anywhere the "
              "client can reach");
    return (HV *)SvRV(s);
}

/* The application's canonical origin.
 *
 * $c->origin is the ONLY source. It is the declared `host` (or an
 * allowed one), never the Host header - which is the whole point:
 * WebAuthn's origin check is what stops a credential minted on one
 * site being replayed at another, so an origin an attacker can choose
 * is not a check at all. That is the CVE-2026-75628 class, and the
 * machinery that resists it already exists here.
 *
 * Undef means no `host` was declared, and that is refused loudly at
 * first use rather than defaulted: a default would be either the
 * request's host (the bug) or a guess (worse). */
static SV *ppk_origin(pTHX_ SV *c) {
    SV *o = sv_2mortal(ppk_call(aTHX_ c, "origin", NULL, 0));
    if (!(o && SvOK(o) && SvCUR(o)))
        croak("Punk::Passkey: no canonical origin - declare the `host` "
              "keyword. A passkey is bound to an origin, and the origin "
              "must be configuration: taking it from the request would "
              "let a caller choose which site's credentials it is "
              "presenting");
    return o;
}

/* The rpId: the host of the canonical origin, with the scheme and any
 * port removed.
 *
 * Derived rather than configured separately, because two places to
 * write the same fact is one place to write it differently - and the
 * failure of a mismatched rpId is a credential that registers happily
 * and cannot be used, at a site that has already told the user
 * passkeys work. */
static SV *ppk_rpid(pTHX_ SV *origin) {
    STRLEN ol;
    const char *o = SvPV_const(origin, ol);
    const char *p = o, *end = o + ol, *colon;
    /* scheme:// */
    {
        static const char sep[] = "://";
        const char *s = ninstr((char *)o, (char *)end,
                               (char *)sep, (char *)sep + 3);
        if (s) p = s + 3;
    }
    /* :port, and never a ':' inside an IPv6 literal - which cannot be
     * an rpId anyway, so a bracketed host is refused rather than
     * trimmed into something plausible */
    if (p < end && *p == '[')
        croak("Punk::Passkey: an IP address cannot be a relying-party id");
    for (colon = p; colon < end && *colon != ':' && *colon != '/'; colon++)
        ;
    return sv_2mortal(newSVpvn(p, (STRLEN)(colon - p)));
}

/* A warn line on the request logger, so a refusal carries the request
 * id and the method and path the rest of the log has.
 *
 * Every ceremony failure is a uniform undef to the caller - a verifier
 * that says WHICH check failed is helping tune the next attempt - so
 * this is the only place the reason exists. Losing it would make a
 * failed login indistinguishable from a bug. */
static void ppk_warn(pTHX_ SV *c, const char *msg) {
    SV *lg = sv_2mortal(ppk_call(aTHX_ c, "log", NULL, 0));
    if (lg && SvROK(lg)) {
        SV *argv[1];
        argv[0] = sv_2mortal(newSVpv(msg, 0));
        SvREFCNT_dec(ppk_call(aTHX_ lg, "warn", argv, 1));
    }
}

#endif /* PPK_CTX_H */
