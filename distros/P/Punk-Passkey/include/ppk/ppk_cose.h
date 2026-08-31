/* ppk_cose.h - a COSE_Key as WebAuthn sends it, and the way out to a key
 * Crypt::JWS can verify with.
 *
 * An authenticator hands over its public key as a COSE_Key map: small
 * integer labels, byte-string values, no encoding of the key that any
 * general library would recognise. Crypt::JWS imports PEM. This file is
 * the join, and it is deliberately the whole join - a SubjectPublicKeyInfo
 * assembled here from (x, y) or (n, e), armoured as PEM, handed to
 * jws_abi's key_from_pem.
 *
 * WHY NOT AN ABI CALL. Appending key_from_ec_point/key_from_rsa to
 * jws_abi would be less code here and a new version of Crypt::JWS to
 * release, pin and wait for in every consumer that follows. An SPKI is
 * 26 constant bytes and a length in front of a point; writing it costs
 * this file forty lines and costs the ecosystem nothing. If the RSA
 * side ever needs real DER beyond the two integers below, that is the
 * moment to revisit - append-only, `version >= 3`, never equality.
 *
 * WHAT IS REFUSED, AND WHY IT IS REFUSED HERE. The algorithm allowlist
 * lives at this seam because this seam is crossed twice: once when a
 * credential is registered, and again on every login when the stored
 * key is re-imported. A key that was acceptable at registration is
 * checked again at each use, so tightening the allowlist tightens
 * every credential already in the table rather than only the next one.
 *
 *   kty  2 (EC2) with crv 1 (P-256), or 3 (RSA)
 *   alg  -7 (ES256) or -257 (RS256), and it must match kty
 *   x, y exactly 32 bytes, refused rather than padded
 *   n    <= 512 bytes (4096-bit), e <= 8 bytes
 *
 * x and y are refused rather than left-padded on purpose. A 31-byte x
 * is not a 32-byte x with the leading zero dropped as far as this is
 * concerned: it is a document that did not follow the rule, and
 * repairing it means two different documents can produce one key.
 * That is the same argument the Idempotency key makes about repairing
 * client input, and it is the reason the plan called for a test at 31
 * and 33 bytes.
 *
 * Include after ppk_cbor.h.
 */

#ifndef PPK_COSE_H
#define PPK_COSE_H

#define PPK_COSE_KTY_EC2   2
#define PPK_COSE_KTY_RSA   3
#define PPK_COSE_ALG_ES256 (-7)
#define PPK_COSE_ALG_RS256 (-257)
#define PPK_COSE_CRV_P256  1

#define PPK_RSA_N_MAX 512
#define PPK_RSA_E_MAX 8

typedef struct {
    IV  kty;
    IV  alg;
    IV  crv;                       /* EC2 only */
    SV *a;                         /* EC2: x     RSA: n  (borrowed) */
    SV *b;                         /* EC2: y     RSA: e  (borrowed) */
} ppk_cose_key;

/* One integer-labelled entry of a decoded COSE map. */
static SV *ppk_cose_get(pTHX_ HV *hv, const char *label) {
    SV **e = hv_fetch(hv, label, (I32)strlen(label), 0);
    return (e && *e) ? *e : NULL;
}

/* Walk a decoded COSE_Key into the struct, refusing anything off the
 * allowlist. Returns 1 on success; on failure returns 0 and points
 * *why at a static reason. */
static int ppk_cose_parse(pTHX_ SV *decoded, ppk_cose_key *k,
                          const char **why) {
    HV *hv;
    SV *v;

    k->kty = k->alg = k->crv = 0;
    k->a = k->b = NULL;

    if (!(decoded && SvROK(decoded) && SvTYPE(SvRV(decoded)) == SVt_PVHV))
        { *why = "COSE key is not a map"; return 0; }
    hv = (HV *)SvRV(decoded);

    if (!(v = ppk_cose_get(aTHX_ hv, "1")) || !SvIOK(v))
        { *why = "no kty"; return 0; }
    k->kty = SvIV(v);

    if (!(v = ppk_cose_get(aTHX_ hv, "3")) || !SvIOK(v))
        { *why = "no alg"; return 0; }
    k->alg = SvIV(v);

    if (k->kty == PPK_COSE_KTY_EC2) {
        STRLEN xl, yl;
        if (k->alg != PPK_COSE_ALG_ES256)
            { *why = "EC2 key with an algorithm other than ES256"; return 0; }
        if (!(v = ppk_cose_get(aTHX_ hv, "-1")) || !SvIOK(v))
            { *why = "no crv"; return 0; }
        k->crv = SvIV(v);
        if (k->crv != PPK_COSE_CRV_P256)
            { *why = "curve is not P-256"; return 0; }
        if (!(k->a = ppk_cose_get(aTHX_ hv, "-2")) || !SvPOK(k->a))
            { *why = "no x"; return 0; }
        if (!(k->b = ppk_cose_get(aTHX_ hv, "-3")) || !SvPOK(k->b))
            { *why = "no y"; return 0; }
        (void)SvPV_const(k->a, xl);
        (void)SvPV_const(k->b, yl);
        if (xl != 32) { *why = "x is not 32 bytes"; return 0; }
        if (yl != 32) { *why = "y is not 32 bytes"; return 0; }
        return 1;
    }
    if (k->kty == PPK_COSE_KTY_RSA) {
        STRLEN nl, el;
        if (k->alg != PPK_COSE_ALG_RS256)
            { *why = "RSA key with an algorithm other than RS256"; return 0; }
        if (!(k->a = ppk_cose_get(aTHX_ hv, "-1")) || !SvPOK(k->a))
            { *why = "no n"; return 0; }
        if (!(k->b = ppk_cose_get(aTHX_ hv, "-2")) || !SvPOK(k->b))
            { *why = "no e"; return 0; }
        (void)SvPV_const(k->a, nl);
        (void)SvPV_const(k->b, el);
        if (nl == 0 || nl > PPK_RSA_N_MAX) { *why = "n out of range"; return 0; }
        if (el == 0 || el > PPK_RSA_E_MAX) { *why = "e out of range"; return 0; }
        return 1;
    }
    *why = "key type is neither EC2 nor RSA";
    return 0;
}

/* ---- DER, only as much as an SPKI needs -------------------------------- */

static void ppk_der_len(pTHX_ SV *out, STRLEN n) {
    if (n < 0x80) { char b = (char)n; sv_catpvn(out, &b, 1); return; }
    if (n < 0x100) {
        char b[2]; b[0] = (char)0x81; b[1] = (char)n;
        sv_catpvn(out, b, 2); return;
    }
    {   char b[3];
        b[0] = (char)0x82;
        b[1] = (char)((n >> 8) & 0xff);
        b[2] = (char)(n & 0xff);
        sv_catpvn(out, b, 3);
    }
}

/* An unsigned big-endian magnitude as a DER INTEGER: leading zero
 * octets dropped, one 0x00 put back when the top bit would otherwise
 * read as a negative number. */
static void ppk_der_uint(pTHX_ SV *out, const unsigned char *p, STRLEN n) {
    STRLEN i = 0;
    int pad;
    while (i < n && p[i] == 0) i++;
    if (i == n) { sv_catpvs(out, "\x02\x01\x00"); return; }
    pad = (p[i] & 0x80) ? 1 : 0;
    sv_catpvs(out, "\x02");
    ppk_der_len(aTHX_ out, (n - i) + (STRLEN)pad);
    if (pad) sv_catpvs(out, "\x00");
    sv_catpvn(out, (const char *)p + i, n - i);
}

/* The 26-byte prime256v1 SubjectPublicKeyInfo prefix: SEQUENCE(89) of
 * AlgorithmIdentifier { id-ecPublicKey, prime256v1 } and a 66-byte BIT
 * STRING with no unused bits, which the uncompressed point fills
 * exactly. Constant because both the curve and the point format are. */
static const unsigned char ppk_spki_p256[] = {
    0x30,0x59,0x30,0x13,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,0x01,
    0x06,0x08,0x2a,0x86,0x48,0xce,0x3d,0x03,0x01,0x07,0x03,0x42,0x00
};

/* rsaEncryption AlgorithmIdentifier, with the NULL parameters PKCS#1
 * requires. */
static const unsigned char ppk_spki_rsa_alg[] = {
    0x30,0x0d,0x06,0x09,0x2a,0x86,0x48,0x86,0xf7,0x0d,0x01,0x01,0x01,
    0x05,0x00
};

static SV *ppk_spki_from_cose(pTHX_ const ppk_cose_key *k) {
    SV *out = newSVpvs("");
    if (k->kty == PPK_COSE_KTY_EC2) {
        STRLEN xl, yl;
        const char *x = SvPV_const(k->a, xl);
        const char *y = SvPV_const(k->b, yl);
        if (xl != 32 || yl != 32) { SvREFCNT_dec(out); return NULL; }
        sv_catpvn(out, (const char *)ppk_spki_p256, sizeof ppk_spki_p256);
        sv_catpvs(out, "\x04");                  /* uncompressed point */
        sv_catpvn(out, x, 32);
        sv_catpvn(out, y, 32);
        return out;
    }
    if (k->kty == PPK_COSE_KTY_RSA) {
        STRLEN nl, el;
        const unsigned char *n = (const unsigned char *)SvPV_const(k->a, nl);
        const unsigned char *e = (const unsigned char *)SvPV_const(k->b, el);
        SV *rsa = sv_2mortal(newSVpvs(""));      /* RSAPublicKey */
        SV *seq = sv_2mortal(newSVpvs(""));
        SV *bits = sv_2mortal(newSVpvs(""));
        ppk_der_uint(aTHX_ rsa, n, nl);
        ppk_der_uint(aTHX_ rsa, e, el);
        sv_catpvs(seq, "\x30");
        ppk_der_len(aTHX_ seq, SvCUR(rsa));
        sv_catsv(seq, rsa);
        /* BIT STRING wrapping it, no unused bits */
        sv_catpvs(bits, "\x03");
        ppk_der_len(aTHX_ bits, SvCUR(seq) + 1);
        sv_catpvs(bits, "\x00");
        sv_catsv(bits, seq);
        sv_catpvs(out, "\x30");
        ppk_der_len(aTHX_ out, sizeof(ppk_spki_rsa_alg) + SvCUR(bits));
        sv_catpvn(out, (const char *)ppk_spki_rsa_alg,
                  sizeof ppk_spki_rsa_alg);
        sv_catsv(out, bits);
        return out;
    }
    SvREFCNT_dec(out);
    return NULL;
}

/* PEM armour. jws_abi's b64url is the wrong alphabet for this - PEM is
 * standard base64, padded, wrapped at 64 - so the sixteen lines are
 * here rather than borrowed. */
static SV *ppk_pem(pTHX_ SV *der) {
    static const char b64[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    STRLEN len, i;
    const unsigned char *p = (const unsigned char *)SvPV_const(der, len);
    SV *out = newSVpvs("-----BEGIN PUBLIC KEY-----\n");
    int col = 0;
    for (i = 0; i < len; i += 3) {
        unsigned long v = (unsigned long)p[i] << 16;
        STRLEN rem = len - i;
        char q[4];
        if (rem > 1) v |= (unsigned long)p[i + 1] << 8;
        if (rem > 2) v |= (unsigned long)p[i + 2];
        q[0] = b64[(v >> 18) & 0x3f];
        q[1] = b64[(v >> 12) & 0x3f];
        q[2] = rem > 1 ? b64[(v >> 6) & 0x3f] : '=';
        q[3] = rem > 2 ? b64[v & 0x3f]        : '=';
        sv_catpvn(out, q, 4);
        col += 4;
        if (col == 64) { sv_catpvs(out, "\n"); col = 0; }
    }
    if (col) sv_catpvs(out, "\n");
    sv_catpvs(out, "-----END PUBLIC KEY-----\n");
    return out;
}

/* The whole way from a decoded COSE map to PEM, which is what the
 * ceremonies call. NULL with *why set on any refusal. */
static SV *ppk_cose_to_pem(pTHX_ SV *decoded, IV *alg_out, const char **why) {
    ppk_cose_key k;
    SV *der, *pem;
    if (!ppk_cose_parse(aTHX_ decoded, &k, why)) return NULL;
    der = ppk_spki_from_cose(aTHX_ &k);
    if (!der) { *why = "cannot encode the key"; return NULL; }
    pem = ppk_pem(aTHX_ der);
    SvREFCNT_dec(der);
    if (alg_out) *alg_out = k.alg;
    *why = NULL;
    return pem;
}

#endif /* PPK_COSE_H */
