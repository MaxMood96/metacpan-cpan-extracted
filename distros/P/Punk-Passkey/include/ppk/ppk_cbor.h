/* ppk_cbor.h - the CBOR subset WebAuthn actually emits, and nothing else.
 *
 * This decoder faces the network. It is reached with attacker-supplied
 * bytes before anything has been authenticated, so its job is as much
 * REFUSING as decoding, and the refusals are the security posture rather
 * than a list of features not got round to yet.
 *
 * What WebAuthn sends, and therefore all this reads:
 *
 *   - the attestation object: a definite-length map of three entries,
 *     fmt (text), attStmt (map, not examined under the `none` stance),
 *     authData (bytes);
 *   - the COSE public key inside authData: a definite-length map with
 *     small integer keys, byte-string values;
 *   - nothing else. An assertion carries no CBOR at all - its
 *     authenticatorData is a fixed binary layout read by hand.
 *
 * So: definite-length maps, arrays, byte strings and text strings;
 * unsigned and negative integers inside IV; true, false and null.
 * Every other thing CBOR can express is refused with NULL:
 *
 *   indefinite lengths | tags | floats | simple values other than
 *   true/false/null | integers past IV | nesting past PPK_CBOR_MAXDEPTH
 *   | any length that would read past the end | a repeated map key |
 *   trailing bytes after the top-level item
 *
 * Three of those deserve their reason stated where it can be read
 * beside the code:
 *
 *   A REPEATED MAP KEY is refused rather than resolved. Taking the
 *   first or taking the last are both defensible and that is the
 *   problem: two implementations that choose differently disagree
 *   about which algorithm a COSE key names, and a document that says
 *   ES256 to the verifier and something else to whatever logged it is
 *   the shape of a real attack. RFC 8949 calls duplicate keys invalid;
 *   this treats them as invalid rather than as a preference.
 *
 *   INDEFINITE LENGTHS are refused even though they are legal CBOR,
 *   because no authenticator emits them and a streaming decoder is
 *   where the interesting bugs live. Nothing legitimate is lost.
 *
 *   TRAILING BYTES are refused by the caller (ppk_cbor_decode), not
 *   just ignored. A document with something appended is not a document
 *   this understood; treating the prefix as the whole is how one
 *   parser's view of a message stops matching another's.
 *
 * The decoder allocates only through Perl and returns mortal-free,
 * caller-owned SVs; on any refusal it frees what it built and returns
 * NULL, so a partial parse never escapes.
 */

#ifndef PPK_CBOR_H
#define PPK_CBOR_H

/* 4 covers every document WebAuthn defines (attestation object -> attStmt
 * -> x5c array -> certificate bytes). 8 is the refusal point: high enough
 * that no real document is near it, low enough that the recursion cannot
 * run the C stack out on a crafted one. */
#define PPK_CBOR_MAXDEPTH 8

/* An upper bound on how many entries any map or array may carry. A
 * length is read before the bytes behind it exist, so without this a
 * four-byte header claiming four billion entries makes four billion
 * allocations before the truncation is noticed. Everything real is
 * under ten. */
#define PPK_CBOR_MAXITEMS 1024

/* Why an SV per item rather than a struct: the callers (ppk_cose.h, the
 * ceremonies) want to walk a decoded document by key, and Perl's HV is
 * a hash that is already written, already tested and already the thing
 * the XS layer must hand back. Integer map keys are stringified with
 * the sign kept ("-1", "3"), which is exactly how COSE labels read in
 * the spec's own tables. */

typedef struct {
    const unsigned char *p;
    const unsigned char *end;
    int depth;
    const char *err;          /* why it refused, for the diagnostic */
} ppk_cbor;

#define PPK_CBOR_FAIL(c, why) (((c)->err = (why)), (SV *)NULL)

static SV *ppk_cbor_item(pTHX_ ppk_cbor *c);

/* Read the argument that follows a major type's low 5 bits.
 * Returns 0 and sets err on an indefinite length (31) or a reserved
 * additional-information value (28-30); *out receives the argument. */
static int ppk_cbor_arg(pTHX_ ppk_cbor *c, unsigned char ai, UV *out) {
    unsigned n;
    if (ai < 24) { *out = ai; return 1; }
    if (ai == 31) { c->err = "indefinite length"; return 0; }
    if (ai > 27)  { c->err = "reserved additional information"; return 0; }
    n = 1u << (ai - 24);                         /* 1, 2, 4 or 8 bytes */
    if ((UV)(c->end - c->p) < n) { c->err = "truncated argument"; return 0; }
    {
        UV v = 0;
        unsigned i;
        for (i = 0; i < n; i++) v = (v << 8) | c->p[i];
        c->p += n;
        /* An 8-byte argument can exceed what an IV holds, and every
         * consumer of this decoder wants an IV. Refusing here keeps the
         * truncation from happening silently somewhere downstream. */
        if (n == 8 && v > (UV)IV_MAX) { c->err = "integer too large"; return 0; }
        *out = v;
    }
    return 1;
}

/* A definite-length string, byte or text. The length is checked against
 * what is left BEFORE the read - always before, never after. */
static SV *ppk_cbor_string(pTHX_ ppk_cbor *c, unsigned char ai, int text) {
    UV len;
    SV *sv;
    if (!ppk_cbor_arg(aTHX_ c, ai, &len)) return NULL;
    if (len > (UV)(c->end - c->p)) return PPK_CBOR_FAIL(c, "string past end");
    sv = newSVpvn((const char *)c->p, (STRLEN)len);
    c->p += len;
    /* Text strings stay BYTES with the UTF-8 flag off, deliberately.
     * Everything this decoder produces is compared against protocol
     * constants ("fmt", "packed") or hashed, and a flagged scalar
     * entering either is the double-encode bug the house has met
     * before. The one place a text string is human-facing - a
     * credential label - is decoded at that seam, by the code that
     * knows it is text. */
    return sv;
}

static SV *ppk_cbor_array(pTHX_ ppk_cbor *c, unsigned char ai) {
    UV len, i;
    AV *av;
    if (!ppk_cbor_arg(aTHX_ c, ai, &len)) return NULL;
    if (len > PPK_CBOR_MAXITEMS) return PPK_CBOR_FAIL(c, "array too long");
    /* One byte is the least an item can be, so a length past what is
     * left cannot be honest - checked before anything is allocated. */
    if (len > (UV)(c->end - c->p)) return PPK_CBOR_FAIL(c, "array past end");
    av = newAV();
    if (len) av_extend(av, (SSize_t)len - 1);
    for (i = 0; i < len; i++) {
        SV *item = ppk_cbor_item(aTHX_ c);
        if (!item) { SvREFCNT_dec((SV *)av); return NULL; }
        av_push(av, item);
    }
    return newRV_noinc((SV *)av);
}

static SV *ppk_cbor_map(pTHX_ ppk_cbor *c, unsigned char ai) {
    UV len, i;
    HV *hv;
    if (!ppk_cbor_arg(aTHX_ c, ai, &len)) return NULL;
    if (len > PPK_CBOR_MAXITEMS) return PPK_CBOR_FAIL(c, "map too long");
    if (len > (UV)(c->end - c->p)) return PPK_CBOR_FAIL(c, "map past end");
    hv = newHV();
    for (i = 0; i < len; i++) {
        SV *k, *v;
        STRLEN kl;
        const char *kp;
        /* The key. Only an integer or a text string can be one here:
         * COSE labels are integers, the attestation object's keys are
         * text, and a map keyed by a map is not something this needs to
         * have an opinion about. */
        {
            unsigned char ib, mt, kai;
            if (c->p >= c->end)
                { SvREFCNT_dec((SV *)hv); return PPK_CBOR_FAIL(c, "truncated map"); }
            ib = *c->p; mt = (unsigned char)(ib >> 5); kai = ib & 0x1f;
            if (mt != 0 && mt != 1 && mt != 3) {
                SvREFCNT_dec((SV *)hv);
                return PPK_CBOR_FAIL(c, "map key is not an integer or text");
            }
            (void)kai;
        }
        k = ppk_cbor_item(aTHX_ c);
        if (!k) { SvREFCNT_dec((SV *)hv); return NULL; }
        sv_2mortal(k);
        kp = SvPV_const(k, kl);
        /* Refused, not resolved - see the header comment. */
        if (hv_exists(hv, kp, (I32)kl)) {
            SvREFCNT_dec((SV *)hv);
            return PPK_CBOR_FAIL(c, "duplicate map key");
        }
        v = ppk_cbor_item(aTHX_ c);
        if (!v) { SvREFCNT_dec((SV *)hv); return NULL; }
        if (!hv_store(hv, kp, (I32)kl, v, 0)) {
            SvREFCNT_dec(v);
            SvREFCNT_dec((SV *)hv);
            return PPK_CBOR_FAIL(c, "cannot store map key");
        }
    }
    return newRV_noinc((SV *)hv);
}

/* One item, whatever it is. Every path either advances p within bounds
 * and returns an SV, or returns NULL with err set. */
static SV *ppk_cbor_item(pTHX_ ppk_cbor *c) {
    unsigned char ib, mt, ai;
    SV *out;

    if (c->p >= c->end) return PPK_CBOR_FAIL(c, "truncated");
    if (c->depth >= PPK_CBOR_MAXDEPTH) return PPK_CBOR_FAIL(c, "too deep");

    ib = *c->p++;
    mt = (unsigned char)(ib >> 5);
    ai = (unsigned char)(ib & 0x1f);

    switch (mt) {
        case 0: {                                   /* unsigned integer */
            UV v;
            if (!ppk_cbor_arg(aTHX_ c, ai, &v)) return NULL;
            return newSVuv(v);
        }
        case 1: {                                   /* negative integer */
            UV v;
            if (!ppk_cbor_arg(aTHX_ c, ai, &v)) return NULL;
            /* -1 - v, and the encoding means v == IV_MAX is already
             * IV_MIN's magnitude; anything at or past it would wrap. */
            if (v >= (UV)IV_MAX) return PPK_CBOR_FAIL(c, "integer too large");
            return newSViv(-1 - (IV)v);
        }
        case 2:                                     /* byte string */
            return ppk_cbor_string(aTHX_ c, ai, 0);
        case 3:                                     /* text string */
            return ppk_cbor_string(aTHX_ c, ai, 1);
        case 4:                                     /* array */
            c->depth++;
            out = ppk_cbor_array(aTHX_ c, ai);
            c->depth--;
            return out;
        case 5:                                     /* map */
            c->depth++;
            out = ppk_cbor_map(aTHX_ c, ai);
            c->depth--;
            return out;
        case 6:                                     /* tag */
            /* Every tag, including the ones a general decoder would
             * welcome. A tag changes what the bytes underneath MEAN,
             * which is the last thing to accept from a document nobody
             * has authenticated yet. */
            return PPK_CBOR_FAIL(c, "tagged item");
        default:                                    /* 7: simple / float */
            switch (ai) {
                case 20: return newSViv(0);         /* false */
                case 21: return newSViv(1);         /* true  */
                case 22: return newSV(0);           /* null  */
                case 25: case 26: case 27:
                    return PPK_CBOR_FAIL(c, "float");
                default:
                    /* undefined (23), simple(0..19), simple(24..255)
                     * and the reserved values. None appears in
                     * WebAuthn, and `undefined` in particular is a
                     * value with no Perl counterpart worth inventing. */
                    return PPK_CBOR_FAIL(c, "simple value");
            }
    }
}

/* The entry point: one complete item and NOTHING after it.
 *
 * `why` receives a static string naming the refusal when this returns
 * NULL. It exists for the log line, never for the client - a verifier
 * that tells an unauthenticated caller which check it failed is a
 * verifier that helps tune the next attempt. */
static SV *ppk_cbor_decode(pTHX_ const unsigned char *buf, STRLEN len,
                           const char **why) {
    ppk_cbor c;
    SV *out;
    c.p = buf;
    c.end = buf + len;
    c.depth = 0;
    c.err = NULL;
    out = ppk_cbor_item(aTHX_ &c);
    if (!out) { if (why) *why = c.err ? c.err : "malformed"; return NULL; }
    if (c.p != c.end) {
        SvREFCNT_dec(out);
        if (why) *why = "trailing bytes";
        return NULL;
    }
    if (why) *why = NULL;
    return out;
}

/* Decode a prefix and report how much was consumed, for authData's
 * credential-data field: the COSE key is followed by extensions the
 * caller may need to see rather than refuse. Same rules otherwise. */
static SV *ppk_cbor_decode_prefix(pTHX_ const unsigned char *buf, STRLEN len,
                                  STRLEN *used, const char **why) {
    ppk_cbor c;
    SV *out;
    c.p = buf;
    c.end = buf + len;
    c.depth = 0;
    c.err = NULL;
    out = ppk_cbor_item(aTHX_ &c);
    if (!out) { if (why) *why = c.err ? c.err : "malformed"; return NULL; }
    if (used) *used = (STRLEN)(c.p - buf);
    if (why) *why = NULL;
    return out;
}

#endif /* PPK_CBOR_H */
