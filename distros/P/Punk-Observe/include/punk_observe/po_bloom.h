/* po_bloom.h - a trigram bloom filter, one per log block.
 *
 * The problem: a log search must not decompress every block the label filter
 * leaves. The classic answers are both wrong here.
 *
 *   - Index every term (the Elasticsearch shape). The index approaches the
 *     size of the data and a high-cardinality field inflates it without
 *     bound.
 *   - Index nothing and scan (the plain Loki shape). Correct, and it
 *     decompresses everything the labels leave.
 *
 * This filter is the third option: it stores NO TEXT and answers exactly one
 * question, "can this block possibly contain that substring". A block whose
 * answer is no is skipped unopened. A block whose answer is yes is
 * decompressed and matched EXACTLY, so a false positive costs one
 * decompression and never a wrong answer.
 *
 * THE ASYMMETRY IS THE WHOLE DESIGN.
 *
 *   A false positive  = a wasted decompression.
 *   A false negative   = A LOST LOG LINE.
 *
 * There is no acceptable rate of the second, so the bit count is derived from
 * the measured distinct-trigram count rather than picked, and t/0041-bloom.t
 * asserts zero false negatives over a generated corpus. That test is the
 * reason this file exists in this shape.
 *
 * (Search::Trigram was the obvious candidate and is not usable: sg_abi.h:66-69
 * copies each document's text INTO the index and the table has no serialise
 * at all, so it is an in-memory document store rather than something a sealed
 * segment can carry.)
 */
#ifndef PO_BLOOM_H
#define PO_BLOOM_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_hash.h"

/* Two independent hashes, derived from one 128-bit murmur by taking its two
 * halves. Kirsch-Mitzenmacher: h_i = h1 + i*h2 gives k hashes from two with no
 * measurable loss, so this costs one hash per trigram rather than k. */
#define PO_BLOOM_K 4

typedef struct {
    unsigned char *bits;
    uint32_t       nbits;      /* always a power of two, so masking works */
    uint32_t       mask;
    uint32_t       added;      /* trigrams inserted, for the sizing report */
} po_bloom;

/* Size from the expected distinct-trigram count and a target false-positive
 * rate. The optimal m/n for rate p is -ln(p)/(ln2)^2; for p = 1% that is
 * about 9.6 bits per element, which this rounds up to the next power of two
 * so the index can mask instead of dividing. */
static uint32_t po_bloom_bits_for(uint32_t n) {
    po_u64 want = (po_u64)n * 10 + 64;    /* ~10 bits each, plus a floor */
    uint32_t p = 64;
    while ((po_u64)p < want && p < (1u << 30)) p <<= 1;
    return p;
}

static int po_bloom_init(po_bloom *b, uint32_t expect) {
    memset(b, 0, sizeof(*b));
    b->nbits = po_bloom_bits_for(expect);
    b->mask  = b->nbits - 1;
    b->bits  = (unsigned char *)calloc((b->nbits + 7) / 8, 1);
    return b->bits != NULL;
}

static void po_bloom_free(po_bloom *b) { free(b->bits); b->bits = NULL; }

static void po_bloom_set(po_bloom *b, const char *p, size_t len) {
    po_h128 h = po_murmur3_128(p, len, 0);
    int i;
    for (i = 0; i < PO_BLOOM_K; i++) {
        uint32_t bit = (uint32_t)((h.lo + (po_u64)i * h.hi) & b->mask);
        b->bits[bit >> 3] |= (unsigned char)(1 << (bit & 7));
    }
    b->added++;
}

static int po_bloom_test_raw(const unsigned char *bits, uint32_t mask,
                             const char *p, size_t len) {
    po_h128 h = po_murmur3_128(p, len, 0);
    int i;
    for (i = 0; i < PO_BLOOM_K; i++) {
        uint32_t bit = (uint32_t)((h.lo + (po_u64)i * h.hi) & mask);
        if (!(bits[bit >> 3] & (1 << (bit & 7)))) return 0;   /* definitely not */
    }
    return 1;                                                 /* possibly */
}

static int po_bloom_test(const po_bloom *b, const char *p, size_t len) {
    return po_bloom_test_raw(b->bits, b->mask, p, len);
}

/* ---- trigrams -------------------------------------------------------------
 *
 * BYTE trigrams, not character ones. A trigram may split a UTF-8 codepoint,
 * which is harmless BECAUSE the filter only ever prunes and the surviving
 * block is matched exactly - and because the query is split by the identical
 * rule, so the same split happens on both sides. Documented here so nobody
 * later "fixes" it into a codepoint-aware version that no longer matches what
 * was indexed.
 *
 * Case folding is applied at BOTH index and query time. Folding only at query
 * time would skip blocks containing the term in another case, which is a
 * false negative wearing a disguise.
 */
static unsigned char po_fold(unsigned char c) {
    return (c >= 'A' && c <= 'Z') ? (unsigned char)(c - 'A' + 'a') : c;
}

typedef void (*po_trigram_cb)(void *ud, const char *tri);

static void po_trigrams(const char *p, size_t len, po_trigram_cb cb, void *ud) {
    size_t i;
    char t[3];
    if (len < 3) return;                 /* see po_bloom_query_usable */
    for (i = 0; i + 3 <= len; i++) {
        t[0] = (char)po_fold((unsigned char)p[i]);
        t[1] = (char)po_fold((unsigned char)p[i + 1]);
        t[2] = (char)po_fold((unsigned char)p[i + 2]);
        cb(ud, t);
    }
}

static void po_bloom_add_cb(void *ud, const char *tri) {
    po_bloom_set((po_bloom *)ud, tri, 3);
}

static void po_bloom_add_text(po_bloom *b, const char *p, size_t len) {
    po_trigrams(p, len, po_bloom_add_cb, b);
}

/* Count distinct trigrams, so a block can be sized from what it actually
 * holds rather than from a guess. Uses a small open set; blocks are ~1MB so
 * the distinct count is bounded well under 2^24. */
typedef struct { unsigned char seen[1 << 21]; uint32_t n; } po_tri_count;

static void po_tri_count_cb(void *ud, const char *tri) {
    po_tri_count *c = (po_tri_count *)ud;
    uint32_t h = po_hash32(tri, 3) & ((1u << 24) - 1);
    uint32_t byte = h >> 3;
    unsigned char m = (unsigned char)(1 << (h & 7));
    if (!(c->seen[byte] & m)) { c->seen[byte] |= m; c->n++; }
}

/* CAN THIS QUERY USE THE FILTER AT ALL?
 *
 * A query shorter than three bytes has NO trigrams, so testing it would test
 * nothing and "no trigram matched" would wrongly prune every block. A search
 * for "ok" must fall through to scanning the candidates, not silently return
 * empty. This is the bug that would make short searches quietly wrong, so it
 * is a named predicate rather than an implicit length check somewhere. */
static int po_bloom_query_usable(size_t qlen) { return qlen >= 3; }

/* Test every trigram of the query. ANY absent trigram means the block cannot
 * contain the query. */
typedef struct { const unsigned char *bits; uint32_t mask; int possible; }
        po_bloom_probe;

static void po_bloom_probe_cb(void *ud, const char *tri) {
    po_bloom_probe *p = (po_bloom_probe *)ud;
    if (!p->possible) return;
    if (!po_bloom_test_raw(p->bits, p->mask, tri, 3)) p->possible = 0;
}

static int po_bloom_may_contain(const unsigned char *bits, uint32_t mask,
                                const char *q, size_t qlen) {
    po_bloom_probe p;
    if (!po_bloom_query_usable(qlen)) return 1;   /* cannot prune: assume yes */
    p.bits = bits; p.mask = mask; p.possible = 1;
    po_trigrams(q, qlen, po_bloom_probe_cb, &p);
    return p.possible;
}

/* The exact match that runs AFTER the filter says "possible". Case-folded to
 * agree with the filter, and a plain byte search: the filter prunes, this
 * decides. */
static const char *po_memfind(const char *hay, size_t hn,
                              const char *needle, size_t nn) {
    size_t i, j;
    if (nn == 0 || nn > hn) return NULL;
    for (i = 0; i + nn <= hn; i++) {
        for (j = 0; j < nn; j++)
            if (po_fold((unsigned char)hay[i + j]) !=
                po_fold((unsigned char)needle[j])) break;
        if (j == nn) return hay + i;
    }
    return NULL;
}

#endif /* PO_BLOOM_H */
