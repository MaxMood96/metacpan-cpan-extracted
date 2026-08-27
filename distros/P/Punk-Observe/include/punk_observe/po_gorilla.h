/* po_gorilla.h - delta-of-delta timestamps, XOR values.
 *
 * A naive point is 16 bytes: 8 of timestamp, 8 of double. A series scraped
 * every 15 seconds for a day is 5,760 points, 92KB, times however many series
 * a fleet has. The published Gorilla result is about 1.37 bytes per point,
 * and the two halves are independent and both simple.
 *
 * TIMESTAMPS: DELTA OF DELTA. Points arrive on an interval, so the delta is
 * nearly constant and the delta of the delta is nearly always zero.
 *
 * ONE DEPARTURE FROM THE PAPER, AND IT IS FORCED. Gorilla stores the second
 * timestamp as a 14-bit delta, because its timestamps are SECONDS. OTLP
 * timestamps are NANOSECONDS: a 15-second scrape interval is 1.5e10 ns, which
 * does not fit 14 bits, or 32. So the first delta is written as a full 64
 * bits. It costs eight bytes ONCE per chunk - amortised over 120 points that
 * is under a bit each - and taking the published constant unexamined would
 * have produced a decoder that silently truncates every interval.
 *
 * VALUES: XOR AGAINST THE PREVIOUS. A gauge that barely moves and a counter
 * that increments both XOR to a value with long runs of leading and trailing
 * zeros.
 */
#ifndef PO_GORILLA_H
#define PO_GORILLA_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_bits.h"

typedef struct {
    po_bw  bw;
    po_u64 t_prev;
    po_i64 d_prev;         /* the previous delta, signed: points can arrive
                            * out of order and a delta can be negative */
    po_u64 v_prev;         /* the previous value's BIT PATTERN */
    int    lead_prev;
    int    len_prev;
    uint32_t n;
} po_gor_w;

static int po_gor_w_init(po_gor_w *g) {
    memset(g, 0, sizeof(*g));
    g->lead_prev = -1;
    return po_bw_init(&g->bw, 256);
}

static void po_gor_w_free(po_gor_w *g) { po_bw_free(&g->bw); }

/* Append one point. `bits` is the value's BIT PATTERN, not its numeric value.
 *
 * Passing the bit pattern rather than a double is deliberate: it makes NaN
 * payloads, the infinities and negative zero survive exactly, and it means
 * an integer point (OTLP's as_int) uses the identical path without a lossy
 * trip through a double. */
static void po_gor_put(po_gor_w *g, po_u64 t, po_u64 bits) {
    if (g->n == 0) {
        po_bw_put(&g->bw, t, 64);          /* the anchor timestamp */
        po_bw_put(&g->bw, bits, 64);       /* and the anchor value */
        g->t_prev = t;
        g->v_prev = bits;
        g->d_prev = 0;
        g->n = 1;
        return;
    }

    if (g->n == 1) {
        /* The first delta, in full. See the header note: nanoseconds do not
         * fit the paper's 14 bits. */
        po_i64 d = (po_i64)(t - g->t_prev);
        po_bw_put(&g->bw, (po_u64)d, 64);
        g->d_prev = d;
        g->t_prev = t;
    }
    else {
        po_i64 d   = (po_i64)(t - g->t_prev);
        po_i64 dod = d - g->d_prev;

        /* THE RANGES ARE TWO'S-COMPLEMENT RANGES, NOT THE PAPER'S.
         *
         * Gorilla is usually written as [-63, 64] in 7 bits, [-255, 256] in
         * 9, and so on. Those are 128 and 512 distinct values, so they fit -
         * but only with an offset. Stored DIRECTLY as two's complement, 7
         * bits holds -64..63, and a dod of 64 written that way reads back as
         * -64. The point lands in the wrong place and nothing reports it.
         *
         * Taking the published constants unexamined put exactly that bug in
         * here, and the bucket-boundary test caught it. */
        if (dod == 0) po_bw_put1(&g->bw, 0);
        else if (dod >= -64 && dod <= 63) {
            po_bw_put(&g->bw, 0x2, 2);                 /* 10  */
            po_bw_put(&g->bw, (po_u64)dod & 0x7F, 7);
        }
        else if (dod >= -256 && dod <= 255) {
            po_bw_put(&g->bw, 0x6, 3);                 /* 110 */
            po_bw_put(&g->bw, (po_u64)dod & 0x1FF, 9);
        }
        else if (dod >= -2048 && dod <= 2047) {
            po_bw_put(&g->bw, 0xE, 4);                 /* 1110 */
            po_bw_put(&g->bw, (po_u64)dod & 0xFFF, 12);
        }
        else if (dod >= -((po_i64)1 << 31) && dod < ((po_i64)1 << 31)) {
            po_bw_put(&g->bw, 0x1E, 5);                /* 11110 */
            po_bw_put(&g->bw, (po_u64)dod & 0xFFFFFFFFu, 32);
        }
        else {
            /* The 64-bit escape. Gorilla has no such case because its
             * timestamps are seconds; nanoseconds reach it whenever a series
             * genuinely jumps, and without it those points would be lost. */
            po_bw_put(&g->bw, 0x1F, 5);                /* 11111 */
            po_bw_put(&g->bw, (po_u64)dod, 64);
        }
        g->d_prev = d;
        g->t_prev = t;
    }

    {   /* the value */
        po_u64 x = g->v_prev ^ bits;
        if (x == 0) po_bw_put1(&g->bw, 0);
        else {
            int lead = 0, trail = 0, i;
            for (i = 63; i >= 0 && !((x >> i) & 1); i--) lead++;
            for (i = 0;  i < 64 && !((x >> i) & 1);  i++) trail++;
            if (lead > 31) lead = 31;      /* the field is 5 bits */

            po_bw_put1(&g->bw, 1);
            /* REUSE REQUIRES THE MEANINGFUL BITS TO FIT THE PREVIOUS WINDOW
             * IN POSITION, NOT MERELY IN WIDTH.
             *
             * The previous window covers bits [lead_prev, lead_prev+len_prev),
             * so reuse is only valid when this xor's meaningful range sits
             * inside it: lead >= lead_prev AND trail >= trail_prev.
             *
             * The first version checked `(64 - lead - trail) <= len_prev` -
             * the WIDTH fits - which is not the same thing. An xor whose bits
             * start inside the window but extend past its bottom had the
             * overhang silently shifted away, and the decoder reconstructed a
             * different number. No crash, no error: a wrong value on a chart.
             *
             * It survived 100,000 random doubles because random values never
             * take this branch - consecutive random mantissas share nothing,
             * so every point stores a new window. A smoothly increasing
             * series takes it on almost every point, which is what most real
             * metrics are. */
            if (g->lead_prev >= 0 && g->len_prev > 0
                && lead >= g->lead_prev
                && trail >= 64 - g->lead_prev - g->len_prev) {
                po_bw_put1(&g->bw, 0);
                po_bw_put(&g->bw, x >> (64 - g->lead_prev - g->len_prev),
                          g->len_prev);
            }
            else {
                int len = 64 - lead - trail;
                if (len < 1) len = 1;
                if (len > 64) len = 64;
                po_bw_put1(&g->bw, 1);
                po_bw_put(&g->bw, (po_u64)lead, 5);
                /* 64 is written as 0 in six bits: a length of 0 is
                 * meaningless (that is the xor==0 case), so the encoding is
                 * unambiguous and 64-bit differences stay representable. */
                po_bw_put(&g->bw, (po_u64)(len & 0x3F), 6);
                po_bw_put(&g->bw, x >> trail, len);
                g->lead_prev = lead;
                g->len_prev  = len;
            }
        }
        g->v_prev = bits;
    }
    g->n++;
}

/* ---- reading ------------------------------------------------------------- */

typedef struct {
    po_br  br;
    po_u64 t_prev;
    po_i64 d_prev;
    po_u64 v_prev;
    int    lead_prev;
    int    len_prev;
    uint32_t i, n;
} po_gor_r;

static void po_gor_r_init(po_gor_r *g, const void *buf, size_t nbits,
                          uint32_t count) {
    memset(g, 0, sizeof(*g));
    po_br_init(&g->br, buf, nbits);
    g->lead_prev = -1;
    g->n = count;
}

/* Returns 1 and fills *t and *bits, or 0 at the end / on a malformed stream. */
static int po_gor_next(po_gor_r *g, po_u64 *t, po_u64 *bits) {
    if (g->br.err || g->i >= g->n) return 0;

    if (g->i == 0) {
        g->t_prev = po_br_get(&g->br, 64);
        g->v_prev = po_br_get(&g->br, 64);
        g->d_prev = 0;
    }
    else if (g->i == 1) {
        po_i64 d = (po_i64)po_br_get(&g->br, 64);
        g->d_prev = d;
        g->t_prev = (po_u64)((po_i64)g->t_prev + d);
        goto value;
    }
    else {
        po_i64 dod = 0;
        if (po_br_get1(&g->br) == 0) dod = 0;
        else if (po_br_get1(&g->br) == 0) dod = po_sext(po_br_get(&g->br, 7), 7);
        else if (po_br_get1(&g->br) == 0) dod = po_sext(po_br_get(&g->br, 9), 9);
        else if (po_br_get1(&g->br) == 0) dod = po_sext(po_br_get(&g->br, 12), 12);
        else if (po_br_get1(&g->br) == 0) dod = po_sext(po_br_get(&g->br, 32), 32);
        else dod = (po_i64)po_br_get(&g->br, 64);

        g->d_prev = g->d_prev + dod;
        g->t_prev = (po_u64)((po_i64)g->t_prev + g->d_prev);
        goto value;
    }

    if (g->br.err) return 0;
    *t = g->t_prev; *bits = g->v_prev;
    g->i++;
    return 1;

value:
    {
        if (po_br_get1(&g->br) == 0) {
            /* unchanged */
        }
        else if (po_br_get1(&g->br) == 0) {
            po_u64 m;
            if (g->len_prev <= 0) { g->br.err = 1; return 0; }
            m = po_br_get(&g->br, g->len_prev);
            g->v_prev ^= m << (64 - g->lead_prev - g->len_prev);
        }
        else {
            int lead = (int)po_br_get(&g->br, 5);
            int len  = (int)po_br_get(&g->br, 6);
            po_u64 m;
            if (len == 0) len = 64;           /* the 64 encoding, see above */
            if (lead + len > 64) { g->br.err = 1; return 0; }
            m = po_br_get(&g->br, len);
            g->v_prev ^= m << (64 - lead - len);
            g->lead_prev = lead;
            g->len_prev  = len;
        }
    }
    if (g->br.err) return 0;
    *t = g->t_prev; *bits = g->v_prev;
    g->i++;
    return 1;
}

/* Bit patterns in and out, so a caller that has a double converts explicitly
 * and a caller that has an integer does not convert at all. */
static po_u64 po_d2b(double d) { po_u64 b; memcpy(&b, &d, 8); return b; }
static double po_b2d(po_u64 b) { double d; memcpy(&d, &b, 8); return d; }

#endif /* PO_GORILLA_H */
