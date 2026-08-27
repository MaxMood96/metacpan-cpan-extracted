/* po_nsarith.h - nanosecond arithmetic, done as integers.
 *
 * A NANOSECOND INSTANT DOES NOT FIT A DOUBLE, AND ON HALF THE SMOKERS IT DOES
 * NOT FIT AN IV EITHER.
 *
 * 2026 is about 1.79e18 nanoseconds past the epoch. A double carries 53 bits
 * of mantissa, so it starts losing the low digits somewhere around 9.0e15 -
 * which is to say it has been wrong since 1970 plus a few months. The Perl
 * this replaces handled that by doing DECIMAL STRING arithmetic: splitting
 * both operands into digits, adding with a carry, joining back. Correct, and
 * roughly two hundred times the cost of the thing it is emulating.
 *
 * It is emulating a uint64. This distribution has had one since phase 0.
 *
 * So the arithmetic is done in po_u64 and the strings exist only at the Perl
 * boundary, where po_sv_to_u64 and po_u64_to_sv already handle the crossing:
 * a UV where that is lossless, a decimal string where it is not.
 *
 * WHAT IS NOT ASSUMED: that every value fits. A caller can hand in something
 * that is not a bare non-negative integer - an empty string, a float, a
 * timestamp from a future format - and the answer has to be defined for those
 * rather than merely fast for the rest. Anything that does not parse falls
 * back to a comparison the caller can still reason about, and the fallback is
 * reported rather than silent.
 */
#ifndef PO_NSARITH_H
#define PO_NSARITH_H

#include "punk_observe/po_compat.h"

/* Compare two instants.
 *
 * `ok` is set when both parsed as integers. When either did not, the result
 * is a plain byte comparison of what was there - which is at least a total
 * order, so a sort using it still terminates and still produces a stable
 * answer instead of undefined behaviour. */
static int po_ns_cmp_str(const char *a, size_t alen,
                         const char *b, size_t blen, int *ok) {
    size_t ai = 0, bi = 0;
    size_t an, bn;

    if (ok) *ok = 0;

    /* Leading zeroes are not significant, and a value written with them is
     * the same instant. Skipping them here means "007" and "7" compare equal
     * rather than sorting by width. */
    while (ai < alen && a[ai] == '0') ai++;
    while (bi < blen && b[bi] == '0') bi++;
    an = alen - ai;
    bn = blen - bi;

    {   /* Both must be all digits for the numeric answer to mean anything. */
        size_t i;
        for (i = ai; i < alen; i++) if (a[i] < '0' || a[i] > '9') goto bytes;
        for (i = bi; i < blen; i++) if (b[i] < '0' || b[i] > '9') goto bytes;
    }

    if (ok) *ok = 1;
    /* MORE DIGITS IS LARGER, once the leading zeroes are gone. That single
     * rule is what makes this exact for values of any width, including ones
     * past a uint64 - which a parse-then-compare would silently clamp. */
    if (an != bn) return an < bn ? -1 : 1;
    if (an == 0) return 0;
    {
        int c = memcmp(a + ai, b + bi, an);
        return c < 0 ? -1 : (c > 0 ? 1 : 0);
    }

bytes:
    {
        size_t n = alen < blen ? alen : blen;
        int c = n ? memcmp(a, b, n) : 0;
        if (c) return c < 0 ? -1 : 1;
        return alen == blen ? 0 : (alen < blen ? -1 : 1);
    }
}

/* Add, saturating. Overflow is clamped rather than wrapped: a retention
 * horizon that wrapped to zero would delete everything, and one that clamps
 * to the top of the range keeps everything, which is the failure worth
 * having. */
static po_u64 po_ns_add(po_u64 a, po_u64 b) {
    return a > PO_U64_MAX - b ? PO_U64_MAX : a + b;
}

/* Subtract, clamped at zero. An instant before the epoch is not a thing, and
 * in a uint64 the difference is not a small negative number - it is 1.8e19,
 * which as a time bound admits everything. */
static po_u64 po_ns_sub(po_u64 a, po_u64 b) {
    return a < b ? 0 : a - b;
}

#endif /* PO_NSARITH_H */
