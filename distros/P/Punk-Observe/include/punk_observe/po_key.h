/* po_key.h - ingest keys.
 *
 * A self-hosted box exposing the ingest prefix to the network wants that
 * endpoint authenticated, and the exporter side already has the channel: a
 * bearer token in `Authorization`, which is what `OTEL_EXPORTER_OTLP_HEADERS`
 * gives every OpenTelemetry SDK for free. No new mechanism, no client
 * change.
 *
 * A KEY IS STORED AS A HASH, NEVER AS THE TOKEN.
 *
 * The key file lives in `/etc`, gets backed up, and ends up in a
 * configuration-management repository. As a list of tokens it is a list of
 * credentials; as a list of hashes it is a list of nothing useful. The token
 * exists once, at the moment it is issued.
 *
 * A KEY COMPARED WITH `eq` IS A TIMING ORACLE.
 *
 * `memcmp` and every string compare in every language return as soon as two
 * bytes differ, so the time taken leaks the length of the matching prefix,
 * and an attacker recovers a key one byte at a time. The comparison here is
 * constant-time by construction: it always reads every byte and accumulates
 * differences rather than branching on them.
 *
 * That is asserted structurally rather than by measurement. A timing test on
 * a loaded smoker measures the smoker.
 *
 * AN INGEST KEY IS NOT THE SESSION CREDENTIAL.
 *
 * Keys are scoped to ingest and cannot read the UI. A key that could do both
 * leaks a whole installation the first time it is baked into a container
 * image, which is where ingest keys go.
 */
#ifndef PO_KEY_H
#define PO_KEY_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_hash.h"

#define PO_KEY_MAX      256    /* a presented token, before hashing */
#define PO_KEY_NAME_MAX 64
#define PO_KEYS_MAX     256

/* A 128-bit content hash. Not a password KDF, and that is a deliberate
 * choice with a reason: an ingest key is high-entropy machine-generated
 * material, not a human-chosen password, so there is no dictionary to
 * stretch against. What the hash buys is that the file is not a credential.
 *
 * If keys were ever allowed to be user-chosen this would be the wrong
 * primitive, which is why they are generated and never accepted. */
typedef struct {
    char     name[PO_KEY_NAME_MAX + 1];
    size_t   name_len;
    po_u64   h_hi, h_lo;
    int      revoked;
} po_key;

typedef struct {
    po_key   k[PO_KEYS_MAX];
    uint32_t n;
    int      required;      /* 0 = the endpoint is open, and says so */
} po_keyring;

static void po_keyring_init(po_keyring *r) { memset(r, 0, sizeof(*r)); }

static void po_key_hash(const char *tok, size_t len, po_u64 *hi, po_u64 *lo) {
    /* A FIXED seed, so a hash computed at issue time matches one computed at
     * check time in another process. A per-process seed would make every
     * stored hash useless after a restart, which is the kind of bug that only
     * shows up on the first reboot after a deployment. */
    po_h128 h = po_murmur3_128(tok, len, 0x6f627365u);
    *hi = h.hi; *lo = h.lo;
}

static int po_keyring_add(po_keyring *r, const char *name, size_t nlen,
                          const char *tok, size_t tlen) {
    po_key *k;
    if (r->n >= PO_KEYS_MAX) return 0;
    if (!tok || !tlen || tlen > PO_KEY_MAX) return 0;
    if (nlen > PO_KEY_NAME_MAX) nlen = PO_KEY_NAME_MAX;
    k = &r->k[r->n++];
    memset(k, 0, sizeof(*k));
    if (nlen) memcpy(k->name, name, nlen);
    k->name_len = nlen;
    po_key_hash(tok, tlen, &k->h_hi, &k->h_lo);
    r->required = 1;
    return 1;
}

/* Add an already-hashed key, which is what reading the key file does. The
 * file holds hashes; nothing on disk holds a token. */
static int po_keyring_add_hash(po_keyring *r, const char *name, size_t nlen,
                               po_u64 hi, po_u64 lo) {
    po_key *k;
    if (r->n >= PO_KEYS_MAX) return 0;
    if (nlen > PO_KEY_NAME_MAX) nlen = PO_KEY_NAME_MAX;
    k = &r->k[r->n++];
    memset(k, 0, sizeof(*k));
    if (nlen) memcpy(k->name, name, nlen);
    k->name_len = nlen;
    k->h_hi = hi; k->h_lo = lo;
    r->required = 1;
    return 1;
}

/* CONSTANT TIME, and structurally so.
 *
 * No early return, no branch on the data, and the accumulator is or-ed rather
 * than tested. The compiler is free to vectorise it; what it is not free to
 * do is short-circuit, because there is no condition to short-circuit on. */
static int po_ct_eq128(po_u64 a_hi, po_u64 a_lo, po_u64 b_hi, po_u64 b_lo) {
    po_u64 d = (a_hi ^ b_hi) | (a_lo ^ b_lo);
    /* Fold to one bit without a comparison: d is zero exactly when equal. */
    d |= d >> 32; d |= d >> 16; d |= d >> 8;
    d |= d >> 4;  d |= d >> 2;  d |= d >> 1;
    return (int)((d & 1) ^ 1);
}

/* Bearer parsing. The scheme is matched case-insensitively because RFC 7235
 * says it is case-insensitive, and an exporter sending `bearer` lowercase is
 * not a client to break. */
static int po_bearer(const char *hdr, size_t len, const char **tok,
                     size_t *tlen) {
    size_t i = 0;
    static const char pre[] = "bearer";
    if (!hdr || len < 7) return 0;
    for (i = 0; i < 6; i++) {
        char c = hdr[i];
        if (c >= 'A' && c <= 'Z') c = (char)(c - 'A' + 'a');
        if (c != pre[i]) return 0;
    }
    i = 6;
    if (hdr[i] != ' ' && hdr[i] != '\t') return 0;
    while (i < len && (hdr[i] == ' ' || hdr[i] == '\t')) i++;
    if (i >= len) return 0;
    *tok  = hdr + i;
    *tlen = len - i;
    return 1;
}

#define PO_AUTH_OK       0
#define PO_AUTH_MISSING  1
#define PO_AUTH_BAD      2
#define PO_AUTH_REVOKED  3

/* Check a presented token.
 *
 * EVERY KEY IS EXAMINED even after a match, so the time taken does not depend
 * on WHICH key matched or on how many are configured. A loop that returned on
 * the first hit would leak the position of a key in the ring, which is a
 * smaller oracle than a byte-at-a-time one but is free to close. */
static int po_keyring_check(const po_keyring *r, const char *tok, size_t tlen,
                            const char **name, size_t *nlen) {
    po_u64 hi, lo;
    uint32_t i;
    int found = 0, revoked = 0;
    const char *hit_name = NULL;
    size_t hit_len = 0;

    if (!r->required) return PO_AUTH_OK;      /* configured open, deliberately */
    if (!tok || !tlen || tlen > PO_KEY_MAX) return PO_AUTH_MISSING;

    po_key_hash(tok, tlen, &hi, &lo);
    for (i = 0; i < r->n; i++) {
        int eq = po_ct_eq128(hi, lo, r->k[i].h_hi, r->k[i].h_lo);
        if (eq) {
            found = 1;
            revoked = r->k[i].revoked;
            hit_name = r->k[i].name;
            hit_len  = r->k[i].name_len;
        }
    }
    if (!found) return PO_AUTH_BAD;
    if (revoked) return PO_AUTH_REVOKED;
    if (name) *name = hit_name;
    if (nlen) *nlen = hit_len;
    return PO_AUTH_OK;
}

static int po_keyring_revoke(po_keyring *r, const char *name, size_t nlen) {
    uint32_t i;
    int n = 0;
    for (i = 0; i < r->n; i++)
        if (r->k[i].name_len == nlen
            && (nlen == 0 || memcmp(r->k[i].name, name, nlen) == 0)) {
            r->k[i].revoked = 1;
            n++;
        }
    return n;
}

#endif /* PO_KEY_H */
