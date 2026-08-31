/* ppk_reg.h - the registration ceremony.
 *
 * Two halves with a challenge between them: the server offers one, the
 * authenticator signs over it, the server checks that what came back
 * is an answer to the question it actually asked.
 *
 * ---- the challenge lifecycle ----------------------------------------
 *
 * One outstanding challenge per session, short-lived, and CONSUMED ON
 * THE FIRST ATTEMPT - success or failure alike. That is not a
 * convenience; it is the property that makes a captured response
 * useless. A challenge that survived a failed attempt could be
 * answered again, which is exactly what an attacker replaying somebody
 * else's registration response needs.
 *
 * This is the CSRF token's lifecycle, deliberately: Punk already has
 * one single-use, session-held, short-lived token pattern that has
 * been thought about, and a second one written from scratch would be
 * a second one to get wrong.
 *
 * The stored form is the base64url TEXT, not the raw bytes. A session
 * is serialised - to a signed cookie, or through a store - and
 * arbitrary binary in that payload is a portability problem waiting
 * for the first non-ASCII byte. The client echoes the challenge back
 * in base64url anyway, so the comparison happens in the form both
 * sides already hold, still in constant time.
 *
 * ---- what is checked, in order ---------------------------------------
 *
 * The order matters where it is cheap to say so: the challenge is
 * consumed before anything else can fail, so no failure path leaves it
 * replayable.
 *
 *   1  clientDataJSON parses, and type is webauthn.create
 *   2  challenge matches the one this session was issued (ct_eq)
 *   3  origin is the application's canonical origin, exactly
 *   4  attestationObject parses; rpIdHash is sha256(rpId); UP set; AT set
 *   5  the credential id is present and within the spec's ceiling
 *   6  the COSE key is on the allowlist and converts
 *   7  attStmt is NOT examined - see the stance below
 *
 * ---- the attestation stance ------------------------------------------
 *
 * attStmt is read out and handed back untouched. For LOGIN - as
 * opposed to enterprise device policy - verifying an attestation chain
 * buys almost nothing and costs an x509 path validator, a trust store
 * and its maintenance. The `verify_attestation` option is the seam for
 * the day that changes: it receives the format and the statement and
 * refuses by returning false. Nothing in this distribution implements
 * one, and the POD says so rather than implying a check that is not
 * happening.
 *
 * Include after ppk_ctx.h, ppk_cbor.h, ppk_cose.h.
 */

#ifndef PPK_REG_H
#define PPK_REG_H

#define PPK_SESSION_REG "punk.passkey.reg"
#define PPK_CHALLENGE_BYTES 32
#define PPK_CHALLENGE_TTL   300      /* five minutes */
#define PPK_CREDID_MAX      1023     /* the ceiling the spec sets */

/* ---- authenticatorData, which is not CBOR ---------------------------------
 *
 * A fixed binary layout, read by hand:
 *
 *    32  rpIdHash
 *     1  flags        bit 0 UP, bit 2 UV, bit 6 AT, bit 7 ED
 *     4  signCount    big-endian
 *   then, when AT is set:
 *    16  AAGUID
 *     2  credentialIdLength
 *     n  credentialId
 *        the COSE public key, and extensions behind it when ED is set
 */
typedef struct {
    const unsigned char *rpid_hash;
    unsigned char flags;
    U32 sign_count;
    const unsigned char *aaguid;
    const unsigned char *cred_id;
    STRLEN cred_id_len;
    const unsigned char *cose;
    STRLEN cose_len;
} ppk_authdata;

#define PPK_FLAG_UP 0x01
#define PPK_FLAG_UV 0x04
#define PPK_FLAG_AT 0x40

static int ppk_authdata_parse(const unsigned char *p, STRLEN len,
                              ppk_authdata *a, const char **why) {
    if (len < 37) { *why = "authenticatorData is too short"; return 0; }
    a->rpid_hash  = p;
    a->flags      = p[32];
    a->sign_count = ((U32)p[33] << 24) | ((U32)p[34] << 16)
                  | ((U32)p[35] << 8)  | (U32)p[36];
    a->aaguid = a->cred_id = a->cose = NULL;
    a->cred_id_len = a->cose_len = 0;
    if (!(a->flags & PPK_FLAG_AT)) return 1;
    if (len < 55) { *why = "attested credential data is truncated"; return 0; }
    a->aaguid = p + 37;
    a->cred_id_len = ((STRLEN)p[53] << 8) | (STRLEN)p[54];
    /* the length is checked against what is actually there before the
     * read, not after */
    if (a->cred_id_len > len - 55)
        { *why = "the credential id runs past the end"; return 0; }
    a->cred_id = p + 55;
    a->cose     = p + 55 + a->cred_id_len;
    a->cose_len = len - 55 - a->cred_id_len;
    return 1;
}

/* ---- the challenge -------------------------------------------------------- */

/* Both ceremonies use these, under different session keys - ONE
 * lifecycle with two slots, not two lifecycles. A registration
 * challenge and an authentication challenge have identical rules, and
 * the second implementation of identical rules is where they stop
 * being identical. */
static SV *ppk_challenge_new(pTHX_ SV *c, const char *slot) {
    const jws_abi *J = ppk_jws(aTHX);
    SV *raw = J->random_bytes(aTHX_ PPK_CHALLENGE_BYTES);
    SV *b64;
    HV *sess, *entry;
    if (!raw) croak("Punk::Passkey: no entropy for a challenge");
    b64 = J->b64url(aTHX_ (const unsigned char *)SvPVX(raw), SvCUR(raw));
    SvREFCNT_dec(raw);
    if (!b64) croak("Punk::Passkey: could not encode a challenge");

    sess  = ppk_session(aTHX_ c);
    entry = newHV();
    (void)hv_stores(entry, "c",   newSVsv(b64));
    (void)hv_stores(entry, "exp", newSVnv((NV)time(NULL) + PPK_CHALLENGE_TTL));
    /* A new ask REPLACES the outstanding one. Two live challenges per
     * session would mean a response could be matched against either,
     * which is one more thing than the ceremony ever needs. */
    (void)hv_store(sess, slot, (I32)strlen(slot),
                   newRV_noinc((SV *)entry), 0);
    return sv_2mortal(b64);
}

/* Take the outstanding challenge and REMOVE it, whatever happens next.
 * Returns a mortal copy, or NULL when there is none or it has expired. */
static SV *ppk_challenge_take(pTHX_ SV *c, const char *slot) {
    HV *sess = ppk_session(aTHX_ c);
    SV *held = hv_delete(sess, slot, (I32)strlen(slot), 0);
    SV **cp, **ep;
    if (!(held && ppk_is_hash(held))) return NULL;
    cp = hv_fetchs((HV *)SvRV(held), "c", 0);
    ep = hv_fetchs((HV *)SvRV(held), "exp", 0);
    if (!(cp && *cp && SvOK(*cp))) return NULL;
    if (!(ep && *ep && SvOK(*ep) && (NV)time(NULL) < SvNV(*ep))) return NULL;
    return sv_2mortal(newSVsv(*cp));
}

/* ---- the options the browser is given ------------------------------------- */

static void ppk_hv_str(pTHX_ HV *h, const char *k, const char *v) {
    (void)hv_store(h, k, (I32)strlen(k), newSVpv(v, 0), 0);
}

static SV *ppk_register_options(pTHX_ SV *c, HV *args) {
    SV *origin = ppk_origin(aTHX_ c);
    SV *rpid   = ppk_rpid(aTHX_ origin);
    SV *chal   = ppk_challenge_new(aTHX_ c, PPK_SESSION_REG);
    HV *out = newHV(), *rp = newHV(), *user = newHV(), *sel = newHV();
    AV *params = newAV();
    SV **e;

    (void)hv_stores(out, "challenge", newSVsv(chal));

    (void)hv_stores(rp, "id", newSVsv(rpid));
    e = args ? hv_fetchs(args, "rp_name", 0) : NULL;
    (void)hv_stores(rp, "name",
        (e && *e && SvOK(*e)) ? newSVsv(*e) : newSVsv(rpid));
    (void)hv_stores(out, "rp", newRV_noinc((SV *)rp));

    /* The user handle is the application's, and it is the application
     * that knows what an account is. A missing one is a programming
     * error rather than something to invent. */
    e = args ? hv_fetchs(args, "user_id", 0) : NULL;
    if (!(e && *e && SvOK(*e)))
        croak("Punk::Passkey: register_options needs a user_id - the "
              "credential is bound to an account, and only the "
              "application knows which");
    {
        const jws_abi *J = ppk_jws(aTHX);
        STRLEN ul;
        const char *up = SvPV_const(*e, ul);
        SV *b = J->b64url(aTHX_ (const unsigned char *)up, ul);
        (void)hv_stores(user, "id", b ? b : newSVpvs(""));
    }
    e = args ? hv_fetchs(args, "user_name", 0) : NULL;
    (void)hv_stores(user, "name",
        (e && *e && SvOK(*e)) ? newSVsv(*e) : newSVpvs(""));
    e = args ? hv_fetchs(args, "user_display_name", 0) : NULL;
    if (!(e && *e && SvOK(*e))) e = args ? hv_fetchs(args, "user_name", 0) : NULL;
    (void)hv_stores(user, "displayName",
        (e && *e && SvOK(*e)) ? newSVsv(*e) : newSVpvs(""));
    (void)hv_stores(out, "user", newRV_noinc((SV *)user));

    /* The allowlist, in preference order: ES256 is what almost every
     * authenticator produces, RS256 is there because Windows Hello
     * does not. */
    {
        HV *es = newHV(), *rs = newHV();
        ppk_hv_str(aTHX_ es, "type", "public-key");
        (void)hv_stores(es, "alg", newSViv(PPK_COSE_ALG_ES256));
        ppk_hv_str(aTHX_ rs, "type", "public-key");
        (void)hv_stores(rs, "alg", newSViv(PPK_COSE_ALG_RS256));
        av_push(params, newRV_noinc((SV *)es));
        av_push(params, newRV_noinc((SV *)rs));
    }
    (void)hv_stores(out, "pubKeyCredParams", newRV_noinc((SV *)params));

    /* Preferences, not requirements. `required` here is how a
     * deployment discovers that some real authenticator its users
     * already own cannot satisfy it, at the moment those users try to
     * sign up. */
    e = args ? hv_fetchs(args, "user_verification", 0) : NULL;
    (void)hv_stores(sel, "userVerification",
        (e && *e && SvOK(*e)) ? newSVsv(*e) : newSVpvs("preferred"));
    e = args ? hv_fetchs(args, "resident_key", 0) : NULL;
    (void)hv_stores(sel, "residentKey",
        (e && *e && SvOK(*e)) ? newSVsv(*e) : newSVpvs("preferred"));
    (void)hv_stores(out, "authenticatorSelection", newRV_noinc((SV *)sel));

    ppk_hv_str(aTHX_ out, "attestation", "none");

    (void)hv_stores(out, "timeout", newSViv(PPK_CHALLENGE_TTL * 1000));

    /* The ids the user already has, so the platform refuses a second
     * registration of the same authenticator in its own UI - which is
     * a better experience than a unique-constraint violation, and the
     * constraint is still there underneath. */
    {
        AV *ex = newAV();
        e = args ? hv_fetchs(args, "exclude", 0) : NULL;
        if (e && *e && SvROK(*e) && SvTYPE(SvRV(*e)) == SVt_PVAV) {
            AV *in = (AV *)SvRV(*e);
            SSize_t i, n = av_len(in) + 1;
            for (i = 0; i < n; i++) {
                SV **id = av_fetch(in, i, 0);
                HV *d;
                if (!(id && *id && SvOK(*id))) continue;
                d = newHV();
                ppk_hv_str(aTHX_ d, "type", "public-key");
                (void)hv_stores(d, "id", newSVsv(*id));
                av_push(ex, newRV_noinc((SV *)d));
            }
        }
        (void)hv_stores(out, "excludeCredentials", newRV_noinc((SV *)ex));
    }

    return newRV_noinc((SV *)out);
}

/* ---- the response --------------------------------------------------------- */

/* A field out of the decoded clientDataJSON. */
static SV *ppk_cd_str(pTHX_ HV *cd, const char *k) {
    SV **e = hv_fetch(cd, k, (I32)strlen(k), 0);
    return (e && *e && SvOK(*e)) ? *e : NULL;
}

static int ppk_ct_eq_sv(pTHX_ SV *a, SV *b) {
    const jws_abi *J = ppk_jws(aTHX);
    STRLEN al, bl;
    const char *ap = SvPV_const(a, al);
    const char *bp = SvPV_const(b, bl);
    return J->ct_eq(aTHX_ (const unsigned char *)ap, al,
                          (const unsigned char *)bp, bl);
}

/*
 * $body is the browser's response: a hashref with clientDataJSON and
 * attestationObject, both base64url, and optionally transports.
 *
 * Returns the credential as a hashref, or NULL with *why set. The
 * caller stores it; this owns no storage, because the application
 * knows what a user is and this does not.
 */
static SV *ppk_register(pTHX_ SV *c, HV *body, HV *args, const char **why) {
    const jws_abi *J = ppk_jws(aTHX);
    const frj_abi *F = ppk_frj(aTHX);
    SV *origin = ppk_origin(aTHX_ c);
    SV *rpid   = ppk_rpid(aTHX_ origin);
    SV *expect, *cdj_b64, *att_b64, *cdj, *att, *decoded, *key, *pem;
    HV *cd, *ah;
    SV **e;
    ppk_authdata ad;
    const char *sub = NULL;
    IV alg = 0;
    HV *out;

    *why = NULL;

    /* The challenge is taken - and removed - BEFORE anything can fail.
     * Every return below this line leaves the session with no
     * outstanding challenge, so a captured response cannot be tried
     * twice. */
    expect = ppk_challenge_take(aTHX_ c, PPK_SESSION_REG);
    if (!expect) { *why = "no outstanding challenge, or it expired"; return NULL; }

    e = hv_fetchs(body, "clientDataJSON", 0);
    cdj_b64 = (e && *e && SvOK(*e)) ? *e : NULL;
    e = hv_fetchs(body, "attestationObject", 0);
    att_b64 = (e && *e && SvOK(*e)) ? *e : NULL;
    if (!cdj_b64 || !att_b64)
        { *why = "the response is missing clientDataJSON or attestationObject";
          return NULL; }

    cdj = sv_2mortal(J->b64url_decode(aTHX_ SvPVX(cdj_b64), SvCUR(cdj_b64)));
    att = sv_2mortal(J->b64url_decode(aTHX_ SvPVX(att_b64), SvCUR(att_b64)));
    if (!cdj || !att || !SvOK(cdj) || !SvOK(att))
        { *why = "the response is not base64url"; return NULL; }

    /* 1. clientDataJSON, and its type */
    {
        SV *doc = sv_2mortal(F->decode(aTHX_ SvPVX(cdj), SvCUR(cdj), NULL));
        SV *t;
        if (!ppk_is_hash(doc)) { *why = "clientDataJSON is not an object"; return NULL; }
        cd = (HV *)SvRV(doc);
        t = ppk_cd_str(aTHX_ cd, "type");
        if (!t || strNE(SvPV_nolen(t), "webauthn.create"))
            { *why = "clientDataJSON type is not webauthn.create"; return NULL; }
    }

    /* 2. the challenge, in constant time */
    {
        SV *got = ppk_cd_str(aTHX_ cd, "challenge");
        if (!got) { *why = "no challenge in clientDataJSON"; return NULL; }
        if (!ppk_ct_eq_sv(aTHX_ got, expect))
            { *why = "the challenge does not match the one this session was issued";
              return NULL; }
    }

    /* 3. the origin, exactly - no suffix logic, no port tolerance */
    {
        SV *got = ppk_cd_str(aTHX_ cd, "origin");
        if (!got) { *why = "no origin in clientDataJSON"; return NULL; }
        if (!sv_eq(got, origin))
            { *why = "the origin is not this application's"; return NULL; }
    }

    /* 4. the attestation object, and authenticatorData */
    decoded = sv_2mortal(ppk_cbor_decode(aTHX_
                  (const unsigned char *)SvPVX(att), SvCUR(att), &sub));
    if (!decoded) { *why = sub ? sub : "the attestation object did not parse";
                    return NULL; }
    if (!ppk_is_hash(decoded))
        { *why = "the attestation object is not a map"; return NULL; }
    ah = (HV *)SvRV(decoded);
    e = hv_fetchs(ah, "authData", 0);
    if (!(e && *e && SvPOK(*e)))
        { *why = "the attestation object has no authData"; return NULL; }
    if (!ppk_authdata_parse(
            (const unsigned char *)SvPVX(*e), SvCUR(*e), &ad, &sub))
        { *why = sub; return NULL; }

    {   /* the rpIdHash: sha256 of the rpId this application declared */
        SV *want = sv_2mortal(J->sha256(aTHX_
                       (const unsigned char *)SvPVX(rpid), SvCUR(rpid)));
        if (!want || SvCUR(want) != 32
            || !J->ct_eq(aTHX_ (const unsigned char *)SvPVX(want), 32,
                               ad.rpid_hash, 32))
            { *why = "the authenticator signed for a different relying party";
              return NULL; }
    }
    if (!(ad.flags & PPK_FLAG_UP))
        { *why = "user presence was not set"; return NULL; }
    if (!(ad.flags & PPK_FLAG_AT))
        { *why = "no attested credential data"; return NULL; }
    {   /* user verification, only when the application asked for it */
        SV **uv = args ? hv_fetchs(args, "user_verification", 0) : NULL;
        if (uv && *uv && SvOK(*uv) && strEQ(SvPV_nolen(*uv), "required")
            && !(ad.flags & PPK_FLAG_UV))
            { *why = "user verification was required and did not happen";
              return NULL; }
    }

    /* 5. the credential id */
    if (ad.cred_id_len == 0)
        { *why = "the credential id is empty"; return NULL; }
    if (ad.cred_id_len > PPK_CREDID_MAX)
        { *why = "the credential id is longer than the spec allows"; return NULL; }

    /* 6. the key: on the allowlist, and convertible */
    key = sv_2mortal(ppk_cbor_decode_prefix(aTHX_ ad.cose, ad.cose_len,
                                            NULL, &sub));
    if (!key) { *why = sub ? sub : "the public key did not parse"; return NULL; }
    pem = ppk_cose_to_pem(aTHX_ key, &alg, &sub);
    if (!pem) { *why = sub ? sub : "the public key was refused"; return NULL; }
    SvREFCNT_dec(pem);            /* wanted for the check, not for storage */

    /* 7. attStmt: handed to the hook if there is one, and otherwise
     * not examined. The stance is in the POD; this is where it would
     * stop being the stance. */
    {
        SV **hook = args ? hv_fetchs(args, "verify_attestation", 0) : NULL;
        if (hook && *hook && SvROK(*hook) && SvTYPE(SvRV(*hook)) == SVt_PVCV) {
            SV **fmt = hv_fetchs(ah, "fmt", 0);
            SV **stmt = hv_fetchs(ah, "attStmt", 0);
            SV *r;
            dSP;
            int count;
            ENTER; SAVETMPS;
            PUSHMARK(SP); EXTEND(SP, 2);
            PUSHs(fmt && *fmt ? *fmt : &PL_sv_undef);
            PUSHs(stmt && *stmt ? *stmt : &PL_sv_undef);
            PUTBACK;
            count = call_sv(*hook, G_SCALAR | G_EVAL);
            SPAGAIN;
            r = count > 0 ? POPs : &PL_sv_undef;
            {
                int ok = !SvTRUE(ERRSV) && SvTRUE(r);
                PUTBACK; FREETMPS; LEAVE;
                if (!ok) { *why = "verify_attestation refused the statement";
                           return NULL; }
            }
        }
    }

    /* what the caller stores */
    out = newHV();
    {
        SV *id = J->b64url(aTHX_ ad.cred_id, ad.cred_id_len);
        (void)hv_stores(out, "credential_id", id ? id : newSVpvs(""));
    }
    /* the COSE bytes verbatim: what arrived is what is stored, and it
     * is re-imported and re-checked on every login rather than trusted
     * because it was acceptable once */
    (void)hv_stores(out, "public_key", newSVpvn((const char *)ad.cose,
                                                ad.cose_len));
    (void)hv_stores(out, "sign_count", newSVuv((UV)ad.sign_count));
    (void)hv_stores(out, "alg", newSViv(alg));
    {
        SV *g = J->b64url(aTHX_ ad.aaguid, 16);
        (void)hv_stores(out, "aaguid", g ? g : newSVpvs(""));
    }
    {   /* informational, and straight from the client - it is a hint
         * about how to talk to the authenticator next time, not a
         * security property */
        SV **t = hv_fetchs(body, "transports", 0);
        (void)hv_stores(out, "transports",
            (t && *t && SvOK(*t)) ? newSVsv(*t) : newSV(0));
    }
    {
        SV **f = hv_fetchs(ah, "fmt", 0);
        (void)hv_stores(out, "fmt", (f && *f) ? newSVsv(*f) : newSVpvs(""));
    }
    (void)hv_stores(out, "uv", newSViv((ad.flags & PPK_FLAG_UV) ? 1 : 0));
    return newRV_noinc((SV *)out);
}

#endif /* PPK_REG_H */
