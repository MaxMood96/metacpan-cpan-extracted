#ifndef PAK_HASH_H
#define PAK_HASH_H

/* CRC32 (IEEE) and base62: the checksum in an API key.
 *
 * Not a security property - anyone can compute it, and the digests that are
 * come from Punk::Auth::Password, which is libcrypto behind an XSUB - but two
 * things that matter anyway:
 *
 *   a truncated or mistyped key is refused before the database is touched,
 *   so a typo costs no query and cannot be timed against a real lookup; and
 *
 *   a secret scanner can recognise the format and tell a leaked key from a
 *   random string, which is how a key gets revoked before it is used.
 *
 * Table-built on first use rather than a 1KB static: it is 256 entries and
 * this runs once per process.
 */

static U32 PAK_CRC_TABLE[256];
static int PAK_CRC_READY = 0;

static void pak_crc32_init(void)
{
    U32 i, j, c;
    for (i = 0; i < 256; i++) {
        c = i;
        for (j = 0; j < 8; j++)
            c = (c & 1) ? (0xEDB88320UL ^ (c >> 1)) : (c >> 1);
        PAK_CRC_TABLE[i] = c;
    }
    PAK_CRC_READY = 1;
}

static U32 pak_crc32(const char *p, STRLEN len)
{
    U32 c = 0xFFFFFFFFUL;
    STRLEN i;
    if (!PAK_CRC_READY) pak_crc32_init();
    for (i = 0; i < len; i++)
        c = PAK_CRC_TABLE[(c ^ (U8)p[i]) & 0xFF] ^ (c >> 8);
    return c ^ 0xFFFFFFFFUL;
}

/* Base62, big-endian, into exactly PAK_CK_LEN characters.
 *
 * 62^6 is about 5.7e10 and 2^32 about 4.3e9, so six characters hold a CRC32
 * with room to spare - which is the arithmetic the original sketch got wrong
 * when it said base32: five bits a character gives 30 bits in six, and a
 * checksum that cannot represent a quarter of its own values is not one. */

#define PAK_CK_LEN 6

static const char PAK_B62[] =
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

static void pak_b62_6(U32 v, char *out)
{
    int i;
    for (i = PAK_CK_LEN - 1; i >= 0; i--) {
        out[i] = PAK_B62[v % 62];
        v /= 62;
    }
}

#endif /* PAK_HASH_H */
