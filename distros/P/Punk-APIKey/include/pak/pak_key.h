#ifndef PAK_KEY_H
#define PAK_KEY_H

/* The key format.
 *
 *     <kind prefix><43 chars base64url><6 chars base62>
 *     sk_live_ + wRq3...  (43)        + 7bQ2xF
 *
 * The random part is Punk::Auth::Password::token() - 32 bytes of pid-guarded
 * sliced entropy as 43 characters of unpadded base64url. Punk already does
 * that correctly, in C, so this calls it rather than probing getentropy for a
 * second time and getting it subtly different.
 *
 * The checksum is CRC32 over those 43 characters, base62, zero padded to six.
 * See pak_hash.h for why it is there.
 *
 * What is STORED is the SHA-256 of the whole key (Punk::Auth::Password::
 * token_digest, the same function and the same wire form auth_tokens uses)
 * plus a `prefix` column of the kind prefix and the first eight random
 * characters - enough to recognise a key in a list, not enough to rebuild it.
 *
 * SHA-256 and not PBKDF2, deliberately: a password needs a slow hash because
 * a person chose it and the search space is small. A key with 256 bits of
 * entropy has no search space to speak of, and the lookup is an equality test
 * on a unique index, which is not a timing oracle on anything.
 */

#define PAK_RAND_LEN 43
#define PAK_KEY_TAIL (PAK_RAND_LEN + PAK_CK_LEN)   /* after the prefix */
#define PAK_PREFIX_KEEP 8                            /* stored, for the list */

enum {
    PAK_OK = 0,
    PAK_MALFORMED,      /* wrong length, or a character outside the alphabet */
    PAK_BAD_CHECKSUM,   /* the shape is right and the digits do not agree    */
    PAK_UNKNOWN_KIND    /* no configured prefix matches                      */
};

static int pak_is_b64url(char ch)
{
    return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
        || (ch >= '0' && ch <= '9') || ch == '-' || ch == '_';
}

static int pak_is_b62(char ch)
{
    return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
        || (ch >= '0' && ch <= '9');
}

/* The kinds hash is { kind => prefix }. Longest prefix first, so that with
 * `sk_` and `sk_live_` both configured a live key is not read as a bare one -
 * though the boot check refuses that pair outright, because relying on match
 * order to tell two credentials apart is a rule nobody can see. */
static SV *pak_match_kind(pTHX_ HV *kinds, const char *s, STRLEN len,
                           STRLEN *plen)
{
    HE *he;
    SV *best = NULL;
    STRLEN blen = 0;

    if (!kinds) return NULL;
    hv_iterinit(kinds);
    while ((he = hv_iternext(kinds))) {
        SV *pfx = HeVAL(he);
        STRLEN pl;
        const char *pp;
        if (!(pfx && SvOK(pfx))) continue;
        pp = SvPV_const(pfx, pl);
        if (pl > len || memNE(s, pp, pl)) continue;
        if (!best || pl > blen) {
            best = HeSVKEY_force(he);   /* the KIND, not the prefix */
            blen = pl;
        }
    }
    if (best && plen) *plen = blen;
    return best;
}

/* Parse a presented credential. `kind` comes back as the kind NAME (a
 * mortal SV) when one matched. Nothing here touches the database: a key that
 * fails this never becomes a query. */
static int pak_parse(pTHX_ HV *kinds, const char *s, STRLEN len, SV **kind)
{
    STRLEN plen = 0;
    SV *k;
    const char *rand_part;
    STRLEN i;
    U32 crc;
    char want[PAK_CK_LEN];

    if (kind) *kind = NULL;
    if (!s || !len) return PAK_MALFORMED;

    k = pak_match_kind(aTHX_ kinds, s, len, &plen);
    if (!k) return PAK_UNKNOWN_KIND;
    if (kind) *kind = k;

    if (len - plen != PAK_KEY_TAIL) return PAK_MALFORMED;
    rand_part = s + plen;

    for (i = 0; i < PAK_RAND_LEN; i++)
        if (!pak_is_b64url(rand_part[i])) return PAK_MALFORMED;
    for (i = PAK_RAND_LEN; i < PAK_KEY_TAIL; i++)
        if (!pak_is_b62(rand_part[i])) return PAK_MALFORMED;

    crc = pak_crc32(rand_part, PAK_RAND_LEN);
    pak_b62_6(crc, want);
    if (memNE(rand_part + PAK_RAND_LEN, want, PAK_CK_LEN))
        return PAK_BAD_CHECKSUM;

    return PAK_OK;
}

/* Mint: prefix . token() . checksum. Returns a new SV (+1). */
static SV *pak_mint(pTHX_ SV *prefix)
{
    SV *tok = sv_2mortal(pak_call_common(aTHX_ NULL,
                  "Punk::Auth::Password::token", NULL, NULL, 0));
    STRLEN tl;
    const char *tp;
    SV *out;
    char ck[PAK_CK_LEN];

    if (!(tok && SvOK(tok)))
        croak("Punk::Plugin::APIKey: Punk::Auth::Password::token gave nothing");
    tp = SvPV_const(tok, tl);
    if (tl < PAK_RAND_LEN)
        croak("Punk::Plugin::APIKey: token is %d characters, expected %d",
              (int)tl, (int)PAK_RAND_LEN);

    pak_b62_6(pak_crc32(tp, PAK_RAND_LEN), ck);

    out = newSVsv(prefix && SvOK(prefix) ? prefix : &PL_sv_no);
    if (!(prefix && SvOK(prefix))) sv_setpvs(out, "");
    sv_catpvn(out, tp, PAK_RAND_LEN);
    sv_catpvn(out, ck, PAK_CK_LEN);
    return out;
}

/* The stored digest: lowercase SHA-256 hex of the whole key, through the same
 * function Punk::Auth uses for its one-time tokens - so the two are the same
 * wire form and neither has its own crypto. */
static SV *pak_digest(pTHX_ SV *key)
{
    SV *argv[1];
    argv[0] = key;
    return pak_call_common(aTHX_ NULL, "Punk::Auth::Password::token_digest",
                            NULL, argv, 1);
}

/* The `prefix` column: the kind prefix plus the first eight random
 * characters. Recognisable in a list, useless as a credential. */
static SV *pak_stored_prefix(pTHX_ SV *key, STRLEN plen)
{
    STRLEN kl;
    const char *kp = SvPV_const(key, kl);
    STRLEN keep = plen + PAK_PREFIX_KEEP;
    if (keep > kl) keep = kl;
    return newSVpvn(kp, keep);
}

#endif /* PAK_KEY_H */
