/* po_bits.h - a bit writer and a bit reader.
 *
 * Everything in phase 5 sits on these two, so they are deliberately small and
 * exhaustively tested. A bug here is not a crash, it is a chart with a spike
 * in the wrong place.
 *
 * Bits are written most-significant-first within each byte, which is the
 * convention the Gorilla paper's control codes assume ('10', '110', '1110')
 * and the one that makes a hex dump readable when something is wrong.
 */
#ifndef PO_BITS_H
#define PO_BITS_H

#include "punk_observe/po_compat.h"

typedef struct {
    unsigned char *buf;
    size_t         cap;      /* bytes */
    size_t         nbits;
    int            err;      /* set on allocation failure; sticky */
} po_bw;

static int po_bw_init(po_bw *w, size_t hint) {
    memset(w, 0, sizeof(*w));
    w->cap = hint ? hint : 64;
    w->buf = (unsigned char *)calloc(w->cap, 1);
    return w->buf != NULL;
}

static void po_bw_free(po_bw *w) { free(w->buf); w->buf = NULL; w->cap = 0; }

static int po_bw_room(po_bw *w, size_t more_bits) {
    size_t need = (w->nbits + more_bits + 7) / 8;
    if (need <= w->cap) return 1;
    {
        size_t want = w->cap * 2;
        unsigned char *nb;
        while (want < need) want *= 2;
        nb = (unsigned char *)realloc(w->buf, want);
        if (!nb) { w->err = 1; return 0; }
        memset(nb + w->cap, 0, want - w->cap);   /* new bytes must be zero */
        w->buf = nb;
        w->cap = want;
    }
    return 1;
}

/* Write the low `n` bits of `v`, most significant of those first. */
static void po_bw_put(po_bw *w, po_u64 v, int n) {
    int i;
    if (w->err || n <= 0) return;
    if (!po_bw_room(w, (size_t)n)) return;
    for (i = n - 1; i >= 0; i--) {
        size_t bit  = w->nbits;
        size_t byte = bit >> 3;
        int    off  = 7 - (int)(bit & 7);
        if ((v >> i) & 1) w->buf[byte] |= (unsigned char)(1 << off);
        w->nbits++;
    }
}

static void po_bw_put1(po_bw *w, int b) { po_bw_put(w, b ? 1 : 0, 1); }

static size_t po_bw_bytes(const po_bw *w) { return (w->nbits + 7) / 8; }

typedef struct {
    const unsigned char *buf;
    size_t               nbits;   /* total available */
    size_t               pos;
    int                  err;     /* set on a read past the end */
} po_br;

static void po_br_init(po_br *r, const void *buf, size_t nbits) {
    r->buf = (const unsigned char *)buf;
    r->nbits = nbits;
    r->pos = 0;
    r->err = 0;
}

/* Read `n` bits. On a read past the end this sets err and returns 0 rather
 * than reading whatever follows the buffer - a truncated chunk must fail, not
 * decode to plausible garbage. */
static po_u64 po_br_get(po_br *r, int n) {
    po_u64 v = 0;
    int i;
    if (r->err || n <= 0) return 0;
    if (r->pos + (size_t)n > r->nbits) { r->err = 1; return 0; }
    for (i = 0; i < n; i++) {
        size_t bit  = r->pos;
        size_t byte = bit >> 3;
        int    off  = 7 - (int)(bit & 7);
        v = (v << 1) | (po_u64)((r->buf[byte] >> off) & 1);
        r->pos++;
    }
    return v;
}

static int po_br_get1(po_br *r) { return (int)po_br_get(r, 1); }

/* Sign-extend an n-bit two's-complement value.
 *
 * This is where bit-stream code goes wrong, and the symptom is not a crash:
 * a 12-bit delta-of-delta of -2047 read back as 2049 puts a point in the
 * wrong place on a chart and nothing anywhere reports a problem. */
static po_i64 po_sext(po_u64 v, int n) {
    po_u64 m = (po_u64)1 << (n - 1);
    if (v & m) return (po_i64)(v | ~(((po_u64)1 << n) - 1));
    return (po_i64)v;
}

#endif /* PO_BITS_H */
