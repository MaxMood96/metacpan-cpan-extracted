#ifndef PTOTP_B32_H
#define PTOTP_B32_H

#include <stddef.h>

/* ptotp_b32.h - RFC 4648 base32, written for what it decodes: a
 * shared secret typed in by hand when a QR cannot be scanned.
 *
 * The requirements that rule out every implementation on the shelf:
 * arbitrary length (secrets are 20, 32 or 64 bytes by algorithm);
 * padding emitted and both padded and bare input accepted; case
 * folded, spaces and hyphens skipped, because authenticator apps
 * display secrets in grouped-four chunks and people type what they
 * see; and REJECTION of anything else - a decoder that maps a typo to
 * some byte produces a different secret that verifies nothing and
 * reports nothing, which is the worst failure this file could have.
 */

static const char ptotp_b32_alpha[32] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

/* Encoded length including padding, excluding the NUL. */
static size_t ptotp_b32_elen(size_t n)
{
    return ((n + 4) / 5) * 8;
}

/* Encode n bytes into dst (at least ptotp_b32_elen(n) + 1). */
static void ptotp_b32_encode(char *dst, const unsigned char *src, size_t n)
{
    size_t i;

    for (i = 0; i < n; i += 5) {
        unsigned char b[5] = { 0, 0, 0, 0, 0 };
        size_t have = n - i < 5 ? n - i : 5, j;
        /* how many output symbols carry data for 1..5 input bytes */
        static const int syms[6] = { 0, 2, 4, 5, 7, 8 };

        for (j = 0; j < have; j++)
            b[j] = src[i + j];

        {
            char out[8];
            out[0] = ptotp_b32_alpha[b[0] >> 3];
            out[1] = ptotp_b32_alpha[((b[0] & 0x07) << 2) | (b[1] >> 6)];
            out[2] = ptotp_b32_alpha[(b[1] >> 1) & 0x1f];
            out[3] = ptotp_b32_alpha[((b[1] & 0x01) << 4) | (b[2] >> 4)];
            out[4] = ptotp_b32_alpha[((b[2] & 0x0f) << 1) | (b[3] >> 7)];
            out[5] = ptotp_b32_alpha[(b[3] >> 2) & 0x1f];
            out[6] = ptotp_b32_alpha[((b[3] & 0x03) << 3) | (b[4] >> 5)];
            out[7] = ptotp_b32_alpha[b[4] & 0x1f];
            for (j = 0; j < 8; j++)
                *dst++ = j < (size_t)syms[have] ? out[j] : '=';
        }
    }
    *dst = '\0';
}

/* Decode into dst (at least (len * 5) / 8 bytes). Returns the decoded
 * length, or -1 on any byte outside the alphabet after the skip set
 * (space, tab, hyphen), on padding that is not terminal, or on a
 * symbol count no encoding produces. Case-insensitive.
 *
 * Rejection is the point: -1 and nothing else for '0', '1', '8', '9',
 * '=' in the middle, and anything punctuation-shaped besides the
 * grouping characters people actually type. */
static long ptotp_b32_decode(unsigned char *dst, const char *src, size_t len)
{
    unsigned long acc = 0;
    int bits = 0, done = 0;
    size_t i, out = 0, symbols = 0;

    for (i = 0; i < len; i++) {
        unsigned char c = (unsigned char)src[i];
        int v;

        if (c == ' ' || c == '\t' || c == '-')
            continue;
        if (c == '=') {
            done = 1;    /* padding: only more padding/skips may follow */
            continue;
        }
        if (done)
            return -1;

        if (c >= 'A' && c <= 'Z')      v = c - 'A';
        else if (c >= 'a' && c <= 'z') v = c - 'a';
        else if (c >= '2' && c <= '7') v = c - '2' + 26;
        else return -1;

        acc = (acc << 5) | (unsigned long)v;
        bits += 5;
        symbols++;
        if (bits >= 8) {
            bits -= 8;
            dst[out++] = (unsigned char)((acc >> bits) & 0xff);
        }
    }

    /* A valid encoding has 0,2,4,5,7 symbols mod 8 - never 1,3,6 -
     * and whatever bits remain must be the zero padding the encoder
     * wrote, or the input was truncated mid-byte. */
    switch (symbols % 8) {
    case 0: case 2: case 4: case 5: case 7:
        break;
    default:
        return -1;
    }
    if (bits && (acc & ((1ul << bits) - 1)))
        return -1;

    return (long)out;
}

#endif /* PTOTP_B32_H */
