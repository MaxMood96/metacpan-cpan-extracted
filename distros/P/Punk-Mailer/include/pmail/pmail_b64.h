#ifndef PMAIL_B64_H
#define PMAIL_B64_H

/* pmail_b64.h - base64 as MIME wants it.
 *
 * A streaming encoder with a three-byte carry, so an attachment can be
 * fed in whatever chunks the reader produces and the output is identical
 * to encoding it at once; 76-column lines ended by CRLF (RFC 2045 6.8)
 * when wrapping is on; and a plain, unwrapped form for RFC 2047 words and
 * SMTP AUTH. One alphabet table for all three.
 *
 * Written here rather than taken from File::Raw::Base64 because that API
 * encodes a whole buffer into a reallocated one - no carry, no stream -
 * and the attachment path must never hold a whole file. */

static const char PMAIL_B64_ALPHABET[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

#define PMAIL_B64_LINE 76

typedef struct {
    unsigned char carry[3];
    int ncarry;
    int col;        /* characters on the current output line */
    int wrap;       /* 1: 76-column CRLF lines; 0: one run */
} pmail_b64_st;

static void pmail_b64_init(pmail_b64_st *st, int wrap)
{
    st->ncarry = 0;
    st->col = 0;
    st->wrap = wrap;
}

static void pmail_b64_group(const unsigned char *in, int n, char out[4])
{
    unsigned int v = (unsigned int)in[0] << 16;
    if (n > 1) v |= (unsigned int)in[1] << 8;
    if (n > 2) v |= (unsigned int)in[2];
    out[0] = PMAIL_B64_ALPHABET[(v >> 18) & 63];
    out[1] = PMAIL_B64_ALPHABET[(v >> 12) & 63];
    out[2] = n > 1 ? PMAIL_B64_ALPHABET[(v >> 6) & 63] : '=';
    out[3] = n > 2 ? PMAIL_B64_ALPHABET[v & 63] : '=';
}

/* Output is staged in a local buffer and flushed to the sink in runs, so a
 * file read in 58368-byte chunks produces a few writes per chunk rather
 * than one per group. */
#define PMAIL_B64_BUF 4096

static int pmail_b64_emit(pmail_b64_st *st, char *buf, size_t *used,
                          const char group[4], pmail_sink *s)
{
    memcpy(buf + *used, group, 4);
    *used += 4;
    if (st->wrap) {
        st->col += 4;
        if (st->col >= PMAIL_B64_LINE) {
            buf[(*used)++] = '\r';
            buf[(*used)++] = '\n';
            st->col = 0;
        }
    }
    if (*used > PMAIL_B64_BUF - 8) {
        if (pmail_put(s, buf, *used) != 0) return -1;
        *used = 0;
    }
    return 0;
}

static int pmail_b64_update(pmail_b64_st *st, const unsigned char *in, size_t n,
                            pmail_sink *s)
{
    char buf[PMAIL_B64_BUF];
    size_t used = 0;
    char group[4];

    /* complete a carried group first */
    while (st->ncarry && st->ncarry < 3 && n) {
        st->carry[st->ncarry++] = *in++;
        n--;
    }
    if (st->ncarry == 3) {
        pmail_b64_group(st->carry, 3, group);
        if (pmail_b64_emit(st, buf, &used, group, s) != 0) return -1;
        st->ncarry = 0;
    }
    while (n >= 3) {
        pmail_b64_group(in, 3, group);
        if (pmail_b64_emit(st, buf, &used, group, s) != 0) return -1;
        in += 3; n -= 3;
    }
    while (n) { st->carry[st->ncarry++] = *in++; n--; }
    return used ? pmail_put(s, buf, used) : 0;
}

static int pmail_b64_final(pmail_b64_st *st, pmail_sink *s)
{
    char group[4];
    if (st->ncarry) {
        pmail_b64_group(st->carry, st->ncarry, group);
        if (pmail_put(s, group, 4) != 0) return -1;
        st->ncarry = 0;
        st->col += 4;
    }
    if (st->wrap && st->col > 0) {
        if (PMAIL_PUTS(s, PMAIL_CRLF) != 0) return -1;
        st->col = 0;
    }
    return 0;
}

/* the exact size of `n` bytes encoded with wrapping: what MAIL FROM's
 * SIZE= needs before a single byte of the file has been read */
static pmail_u64 pmail_b64_wrapped_len(pmail_u64 n)
{
    pmail_u64 enc = 4 * ((n + 2) / 3);
    pmail_u64 lines = (enc + PMAIL_B64_LINE - 1) / PMAIL_B64_LINE;
    return enc + 2 * lines;
}

/* one unwrapped run into a new SV (RFC 2047 words, SMTP AUTH PLAIN) */
static SV *pmail_b64_plain_sv(pTHX_ const unsigned char *in, size_t n)
{
    SV *out = newSV(4 * ((n + 2) / 3) + 1);
    char *p;
    SvPOK_on(out);
    p = SvPVX(out);
    while (n >= 3) { pmail_b64_group(in, 3, p); in += 3; n -= 3; p += 4; }
    if (n) { pmail_b64_group(in, (int)n, p); p += 4; }
    *p = 0;
    SvCUR_set(out, p - SvPVX(out));
    return out;
}

#endif /* PMAIL_B64_H */
