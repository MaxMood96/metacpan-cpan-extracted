#ifndef PTOTP_OTP_H
#define PTOTP_OTP_H

#include <stddef.h>
#include <string.h>

#include "frh_abi.h"

/* ptotp_otp.h - HOTP (RFC 4226) and TOTP (RFC 6238) over the HMAC a
 * frh_abi table provides. Pure C, no perl types: the table pointer
 * comes in as an argument, resolved once by the XS at boot.
 *
 * The counter is uint64-shaped end to end and never passes through an
 * IV or a %d on its way anywhere: the 32-bit IV smokers truncate
 * 64-bit casts, and a truncated counter is a code that verifies on
 * the developer's machine and nowhere else.
 */

typedef unsigned long long ptotp_u64;

#define PTOTP_MAX_DIGEST 64

/* HOTP: counter as eight big-endian bytes, HMAC, dynamic truncation,
 * modulo 10^digits. Returns the code, or (unsigned long)-1 on an HMAC
 * failure or digits outside 6..8. */
static unsigned long ptotp_hotp(const frh_abi *H, int alg_id,
                                const unsigned char *secret, size_t slen,
                                ptotp_u64 counter, int digits)
{
    unsigned char msg[8], mac[PTOTP_MAX_DIGEST];
    const frh_algo_t *a;
    unsigned long code, mod;
    size_t off;
    int i;

    if (!H || digits < 6 || digits > 8)
        return (unsigned long)-1;
    a = H->algo_by_id(alg_id);
    if (!a || !a->hmac_able || a->digest_size < 20 ||
        a->digest_size > PTOTP_MAX_DIGEST)
        return (unsigned long)-1;

    for (i = 7; i >= 0; i--) {
        msg[i] = (unsigned char)(counter & 0xff);
        counter >>= 8;
    }
    if (H->hmac(alg_id, secret, slen, msg, 8, mac) != 0)
        return (unsigned long)-1;

    /* dynamic truncation: the low nibble of the last byte indexes four
     * bytes; mask the top bit */
    off = mac[a->digest_size - 1] & 0x0f;
    code = ((unsigned long)(mac[off]     & 0x7f) << 24)
         | ((unsigned long) mac[off + 1]         << 16)
         | ((unsigned long) mac[off + 2]         << 8)
         |  (unsigned long) mac[off + 3];

    mod = 1;
    for (i = 0; i < digits; i++)
        mod *= 10;
    return code % mod;
}

/* TOTP at a moment: HOTP at time/period. */
static unsigned long ptotp_totp_at(const frh_abi *H, int alg_id,
                                   const unsigned char *secret, size_t slen,
                                   ptotp_u64 unixtime, unsigned period,
                                   int digits)
{
    if (!period)
        return (unsigned long)-1;
    return ptotp_hotp(H, alg_id, secret, slen, unixtime / period, digits);
}

/* Constant-time comparison of two digit strings of equal length. */
static int ptotp_ct_eq(const char *a, const char *b, size_t n)
{
    unsigned char acc = 0;
    size_t i;

    for (i = 0; i < n; i++)
        acc |= (unsigned char)(a[i] ^ b[i]);
    return acc == 0;
}

/* Render a code as exactly `digits` ASCII digits. */
static void ptotp_render(unsigned long code, int digits, char *out)
{
    int i;

    for (i = digits - 1; i >= 0; i--) {
        out[i] = (char)('0' + code % 10);
        code /= 10;
    }
    out[digits] = '\0';
}

/* Verify a submitted code against the window around `now`.
 *
 * Checks counters now/period - skew .. + skew. Two properties most
 * implementations skip, both deliberate:
 *
 *  - The window loop NEVER breaks early on a match, and each
 *    comparison is constant-time, so the time taken does not report
 *    which counter hit or whether one did.
 *
 *  - `last_counter` makes the verifier replay-safe by construction:
 *    any code whose counter does not exceed it is refused even when
 *    it would otherwise verify, and on success *matched receives the
 *    counter for the caller to store. A verifier returning a bare
 *    boolean cannot be made replay-safe from outside. Pass
 *    (ptotp_u64)-1 as last_counter for "no floor" - 0 would wrongly
 *    refuse the counter-zero code, which RFC 4226's own test vectors
 *    exercise.
 *
 * The submitted code is refused before any HMAC runs when its length
 * is not `digits` or it contains a non-digit.
 *
 * Returns 1 on acceptance, 0 otherwise. */
static int ptotp_verify(const frh_abi *H, int alg_id,
                        const unsigned char *secret, size_t slen,
                        ptotp_u64 now, unsigned period, int digits,
                        const char *code, size_t clen,
                        unsigned skew, ptotp_u64 last_counter,
                        ptotp_u64 *matched)
{
    ptotp_u64 centre, c, lo, hi;
    int ok = 0;
    size_t i;

    if (!H || !period || digits < 6 || digits > 8 || clen != (size_t)digits)
        return 0;
    for (i = 0; i < clen; i++)
        if (code[i] < '0' || code[i] > '9')
            return 0;

    centre = now / period;
    lo = centre > skew ? centre - skew : 0;
    hi = centre + skew;

    for (c = lo; c <= hi; c++) {
        unsigned long want = ptotp_hotp(H, alg_id, secret, slen, c, digits);
        char buf[9];

        if (want == (unsigned long)-1)
            continue;
        ptotp_render(want, digits, buf);
        if (ptotp_ct_eq(code, buf, clen)
            && (last_counter == (ptotp_u64)-1 || c > last_counter)
            && !ok) {
            ok = 1;
            if (matched)
                *matched = c;
        }
        /* no break: every counter in the window is always checked */
    }
    return ok;
}

#endif /* PTOTP_OTP_H */
