/* ppk_sig.h - the ECDSA signature two ways round.
 *
 * WebAuthn signs with ECDSA and delivers the signature as ASN.1 DER,
 * SEQUENCE { INTEGER r, INTEGER s }, because that is what every
 * authenticator's crypto library produces. JOSE - and so jws_abi's
 * ES256 verify - takes the raw fixed-width form, r || s, 32 bytes
 * each. Neither side is wrong; they are simply different conventions
 * and something has to convert.
 *
 * That something is thirty lines of parser facing unauthenticated
 * bytes, so it accepts exactly one shape and refuses everything else:
 *
 *   30 <len> 02 <len> <r> 02 <len> <s>      and nothing after it
 *
 * with each INTEGER at most 33 octets, and 33 only when the first is
 * the 0x00 that DER requires in front of a high bit. A shorter
 * integer is left-padded to 32 - that is not repair, it is reading a
 * magnitude, since DER writes 31 octets when the value genuinely fits
 * in 31 and the raw form is fixed-width by definition. A LONGER one is
 * refused: an r that does not fit in 32 bytes is not a P-256 r.
 *
 * RS256 signatures are not touched. PKCS#1 v1.5 is already the fixed
 * width jws_abi wants, so the ceremonies pass those through and only
 * ES256 comes here.
 */

#ifndef PPK_SIG_H
#define PPK_SIG_H

#define PPK_P256_COORD 32

/* Read one DER INTEGER at *pp (bounded by end) as a fixed-width
 * big-endian magnitude into out[width]. Returns 1, or 0 with *why. */
static int ppk_der_int_fixed(const unsigned char **pp,
                             const unsigned char *end,
                             unsigned char *out, STRLEN width,
                             const char **why) {
    const unsigned char *p = *pp;
    STRLEN len;

    if (end - p < 2)          { *why = "truncated integer"; return 0; }
    if (*p++ != 0x02)         { *why = "expected an INTEGER"; return 0; }
    len = *p++;
    /* A P-256 integer is never long enough to need the multi-byte
     * length form, so its presence is itself the refusal. */
    if (len & 0x80)           { *why = "long-form integer length"; return 0; }
    if (len == 0)             { *why = "empty integer"; return 0; }
    if ((STRLEN)(end - p) < len) { *why = "integer past end"; return 0; }

    /* DER: one leading 0x00 is allowed, and only to clear a high bit. */
    if (p[0] == 0x00) {
        if (len == 1) {
            /* a genuine zero; not a valid ECDSA component */
            *why = "zero integer";
            return 0;
        }
        if (!(p[1] & 0x80))   { *why = "non-minimal integer"; return 0; }
        p++; len--;
    }
    else if (p[0] & 0x80)     { *why = "negative integer"; return 0; }

    if (len > width)          { *why = "integer too wide"; return 0; }
    memset(out, 0, width);
    memcpy(out + (width - len), p, len);
    *pp = p + len;
    return 1;
}

/* DER SEQUENCE { r, s } -> the raw 64 bytes ES256 verify wants.
 * Returns an owned SV, or NULL with *why set. */
static SV *ppk_sig_der_to_raw(pTHX_ const unsigned char *der, STRLEN len,
                              const char **why) {
    const unsigned char *p = der, *end = der + len;
    STRLEN slen;
    unsigned char raw[PPK_P256_COORD * 2];

    if (len < 8)      { *why = "signature too short"; return NULL; }
    if (*p++ != 0x30) { *why = "expected a SEQUENCE"; return NULL; }
    slen = *p++;
    if (slen & 0x80)  { *why = "long-form sequence length"; return NULL; }
    /* The sequence must describe exactly what is left - not less, so a
     * signature cannot carry a second document behind it, and not
     * more. */
    if (slen != (STRLEN)(end - p)) { *why = "sequence length mismatch"; return NULL; }

    if (!ppk_der_int_fixed(&p, end, raw, PPK_P256_COORD, why)) return NULL;
    if (!ppk_der_int_fixed(&p, end, raw + PPK_P256_COORD,
                           PPK_P256_COORD, why)) return NULL;
    if (p != end) { *why = "trailing bytes after the signature"; return NULL; }

    *why = NULL;
    return newSVpvn((const char *)raw, sizeof raw);
}

#endif /* PPK_SIG_H */
