/* po_attr.h - OTLP AnyValue, flattened and sorted.
 *
 * An OTLP attribute value is a tagged union: string, bool, int, double,
 * bytes, array or kvlist. Semantic conventions use the array and map forms in
 * practice, so a store that keeps only string attributes drops real data.
 *
 * Two jobs here, and the second one is the load-bearing one.
 *
 * FLATTEN. Scalars encode to a tag byte plus a value. An array becomes
 * key.0, key.1, ...; a map becomes key.sub, recursively, to a depth of four,
 * below which the remaining subtree is kept as its own encoded bytes rather
 * than expanded. Depth is bounded because the input is untrusted and a
 * thousand nested kvlists would otherwise recurse the C stack to death.
 *
 * SORT. Two spans with the same attributes given in different orders MUST
 * produce byte-identical blocks. Phase 4 derives a series id by hashing this
 * block, with no coordination between workers - so if the order leaks into
 * the bytes, the same series gets two ids, storage doubles, and the
 * cardinality cap counts every series twice. The sort is not a tidiness
 * measure; it is what makes a content-derived identity possible at all.
 */
#ifndef PO_ATTR_H
#define PO_ATTR_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_pb_read.h"
#include "punk_observe/po_rec.h"
#include "otel_proto.h"     /* PB_ANYVALUE_*, PB_KEYVALUE_*, PB_KVLIST_* */

#include <stdlib.h>         /* qsort */

#define PO_ATTR_MAX_DEPTH 4
#define PO_ATTR_MAX       128       /* OTLP's default attribute count limit */
#define PO_ATTR_KEYMAX    256

/* value tags, one byte on the wire in the arena */
#define PO_AV_STRING 1
#define PO_AV_BOOL   2
#define PO_AV_INT    3
#define PO_AV_DOUBLE 4
#define PO_AV_BYTES  5
#define PO_AV_NESTED 6              /* kept encoded: past the depth bound   */

typedef struct {
    char           key[PO_ATTR_KEYMAX];
    size_t         klen;
    uint8_t        tag;
    const uint8_t *sp;              /* borrowed: string/bytes/nested        */
    size_t         slen;
    po_u64         u;               /* int (two's complement) or bool       */
    double         d;
} po_attr;

typedef struct {
    po_attr a[PO_ATTR_MAX];
    int     n;
    int     dropped;                /* over the limit; OTLP wants the count */
} po_attrs;

static void po_attrs_init(po_attrs *s) { s->n = 0; s->dropped = 0; }

/* Append with the key prefix already built. Refuses silently past the limit
 * and counts it, which is what OTLP's dropped_attributes_count is for: a
 * silently truncated attribute set is worse than a visibly truncated one. */
static po_attr *po_attrs_push(po_attrs *s, const char *key, size_t klen) {
    po_attr *a;
    if (s->n >= PO_ATTR_MAX || klen >= PO_ATTR_KEYMAX) { s->dropped++; return NULL; }
    a = &s->a[s->n++];
    memcpy(a->key, key, klen);
    a->klen = klen;
    a->tag  = 0; a->sp = NULL; a->slen = 0; a->u = 0; a->d = 0;
    return a;
}

/* Build "<prefix>.<suffix>" into out, returning its length, or 0 if it would
 * not fit. Used for both the array index and the map key. */
static size_t po_attr_join(char *out, size_t cap,
                           const char *pfx, size_t plen,
                           const char *sfx, size_t slen) {
    if (plen == 0) {
        if (slen >= cap) return 0;
        memcpy(out, sfx, slen);
        return slen;
    }
    if (plen + 1 + slen >= cap) return 0;
    memcpy(out, pfx, plen);
    out[plen] = '.';
    memcpy(out + plen + 1, sfx, slen);
    return plen + 1 + slen;
}

static int po_attr_value(po_pbr *r, po_attrs *s,
                         const char *key, size_t klen, int depth);

/* One KeyValue: key at field 1, value at field 2. */
static int po_attr_kv(po_pbr *r, po_attrs *s,
                      const char *pfx, size_t plen, int depth) {
    uint32_t f, w;
    const uint8_t *kp = NULL; size_t kl = 0;
    po_pbr vsub; int have_value = 0;
    char key[PO_ATTR_KEYMAX];
    size_t keylen;

    /* The value can precede the key on the wire, so both are collected before
     * either is used. Field order within a message is not guaranteed. */
    while (po_pbr_next(r, &f, &w)) {
        if (f == PB_KEYVALUE_KEY && w == PO_PB_BYTES) {
            if (!po_pbr_bytes(r, &kp, &kl)) return 0;
        }
        else if (f == PB_KEYVALUE_VALUE && w == PO_PB_BYTES) {
            if (!po_pbr_sub(r, &vsub)) return 0;
            have_value = 1;
        }
        else if (!po_pbr_skip(r, w)) return 0;
    }
    if (r->err) return 0;
    if (!kp || !have_value) return 1;      /* an incomplete pair is skipped */

    keylen = po_attr_join(key, sizeof(key), pfx, plen, (const char *)kp, kl);
    if (!keylen) { s->dropped++; return 1; }
    return po_attr_value(&vsub, s, key, keylen, depth);
}

/* One AnyValue. */
static int po_attr_value(po_pbr *r, po_attrs *s,
                         const char *key, size_t klen, int depth) {
    uint32_t f, w;
    const uint8_t *start = r->p;
    size_t whole = (size_t)(r->end - r->p);

    while (po_pbr_next(r, &f, &w)) {
        switch (f) {
            case PB_ANYVALUE_STRING: {
                const uint8_t *p; size_t n; po_attr *a;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_bytes(r, &p, &n)) return 0;
                if ((a = po_attrs_push(s, key, klen)))
                    { a->tag = PO_AV_STRING; a->sp = p; a->slen = n; }
                break;
            }
            case PB_ANYVALUE_BOOL: {
                po_u64 v; po_attr *a;
                if (w != PO_PB_VARINT) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_varint(r, &v)) return 0;
                if ((a = po_attrs_push(s, key, klen)))
                    { a->tag = PO_AV_BOOL; a->u = v ? 1 : 0; }
                break;
            }
            case PB_ANYVALUE_INT: {
                po_u64 v; po_attr *a;
                if (w != PO_PB_VARINT) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_varint(r, &v)) return 0;
                if ((a = po_attrs_push(s, key, klen)))
                    { a->tag = PO_AV_INT; a->u = v; }   /* two's complement */
                break;
            }
            case PB_ANYVALUE_DOUBLE: {
                double d; po_attr *a;
                if (w != PO_PB_FIXED64) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_double(r, &d)) return 0;
                if ((a = po_attrs_push(s, key, klen)))
                    { a->tag = PO_AV_DOUBLE; a->d = d; }
                break;
            }
            case PB_ANYVALUE_BYTES: {
                const uint8_t *p; size_t n; po_attr *a;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_bytes(r, &p, &n)) return 0;
                if ((a = po_attrs_push(s, key, klen)))
                    { a->tag = PO_AV_BYTES; a->sp = p; a->slen = n; }
                break;
            }
            case PB_ANYVALUE_ARRAY: {
                po_pbr arr; uint32_t af, aw; int idx = 0;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_sub(r, &arr)) return 0;
                if (depth >= PO_ATTR_MAX_DEPTH) goto keep_nested;
                while (po_pbr_next(&arr, &af, &aw)) {
                    if (af == PB_ARRAYVALUE_VALUES && aw == PO_PB_BYTES) {
                        po_pbr el; char k[PO_ATTR_KEYMAX]; char num[16];
                        size_t nl = 0, kl2; int t = idx++;
                        /* decimal index, written backwards then reversed */
                        if (t == 0) num[nl++] = '0';
                        else { char tmp[16]; size_t tn = 0;
                               while (t) { tmp[tn++] = (char)('0' + t % 10); t /= 10; }
                               while (tn) num[nl++] = tmp[--tn]; }
                        if (!po_pbr_sub(&arr, &el)) { po_pbr_join(r, &arr); return 0; }
                        kl2 = po_attr_join(k, sizeof(k), key, klen, num, nl);
                        if (!kl2) { s->dropped++; continue; }
                        if (!po_attr_value(&el, s, k, kl2, depth + 1))
                            { po_pbr_join(r, &arr); return 0; }
                    }
                    else if (!po_pbr_skip(&arr, aw)) { po_pbr_join(r, &arr); return 0; }
                }
                po_pbr_join(r, &arr);
                if (r->err) return 0;
                break;
            }
            case PB_ANYVALUE_KVLIST: {
                po_pbr kvl; uint32_t kf, kw;
                if (w != PO_PB_BYTES) { if (!po_pbr_skip(r, w)) return 0; break; }
                if (!po_pbr_sub(r, &kvl)) return 0;
                if (depth >= PO_ATTR_MAX_DEPTH) goto keep_nested;
                while (po_pbr_next(&kvl, &kf, &kw)) {
                    if (kf == PB_KVLIST_VALUES && kw == PO_PB_BYTES) {
                        po_pbr kv;
                        if (!po_pbr_sub(&kvl, &kv)) { po_pbr_join(r, &kvl); return 0; }
                        if (!po_attr_kv(&kv, s, key, klen, depth + 1))
                            { po_pbr_join(r, &kvl); return 0; }
                    }
                    else if (!po_pbr_skip(&kvl, kw)) { po_pbr_join(r, &kvl); return 0; }
                }
                po_pbr_join(r, &kvl);
                if (r->err) return 0;
                break;
            }
            default:
                if (!po_pbr_skip(r, w)) return 0;
        }
    }
    return r->err ? 0 : 1;

keep_nested: {
        /* Past the depth bound: keep the subtree's own bytes rather than
         * expanding it. The data is preserved and searchable as an opaque
         * value, and the recursion stops. */
        po_attr *a = po_attrs_push(s, key, klen);
        if (a) { a->tag = PO_AV_NESTED; a->sp = start; a->slen = whole; }
        r->p = r->end;
        return 1;
    }
}

/* Sort by key, then by tag, then by value bytes. A total order: two attribute
 * sets that differ only in the order they were given must compare equal, and
 * two that differ in any content must not. */
static int po_attr_cmp(const void *va, const void *vb) {
    const po_attr *a = (const po_attr *)va, *b = (const po_attr *)vb;
    size_t n = a->klen < b->klen ? a->klen : b->klen;
    int c = memcmp(a->key, b->key, n);
    if (c) return c;
    if (a->klen != b->klen) return a->klen < b->klen ? -1 : 1;
    if (a->tag != b->tag) return a->tag < b->tag ? -1 : 1;
    switch (a->tag) {
        case PO_AV_STRING: case PO_AV_BYTES: case PO_AV_NESTED: {
            size_t m = a->slen < b->slen ? a->slen : b->slen;
            c = m ? memcmp(a->sp, b->sp, m) : 0;
            if (c) return c;
            return a->slen == b->slen ? 0 : (a->slen < b->slen ? -1 : 1);
        }
        case PO_AV_DOUBLE:
            /* Bit pattern, not value: -0.0 and 0.0 are different attributes,
             * and NaN must order consistently rather than compare unequal to
             * itself and make the sort unstable. */
            return memcmp(&a->d, &b->d, sizeof(double));
        default:
            return a->u == b->u ? 0 : (a->u < b->u ? -1 : 1);
    }
}

static void po_attrs_sort(po_attrs *s) {
    if (s->n > 1) qsort(s->a, (size_t)s->n, sizeof(po_attr), po_attr_cmp);
}

/* Serialise the sorted set into the arena as a self-contained block:
 *
 *     [varint count] ( [varint klen][key][tag][value] )*
 *
 * Deterministic by construction, so hashing it is hashing the attribute set.
 * Returns the offset, or PO_ARENA_ERR. */
static uint32_t po_attrs_encode(po_attrs *s, po_arena *ar, uint32_t *len_out) {
    char hdr[16];
    size_t hn = 0;
    uint32_t off, i;
    po_u64 n = (po_u64)s->n;

    po_attrs_sort(s);

    do { hdr[hn] = (char)((n & 0x7F) | (n > 0x7F ? 0x80 : 0)); n >>= 7; hn++; }
    while (n);
    off = po_arena_put(ar, hdr, hn);
    if (off == PO_ARENA_ERR) return PO_ARENA_ERR;

    for (i = 0; i < (uint32_t)s->n; i++) {
        const po_attr *a = &s->a[i];
        char b[16]; size_t bn = 0; po_u64 k = (po_u64)a->klen;
        char tag = (char)a->tag;
        do { b[bn] = (char)((k & 0x7F) | (k > 0x7F ? 0x80 : 0)); k >>= 7; bn++; }
        while (k);
        if (po_arena_put(ar, b, bn) == PO_ARENA_ERR) return PO_ARENA_ERR;
        if (po_arena_put(ar, a->key, a->klen) == PO_ARENA_ERR) return PO_ARENA_ERR;
        if (po_arena_put(ar, &tag, 1) == PO_ARENA_ERR) return PO_ARENA_ERR;
        switch (a->tag) {
            case PO_AV_STRING: case PO_AV_BYTES: case PO_AV_NESTED: {
                char l[16]; size_t ln = 0; po_u64 v = (po_u64)a->slen;
                do { l[ln] = (char)((v & 0x7F) | (v > 0x7F ? 0x80 : 0)); v >>= 7; ln++; }
                while (v);
                if (po_arena_put(ar, l, ln) == PO_ARENA_ERR) return PO_ARENA_ERR;
                if (a->slen && po_arena_put(ar, (const char *)a->sp, a->slen)
                        == PO_ARENA_ERR) return PO_ARENA_ERR;
                break;
            }
            case PO_AV_DOUBLE: {
                po_u64 bits; memcpy(&bits, &a->d, 8); bits = po_le64(bits);
                if (po_arena_put(ar, (const char *)&bits, 8) == PO_ARENA_ERR)
                    return PO_ARENA_ERR;
                break;
            }
            default: {
                po_u64 v = po_le64(a->u);
                if (po_arena_put(ar, (const char *)&v, 8) == PO_ARENA_ERR)
                    return PO_ARENA_ERR;
                break;
            }
        }
    }
    *len_out = (uint32_t)(ar->len - off);
    return off;
}

/* Read a repeated KeyValue field (resource, scope, span or log attributes). */
static int po_attrs_read(po_pbr *r, po_attrs *s) {
    po_pbr kv;
    if (!po_pbr_sub(r, &kv)) return 0;
    if (!po_attr_kv(&kv, s, NULL, 0, 0)) { po_pbr_join(r, &kv); return 0; }
    po_pbr_join(r, &kv);
    return !r->err;
}

#endif /* PO_ATTR_H */
