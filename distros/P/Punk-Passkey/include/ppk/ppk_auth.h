/* ppk_auth.h - the authentication ceremony.
 *
 * The one that logs somebody in, so every check is load-bearing and
 * every failure fails closed. There is no CBOR on this path at all -
 * an assertion's authenticatorData is the same fixed binary layout
 * registration's was, and the only structured thing is the
 * clientDataJSON - so the parsing risk was spent in phase 0 and is not
 * spent again here.
 *
 * ---- what is checked, in order ---------------------------------------
 *
 *   1  clientDataJSON parses, and type is webauthn.get
 *   2  the challenge is the one this session was issued (ct_eq), and it
 *      is consumed before anything else can fail
 *   3  the origin is this application's canonical origin, exactly
 *   4  the credential is one this application stored (the lookup)
 *   5  authenticatorData: rpIdHash is sha256(rpId), UP set, UV when
 *      the application asked for it
 *   6  the signature verifies, with the STORED key re-imported, over
 *      authenticatorData || sha256(clientDataJSON)
 *   7  the sign count is examined - and is a signal, not a gate
 *
 * ---- the failure is uniform ------------------------------------------
 *
 * Every refusal is the same undef and the same absence of detail to
 * the caller. That matters more here than in registration: an
 * unknown credential id and a bad signature must be indistinguishable,
 * or the login endpoint becomes an oracle for which credential ids
 * exist - and a credential id identifies a person's authenticator.
 * The reason goes to the log, where the request id already is.
 *
 * ---- the sign count is a signal ---------------------------------------
 *
 * The specification offers the signature counter as clone detection: a
 * counter that goes backwards means two authenticators share one
 * private key. Treating that as a hard failure is the obvious reading
 * and it is wrong in practice, because cloud-synced passkeys - iCloud
 * Keychain, Google Password Manager - legitimately report zero for
 * ever and are the majority of passkeys in existence. A hard gate
 * locks out every one of those users on the day it ships.
 *
 * So: a regression is logged and surfaced to the application through
 * on_clone_signal, the stored count is still moved, and the login
 * SUCCEEDS. The operator who wants to force re-enrolment has the
 * event; the user with an iPhone still gets in.
 *
 * Include after ppk_reg.h (the challenge lifecycle and authData are
 * shared with registration, deliberately).
 */

#ifndef PPK_AUTH_H
#define PPK_AUTH_H

#define PPK_SESSION_AUTH "punk.passkey.auth"

/* ---- the options the browser is given ------------------------------------- */

static SV *ppk_challenge_options(pTHX_ SV *c, HV *args) {
    SV *origin = ppk_origin(aTHX_ c);
    SV *rpid   = ppk_rpid(aTHX_ origin);
    SV *chal   = ppk_challenge_new(aTHX_ c, PPK_SESSION_AUTH);
    HV *out = newHV();
    SV **e;

    (void)hv_stores(out, "challenge", newSVsv(chal));
    (void)hv_stores(out, "rpId", newSVsv(rpid));
    (void)hv_stores(out, "timeout", newSViv(PPK_CHALLENGE_TTL * 1000));

    e = args ? hv_fetchs(args, "user_verification", 0) : NULL;
    (void)hv_stores(out, "userVerification",
        (e && *e && SvOK(*e)) ? newSVsv(*e) : newSVpvs("preferred"));

    /* allowCredentials is OPTIONAL, and both shapes are first class.
     *
     * Empty is the usernameless flow: the authenticator offers whatever
     * resident credential it holds for this rpId, and the server learns
     * who it is from the credential id that comes back. Populated is
     * the flow where the user typed a username first, and it is the
     * only way a non-resident credential can be used at all.
     *
     * The key is absent rather than empty when there is nothing to
     * list: an empty array is a different instruction to some
     * platforms than no array. */
    e = args ? hv_fetchs(args, "allow", 0) : NULL;
    if (e && *e && SvROK(*e) && SvTYPE(SvRV(*e)) == SVt_PVAV
        && av_len((AV *)SvRV(*e)) >= 0) {
        AV *in = (AV *)SvRV(*e), *allow = newAV();
        SSize_t i, n = av_len(in) + 1;
        for (i = 0; i < n; i++) {
            SV **id = av_fetch(in, i, 0);
            HV *d;
            if (!(id && *id && SvOK(*id))) continue;
            d = newHV();
            ppk_hv_str(aTHX_ d, "type", "public-key");
            (void)hv_stores(d, "id", newSVsv(*id));
            av_push(allow, newRV_noinc((SV *)d));
        }
        (void)hv_stores(out, "allowCredentials", newRV_noinc((SV *)allow));
    }

    return newRV_noinc((SV *)out);
}

/* ---- the assertion --------------------------------------------------------- */

/* Call a coderef with n arguments, scalar context; returns a new SV
 * (+1) or NULL. Used for the three callbacks the ceremony takes,
 * because the engine owns no storage and cannot know what a user is. */
static SV *ppk_call_cb(pTHX_ SV *cb, SV **argv, int argc, int *died) {
    dSP;
    int count, i;
    SV *out = NULL;
    if (died) *died = 0;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    EXTEND(SP, argc);
    for (i = 0; i < argc; i++) PUSHs(argv[i]);
    PUTBACK;
    count = call_sv(cb, G_SCALAR | G_EVAL);
    SPAGAIN;
    if (count > 0) {
        SV *r = POPs;
        if (SvTRUE(ERRSV)) { if (died) *died = 1; }
        else out = newSVsv(r);
    }
    PUTBACK; FREETMPS; LEAVE;
    return out;
}

static SV *ppk_hv_get(pTHX_ HV *h, const char *k) {
    SV **e = hv_fetch(h, k, (I32)strlen(k), 0);
    return (e && *e && SvOK(*e)) ? *e : NULL;
}

/*
 * $body: the browser's assertion - id (or rawId), clientDataJSON,
 * authenticatorData, signature, optionally userHandle, all base64url.
 *
 * %args: lookup (required coderef, credential id -> the stored row),
 * on_used (coderef, called with the row and the new count),
 * on_clone_signal (coderef, called with the row, the stored count and
 * the asserted one), user_verification.
 *
 * Returns a hashref describing the accepted login, or NULL with *why.
 */
static SV *ppk_verify(pTHX_ SV *c, HV *body, HV *args, const char **why) {
    const jws_abi *J = ppk_jws(aTHX);
    const frj_abi *F = ppk_frj(aTHX);
    SV *origin = ppk_origin(aTHX_ c);
    SV *rpid   = ppk_rpid(aTHX_ origin);
    SV *expect, *cdj, *ad_sv, *sig, *row = NULL, *pem = NULL;
    SV *id_b64;
    HV *cd, *rowh;
    ppk_authdata ad;
    const char *sub = NULL;
    IV alg = 0;
    UV stored_count = 0;
    int clone = 0, died = 0;
    HV *out;

    *why = NULL;

    /* consumed before anything else can fail - see ppk_reg.h */
    expect = ppk_challenge_take(aTHX_ c, PPK_SESSION_AUTH);
    if (!expect) { *why = "no outstanding challenge, or it expired"; return NULL; }

    {
        SV *v;
        v = ppk_hv_get(aTHX_ body, "id");
        if (!v) v = ppk_hv_get(aTHX_ body, "rawId");
        if (!v) { *why = "the assertion has no credential id"; return NULL; }
        id_b64 = v;
    }

    {
        SV *v = ppk_hv_get(aTHX_ body, "clientDataJSON");
        if (!v) { *why = "the assertion has no clientDataJSON"; return NULL; }
        cdj = sv_2mortal(J->b64url_decode(aTHX_ SvPVX(v), SvCUR(v)));
        v = ppk_hv_get(aTHX_ body, "authenticatorData");
        if (!v) { *why = "the assertion has no authenticatorData"; return NULL; }
        ad_sv = sv_2mortal(J->b64url_decode(aTHX_ SvPVX(v), SvCUR(v)));
        v = ppk_hv_get(aTHX_ body, "signature");
        if (!v) { *why = "the assertion has no signature"; return NULL; }
        sig = sv_2mortal(J->b64url_decode(aTHX_ SvPVX(v), SvCUR(v)));
        if (!cdj || !ad_sv || !sig)
            { *why = "the assertion is not base64url"; return NULL; }
    }

    /* 1. clientDataJSON, and its type
     *
     * Read by NAME, never by matching a template: the object carries
     * whatever fields the client's platform chose to add, and one of
     * the captures this is tested against says so in a field of its
     * own. */
    {
        SV *doc = sv_2mortal(F->decode(aTHX_ SvPVX(cdj), SvCUR(cdj), NULL));
        SV *t;
        if (!ppk_is_hash(doc)) { *why = "clientDataJSON is not an object"; return NULL; }
        cd = (HV *)SvRV(doc);
        t = ppk_hv_get(aTHX_ cd, "type");
        if (!t || strNE(SvPV_nolen(t), "webauthn.get"))
            { *why = "clientDataJSON type is not webauthn.get"; return NULL; }
    }

    /* 2. the challenge */
    {
        SV *got = ppk_hv_get(aTHX_ cd, "challenge");
        if (!got) { *why = "no challenge in clientDataJSON"; return NULL; }
        if (!ppk_ct_eq_sv(aTHX_ got, expect))
            { *why = "the challenge does not match the one this session was issued";
              return NULL; }
    }

    /* 3. the origin */
    {
        SV *got = ppk_hv_get(aTHX_ cd, "origin");
        if (!got) { *why = "no origin in clientDataJSON"; return NULL; }
        if (!sv_eq(got, origin))
            { *why = "the origin is not this application's"; return NULL; }
    }

    /* 4. the credential, from the application's own storage */
    {
        SV **lk = args ? hv_fetchs(args, "lookup", 0) : NULL;
        SV *argv[1];
        if (!(lk && *lk && SvROK(*lk) && SvTYPE(SvRV(*lk)) == SVt_PVCV))
            croak("Punk::Passkey::verify needs a `lookup` coderef - the "
                  "engine owns no storage, and only the application knows "
                  "where its credentials live");
        argv[0] = id_b64;
        row = ppk_call_cb(aTHX_ *lk, argv, 1, &died);
        if (row) sv_2mortal(row);
        if (died) { *why = "the lookup callback died"; return NULL; }
        /* An unknown credential is the SAME refusal as a bad signature.
         * Distinguishing them would answer "does this credential id
         * exist here", which is a question about a person's
         * authenticator. */
        if (!ppk_is_hash(row)) { *why = "no such credential"; return NULL; }
        rowh = (HV *)SvRV(row);
    }

    /* 5. authenticatorData */
    if (!ppk_authdata_parse((const unsigned char *)SvPVX(ad_sv),
                            SvCUR(ad_sv), &ad, &sub))
        { *why = sub; return NULL; }
    {
        SV *want = sv_2mortal(J->sha256(aTHX_
                       (const unsigned char *)SvPVX(rpid), SvCUR(rpid)));
        if (!want || SvCUR(want) != 32
            || !J->ct_eq(aTHX_ (const unsigned char *)SvPVX(want), 32,
                               ad.rpid_hash, 32))
            { *why = "the assertion was signed for a different relying party";
              return NULL; }
    }
    if (!(ad.flags & PPK_FLAG_UP))
        { *why = "user presence was not set"; return NULL; }
    {
        SV **uv = args ? hv_fetchs(args, "user_verification", 0) : NULL;
        if (uv && *uv && SvOK(*uv) && strEQ(SvPV_nolen(*uv), "required")
            && !(ad.flags & PPK_FLAG_UV))
            { *why = "user verification was required and did not happen";
              return NULL; }
    }

    /* 6. the signature, with the stored key
     *
     * The key is re-imported and re-checked against the allowlist HERE,
     * on every login, rather than trusted because it was acceptable at
     * registration - so tightening the allowlist tightens every
     * credential already in the table. */
    {
        SV *pk = ppk_hv_get(aTHX_ rowh, "public_key");
        SV *key;
        STRLEN sl;
        const unsigned char *sp;
        int ok;
        void *k;
        if (!pk) { *why = "the stored credential has no public key"; return NULL; }
        key = sv_2mortal(ppk_cbor_decode_prefix(aTHX_
                  (const unsigned char *)SvPVX(pk), SvCUR(pk), NULL, &sub));
        if (!key) { *why = sub ? sub : "the stored key did not parse"; return NULL; }
        pem = ppk_cose_to_pem(aTHX_ key, &alg, &sub);
        if (!pem) { *why = sub ? sub : "the stored key was refused"; return NULL; }
        sv_2mortal(pem);

        sp = (const unsigned char *)SvPVX(sig);
        sl = SvCUR(sig);
        if (alg == PPK_COSE_ALG_ES256) {
            /* an authenticator signs in DER; JOSE verifies raw r||s */
            SV *raw = ppk_sig_der_to_raw(aTHX_ sp, sl, &sub);
            if (!raw) { *why = sub ? sub : "the signature is malformed"; return NULL; }
            sv_2mortal(raw);
            sp = (const unsigned char *)SvPVX(raw);
            sl = SvCUR(raw);
        }

        /* the signed message: authenticatorData || sha256(clientDataJSON) */
        {
            SV *hash = sv_2mortal(J->sha256(aTHX_
                           (const unsigned char *)SvPVX(cdj), SvCUR(cdj)));
            SV *msg;
            const char *name = (alg == PPK_COSE_ALG_RS256) ? "RS256" : "ES256";
            if (!hash) { *why = "could not hash the client data"; return NULL; }
            msg = sv_2mortal(newSVsv(ad_sv));
            sv_catsv(msg, hash);
            k = J->key_from_pem(aTHX_ SvPVX(pem), SvCUR(pem));
            if (!k) { *why = "the stored key did not import"; return NULL; }
            ok = J->verify(aTHX_ k, name, strlen(name),
                           (const unsigned char *)SvPVX(msg), SvCUR(msg),
                           sp, sl);
            J->key_free(aTHX_ k);
        }
        if (!ok) { *why = "the signature did not verify"; return NULL; }
    }

    /* 7. the sign count: a signal, not a gate */
    {
        SV *sc = ppk_hv_get(aTHX_ rowh, "sign_count");
        stored_count = sc ? SvUV(sc) : 0;
        if (stored_count != 0 && ad.sign_count != 0
            && (UV)ad.sign_count <= stored_count) {
            clone = 1;
            ppk_warn(aTHX_ c,
                "passkey sign count did not increase - the credential may "
                "have been cloned, or the authenticator may not count");
            {
                SV **cb = args ? hv_fetchs(args, "on_clone_signal", 0) : NULL;
                if (cb && *cb && SvROK(*cb) && SvTYPE(SvRV(*cb)) == SVt_PVCV) {
                    SV *argv[3];
                    argv[0] = row;
                    argv[1] = sv_2mortal(newSVuv(stored_count));
                    argv[2] = sv_2mortal(newSVuv((UV)ad.sign_count));
                    {
                        SV *r = ppk_call_cb(aTHX_ *cb, argv, 3, NULL);
                        if (r) SvREFCNT_dec(r);
                    }
                }
            }
        }
    }

    /* 8. the count moves forward, through the application's callback */
    {
        SV **cb = args ? hv_fetchs(args, "on_used", 0) : NULL;
        if (cb && *cb && SvROK(*cb) && SvTYPE(SvRV(*cb)) == SVt_PVCV) {
            SV *argv[2];
            argv[0] = row;
            argv[1] = sv_2mortal(newSVuv((UV)ad.sign_count));
            {
                SV *r = ppk_call_cb(aTHX_ *cb, argv, 2, NULL);
                if (r) SvREFCNT_dec(r);
            }
        }
    }

    out = newHV();
    {
        SV *uid = ppk_hv_get(aTHX_ rowh, "user_id");
        (void)hv_stores(out, "user_id", uid ? newSVsv(uid) : newSV(0));
    }
    (void)hv_stores(out, "credential_id", newSVsv(id_b64));
    (void)hv_stores(out, "credential", newSVsv(row));
    (void)hv_stores(out, "sign_count", newSVuv((UV)ad.sign_count));
    (void)hv_stores(out, "clone_signal", newSViv(clone));
    (void)hv_stores(out, "uv", newSViv((ad.flags & PPK_FLAG_UV) ? 1 : 0));
    {
        SV *uh = ppk_hv_get(aTHX_ body, "userHandle");
        (void)hv_stores(out, "user_handle", uh ? newSVsv(uh) : newSV(0));
    }
    return newRV_noinc((SV *)out);
}

#endif /* PPK_AUTH_H */
