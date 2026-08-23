#ifndef FRH_ABI_H
#define FRH_ABI_H

#include <stddef.h>

/* frh_abi.h - the C ABI File::Raw::Hash exposes to other XS
 * distributions.
 *
 * Reached at runtime through File::Raw::Hash::_abi_ptr, never by
 * linking:
 *
 *     dSP; IV p = 0;
 *     PUSHMARK(SP); PUTBACK;
 *     if (call_pv("File::Raw::Hash::_abi_ptr", G_SCALAR|G_EVAL) > 0) {
 *         SPAGAIN; p = POPi; PUTBACK;
 *     }
 *     const frh_abi *H = p ? INT2PTR(const frh_abi *, p) : NULL;
 *     #define MY_FRH_NEED 1
 *     if (!H || H->version < MY_FRH_NEED) croak(...);
 *
 * The check is >= against the version whose members YOU call - a
 * constant you define - never this header's FRH_ABI_VERSION and never
 * equality. The table is append-only: a provider newer than your
 * header is always safe, and compiling against a newer header must
 * not raise your runtime requirement. An equality check turns every
 * append into a breaking change for consumers already shipped.
 *
 * No perl types cross this seam. Handles are opaque and die in
 * runner_free; digests land in caller buffers sized from the
 * registry; nothing here mallocs on the caller's behalf.
 *
 * Charter: digests, HMAC, cache keys, content addressing, checksums.
 * For keys, signatures and JWS - anywhere libcrypto is the point
 * rather than a cost - use Crypt::JWS's jws_abi instead.
 */

#define FRH_ABI_VERSION 1

/* One registry row. Algorithm ids are dense, stable and append-only:
 * the ids this version ships keep their values forever and a new
 * algorithm takes the next one, so a consumer may cache ids across
 * its own lifetime. */
typedef struct {
    const char *name;          /* canonical: "sha256", "blake3", ... */
    int         id;
    size_t      digest_size;   /* raw bytes */
    int         hmac_able;
    size_t      block_size;    /* HMAC block size; 0 when !hmac_able */
} frh_algo_t;

typedef struct frh_abi {
    int version;

    /* --- registry ---------------------------------------------------------
     * Rows live for the process; NULL on unknown name / out-of-range
     * id. Ids run 0 .. algo_count()-1 with no holes. */
    const frh_algo_t *(*algo_by_name)(const char *name, size_t len);
    const frh_algo_t *(*algo_by_id)(int id);
    int               (*algo_count)(void);

    /* --- one-shot ---------------------------------------------------------
     * Digest `n` bytes into out, which must hold digest_size bytes for
     * the id. Returns 0; -1 on bad id (and, for hmac, an id that is
     * not hmac_able). Raw bytes: for the integer checksums (crc32,
     * xxh64) that is the big-endian rendering of the value, matching
     * what the hex format prints. */
    int (*digest)(int id, const unsigned char *in, size_t n,
                  unsigned char *out);
    int (*hmac)(int id, const unsigned char *key, size_t klen,
                const unsigned char *in, size_t n,
                unsigned char *out);

    /* --- the lockstep runner ----------------------------------------------
     * One byte stream, many digests, one pass. new_runner copies ids
     * (each 0 .. algo_count()-1; duplicates allowed); `seed` is
     * consulted only by xxh64 entries, pass 0 for the default. NULL on
     * bad ids or allocation failure.
     *
     * set_hmac upgrades every algorithm or fails atomically: -1 when
     * any id is not hmac_able, and the runner stays usable in plain
     * mode. Call it before the first update.
     *
     * finish writes raw bytes into outs[i] - digest_size bytes for the
     * i-th id as given to new_runner - and a runner finishes exactly
     * once: a second finish returns -1 and writes nothing. free
     * releases the handle; free(NULL) is a no-op. */
    void *(*new_runner)(const int *ids, int n, unsigned long long seed);
    int   (*runner_set_hmac)(void *r, const unsigned char *key,
                             size_t klen);
    void  (*runner_update)(void *r, const void *data, size_t len);
    int   (*runner_finish)(void *r, unsigned char **outs);
    void  (*runner_free)(void *r);
} frh_abi;

#endif /* FRH_ABI_H */
