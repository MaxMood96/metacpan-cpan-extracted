/* po_hash.h - MurmurHash3 x64 128-bit.
 *
 * This produces the series id, so it is not a hash table's convenience - it
 * is an IDENTITY, computed independently by N workers that never talk to each
 * other. Phase 4 turns on that: if two workers hash the same label set to the
 * same 128 bits with no coordination, per-worker writing is possible; if they
 * do not, nothing else in the design works.
 *
 * WHY 128 BITS. A 64-bit id across ten million series has a birthday collision
 * probability around 0.3%: small enough to feel safe, large enough to happen
 * somewhere in a fleet, and a collision here silently merges two unrelated
 * services into one chart. Nobody would ever find it. 128 bits puts that
 * probability past the point of caring - and the full label block is STILL
 * compared with memcmp before an id is reused, because a hash that is only
 * probably unique is not an identity.
 *
 * WHY MURMUR. Fast, non-cryptographic (this is not a security boundary),
 * fixed by its author, and - the part that matters - it has PUBLISHED TEST
 * VECTORS, so t/0021-series-id.t can assert this implementation against
 * something outside it rather than against itself.
 *
 * MurmurHash3 was written by Austin Appleby and placed in the public domain.
 */
#ifndef PO_HASH_H
#define PO_HASH_H

#include "punk_observe/po_compat.h"

typedef struct { po_u64 hi, lo; } po_h128;

static po_u64 po_rotl64(po_u64 x, int r) {
    return (x << r) | (x >> (64 - r));
}

static po_u64 po_fmix64(po_u64 k) {
    k ^= k >> 33;
    k *= (po_u64)0xff51afd7ed558ccdULL;
    k ^= k >> 33;
    k *= (po_u64)0xc4ceb9fe1a85ec53ULL;
    k ^= k >> 33;
    return k;
}

/* Reads eight bytes little-endian regardless of host order, so the same input
 * gives the same id on every architecture. A big-endian worker and a
 * little-endian one must agree, or a mixed fleet splits every series in two. */
static po_u64 po_getblock64(const uint8_t *p, size_t i) {
    po_u64 v;
    memcpy(&v, p + i * 8, 8);          /* memcpy, not a cast: alignment */
    return po_le64(v);
}

static po_h128 po_murmur3_128(const void *key, size_t len, uint32_t seed) {
    const uint8_t *data = (const uint8_t *)key;
    const size_t nblocks = len / 16;
    po_u64 h1 = seed, h2 = seed;
    const po_u64 c1 = (po_u64)0x87c37b91114253d5ULL;
    const po_u64 c2 = (po_u64)0x4cf5ad432745937fULL;
    size_t i;
    po_h128 out;

    for (i = 0; i < nblocks; i++) {
        po_u64 k1 = po_getblock64(data, i * 2 + 0);
        po_u64 k2 = po_getblock64(data, i * 2 + 1);

        k1 *= c1; k1 = po_rotl64(k1, 31); k1 *= c2; h1 ^= k1;
        h1 = po_rotl64(h1, 27); h1 += h2; h1 = h1 * 5 + 0x52dce729;
        k2 *= c2; k2 = po_rotl64(k2, 33); k2 *= c1; h2 ^= k2;
        h2 = po_rotl64(h2, 31); h2 += h1; h2 = h2 * 5 + 0x38495ab5;
    }

    {
        const uint8_t *tail = data + nblocks * 16;
        po_u64 k1 = 0, k2 = 0;
        switch (len & 15) {
            case 15: k2 ^= ((po_u64)tail[14]) << 48;  /* fallthrough */
            case 14: k2 ^= ((po_u64)tail[13]) << 40;  /* fallthrough */
            case 13: k2 ^= ((po_u64)tail[12]) << 32;  /* fallthrough */
            case 12: k2 ^= ((po_u64)tail[11]) << 24;  /* fallthrough */
            case 11: k2 ^= ((po_u64)tail[10]) << 16;  /* fallthrough */
            case 10: k2 ^= ((po_u64)tail[ 9]) << 8;   /* fallthrough */
            case  9: k2 ^= ((po_u64)tail[ 8]) << 0;
                     k2 *= c2; k2 = po_rotl64(k2, 33); k2 *= c1; h2 ^= k2;
                     /* fallthrough */
            case  8: k1 ^= ((po_u64)tail[ 7]) << 56;  /* fallthrough */
            case  7: k1 ^= ((po_u64)tail[ 6]) << 48;  /* fallthrough */
            case  6: k1 ^= ((po_u64)tail[ 5]) << 40;  /* fallthrough */
            case  5: k1 ^= ((po_u64)tail[ 4]) << 32;  /* fallthrough */
            case  4: k1 ^= ((po_u64)tail[ 3]) << 24;  /* fallthrough */
            case  3: k1 ^= ((po_u64)tail[ 2]) << 16;  /* fallthrough */
            case  2: k1 ^= ((po_u64)tail[ 1]) << 8;   /* fallthrough */
            case  1: k1 ^= ((po_u64)tail[ 0]) << 0;
                     k1 *= c1; k1 = po_rotl64(k1, 31); k1 *= c2; h1 ^= k1;
                     break;
            default: break;
        }
    }

    h1 ^= (po_u64)len; h2 ^= (po_u64)len;
    h1 += h2;
    h2 += h1;
    h1 = po_fmix64(h1);
    h2 = po_fmix64(h2);
    h1 += h2;
    h2 += h1;

    out.lo = h1;
    out.hi = h2;
    return out;
}

/* A 32-bit hash for the in-memory tables, where a collision costs a probe and
 * nothing else. Not used for identity. */
static uint32_t po_hash32(const void *key, size_t len) {
    po_h128 h = po_murmur3_128(key, len, 0);
    return (uint32_t)(h.lo & 0xFFFFFFFFu);
}

static int po_h128_eq(po_h128 a, po_h128 b) {
    return a.hi == b.hi && a.lo == b.lo;
}

#endif /* PO_HASH_H */
