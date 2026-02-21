#define PERL_NO_GET_CONTEXT     /* we want efficiency */

#include "EXTERN.h"
#include "XSUB.h"
#include "perl.h"
#include "ppport.h"
#include <stdint.h>
#include <string.h>

#define SMILE_HDR0 0x3A
#define SMILE_HDR1 0x29
#define SMILE_HDR2 0x0A

/* header byte #3:
 * bits 0: shared names (default true if header missing)
 * bit  1: shared short string values (default false if header missing)
 * bit  2: raw binary (unused here)
 */
#define SMILE_HDR3 (0x01 | 0x02) /* enable shared names + shared string values */

#define MAX_SHARED_NAMES 1024
#define MAX_SHARED_VALUES 1024

typedef struct {
    const unsigned char *p;
    const unsigned char *end;
} smile_reader_t;

typedef struct {
    int shared_names;
    int shared_values;
    int canonical;
    SV *seen_names_map;  /* HV* */
    SV *seen_values_map; /* HV* */
    int seen_name_count;
    int seen_value_count;
} smile_enc_ctx_t;

typedef struct {
    int shared_names;
    int shared_values;
    int use_bigint;
    int json_bool;
    SV *seen_names[MAX_SHARED_NAMES]; /* SV* strings */
    SV *seen_values[MAX_SHARED_VALUES];
    int seen_name_count;
    int seen_value_count;
} smile_dec_ctx_t;

static void smile_croak(pTHX_ const char *msg) { croak("%s", msg); }

static SV *json_true_cache = NULL;
static SV *json_false_cache = NULL;

static void init_json_bool_cache(pTHX) {
    if (json_true_cache && json_false_cache)
        return;
    if (!eval_pv("require JSON::PP; 1", TRUE))
        return;

    dSP;
    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    PUTBACK;
    call_pv("JSON::PP::true", G_SCALAR);
    SPAGAIN;
    json_true_cache = newSVsv(POPs);
    PUTBACK;

    PUSHMARK(SP);
    PUTBACK;
    call_pv("JSON::PP::false", G_SCALAR);
    SPAGAIN;
    json_false_cache = newSVsv(POPs);
    PUTBACK;

    FREETMPS;
    LEAVE;
}

static unsigned char rd_u8(pTHX_ smile_reader_t *r) {
    if (r->p >= r->end)
        smile_croak(aTHX_ "Unexpected EOF");
    return *r->p++;
}
static void rd_bytes(pTHX_ smile_reader_t *r, unsigned char *dst, size_t n) {
    if ((size_t)(r->end - r->p) < n)
        smile_croak(aTHX_ "Unexpected EOF");
    memcpy(dst, r->p, n);
    r->p += n;
}

static uint64_t rd_vint_u(pTHX_ smile_reader_t *r) {
    uint64_t v = 0;
    for (;;) {
        unsigned char b = rd_u8(aTHX_ r);
        if (b & 0x80) {
            v = (v << 6) | (uint64_t)(b & 0x3F);
            return v;
        }
        v = (v << 7) | (uint64_t)(b & 0x7F);
    }
}
static int64_t zigzag_decode_u64(uint64_t u) {
    return (int64_t)((u >> 1) ^ (uint64_t)-(int64_t)(u & 1));
}
static uint64_t zigzag_encode_i64(int64_t v) { return ((uint64_t)v << 1) ^ (uint64_t)(v >> 63); }

static void wr_u8(pTHX_ SV *out, unsigned char b) {
    STRLEN cur = SvCUR(out);
    if (SvLEN(out) <= cur + 1)
        (void)SvGROW(out, cur + 2);
    char *dst = SvPVX(out);
    dst[cur] = (char)b;
    cur++;
    dst[cur] = '\0';
    SvCUR_set(out, cur);
}
static void wr_bytes(pTHX_ SV *out, const unsigned char *p, size_t n) {
    if (n == 0)
        return;
    STRLEN cur = SvCUR(out);
    if (SvLEN(out) <= cur + (STRLEN)n)
        (void)SvGROW(out, cur + (STRLEN)n + 1);
    char *dst = SvPVX(out);
    memcpy(dst + cur, p, n);
    cur += (STRLEN)n;
    dst[cur] = '\0';
    SvCUR_set(out, cur);
}

static void wr_vint_u(pTHX_ SV *out, uint64_t u) {
    unsigned char tmp[16];
    size_t start = sizeof(tmp);

    tmp[--start] = (unsigned char)((u & 0x3F) | 0x80);
    u >>= 6;
    while (u) {
        tmp[--start] = (unsigned char)(u & 0x7F);
        u >>= 7;
    }
    wr_bytes(aTHX_ out, tmp + start, sizeof(tmp) - start);
}
static void wr_vint_i(pTHX_ SV *out, int64_t v) { wr_vint_u(aTHX_ out, zigzag_encode_i64(v)); }

static void wr_safe7_binary(pTHX_ SV *out, const unsigned char *src, size_t raw_len) {
    size_t total_bits = raw_len * 8;
    size_t groups = (total_bits + 6) / 7;
    size_t bitpos = 0;
    for (size_t g = 0; g < groups; g++) {
        size_t remain = total_bits - bitpos;
        int take = (remain >= 7) ? 7 : (int)remain;
        unsigned char out7 = 0;
        for (int j = 0; j < take; j++) {
            size_t absbit = bitpos + (size_t)j;
            size_t by = absbit / 8;
            size_t bi = absbit % 8;
            unsigned char bit = (unsigned char)((src[by] >> (7 - bi)) & 1u);
            out7 |= (unsigned char)(bit << (take == 7 ? (6 - j) : (take - 1 - j)));
        }
        wr_u8(aTHX_ out, out7);
        bitpos += (size_t)take;
    }
}

static SV *rd_safe7_binary(pTHX_ smile_reader_t *r, size_t raw_len) {
    SV *sv = newSVpvn("", 0);
    SvGROW(sv, (STRLEN)raw_len + 1);
    unsigned char *dst = (unsigned char *)SvPVX(sv);
    memset(dst, 0, raw_len + 1);

    size_t total_bits = raw_len * 8;
    size_t groups = (total_bits + 6) / 7;
    size_t bitpos = 0;

    for (size_t g = 0; g < groups; g++) {
        size_t remain = total_bits - bitpos;
        int take = (remain >= 7) ? 7 : (int)remain;
        unsigned char in7 = rd_u8(aTHX_ r) & 0x7F;
        for (int j = 0; j < take; j++) {
            unsigned char bit =
                (unsigned char)((in7 >> (take == 7 ? (6 - j) : (take - 1 - j))) & 1u);
            size_t absbit = bitpos + (size_t)j;
            size_t by = absbit / 8;
            size_t bi = absbit % 8;
            dst[by] |= (unsigned char)(bit << (7 - bi));
        }
        bitpos += (size_t)take;
    }

    SvCUR_set(sv, (STRLEN)raw_len);
    return sv;
}

static int valid_backref_index(int index) {
    (void)index;
    return 1;
}

static int is_ascii_bytes(const unsigned char *p, size_t n) {
    for (size_t i = 0; i < n; i++)
        if (p[i] & 0x80)
            return 0;
    return 1;
}

/* --- float/double --- */
static void wr_ieee_as_7bit_groups(pTHX_ SV *out, const unsigned char *raw, int nbits) {
    int groups = (nbits + 6) / 7;
    int pad = groups * 7 - nbits;
    int take = 7 - pad;

    uint64_t bits = 0;
    for (int i = 0; i < (nbits / 8); i++)
        bits = (bits << 8) | (uint64_t)raw[i];

    int pos = nbits;

    unsigned char g0 = 0;
    if (take > 0) {
        uint64_t mask = (take == 64) ? ~0ULL : ((1ULL << take) - 1ULL);
        g0 = (unsigned char)((bits >> (pos - take)) & mask);
        pos -= take;
    }
    wr_u8(aTHX_ out, (unsigned char)(g0 & 0x7F));

    while (pos > 0) {
        unsigned char g = (unsigned char)((bits >> (pos - 7)) & 0x7FULL);
        pos -= 7;
        wr_u8(aTHX_ out, g);
    }
}
static NV rd_ieee_from_7bit_groups(pTHX_ smile_reader_t *r, int nbits) {
    int groups = (nbits + 6) / 7;
    int pad = groups * 7 - nbits;
    int take0 = 7 - pad;

    unsigned char raw[8];
    memset(raw, 0, sizeof(raw));

    int bitpos = 0;

    unsigned char g0 = rd_u8(aTHX_ r) & 0x7F;
    for (int j = 0; j < take0; j++) {
        unsigned char bit = (unsigned char)((g0 >> (take0 - 1 - j)) & 1u);
        int by = bitpos / 8;
        int bi = bitpos % 8;
        raw[by] |= (unsigned char)(bit << (7 - bi));
        bitpos++;
    }

    for (int i = 1; i < groups; i++) {
        unsigned char g = rd_u8(aTHX_ r) & 0x7F;
        for (int j = 0; j < 7; j++) {
            if (bitpos >= nbits)
                break;
            unsigned char bit = (unsigned char)((g >> (6 - j)) & 1u);
            int by = bitpos / 8;
            int bi = bitpos % 8;
            raw[by] |= (unsigned char)(bit << (7 - bi));
            bitpos++;
        }
    }

    if (nbits == 32) {
        uint32_t u32 = 0;
        for (int i = 0; i < 4; i++)
            u32 = (u32 << 8) | (uint32_t)raw[i];
        float f = 0.0f;
        memcpy(&f, &u32, sizeof(f));
        return (NV)f;
    }

    uint64_t u64 = 0;
    for (int i = 0; i < 8; i++)
        u64 = (u64 << 8) | (uint64_t)raw[i];
    double d = 0.0;
    memcpy(&d, &u64, sizeof(d));
    return (NV)d;
}

/* --- TO_JSON --- */
static SV *maybe_to_json(pTHX_ SV *sv) {
    if (!SvROK(sv))
        return sv;
    SV *rv = SvRV(sv);
    if (!SvOBJECT(rv))
        return sv;

    if (gv_fetchmethod_autoload(SvSTASH(rv), "TO_JSON", 0)) {
        dSP;
        ENTER;
        SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(sv);
        PUTBACK;
        int count = call_method("TO_JSON", G_SCALAR);
        SPAGAIN;
        if (count != 1) {
            PUTBACK;
            FREETMPS;
            LEAVE;
            croak("TO_JSON must return a single value");
        }
        SV *ret = POPs;
        SV *copy = newSVsv(ret);
        PUTBACK;
        FREETMPS;
        LEAVE;
        return copy;
    }
    return sv;
}

/* --- encoding shared maps --- */
static int enc_lookup_shared(pTHX_ HV *map, SV *sv_key, int *out_index) {
    HE *he = hv_fetch_ent(map, sv_key, 0, 0);
    if (!he)
        return 0;
    SV *v = HeVAL(he);
    if (!SvOK(v))
        return 0;
    *out_index = (int)SvIV(v);
    return 1;
}
static void enc_store_shared(pTHX_ HV *map, SV *sv_key, int index) {
    hv_store_ent(map, sv_key, newSViv((IV)index), 0);
}

static int enc_lookup_shared_ascii(pTHX_ HV *map, const unsigned char *key,
                                   STRLEN len, int *out_index) {
    SV **svp = hv_fetch(map, (const char *)key, (I32)len, 0);
    if (!svp || !SvOK(*svp))
        return 0;
    *out_index = (int)SvIV(*svp);
    return 1;
}

static void enc_store_shared_ascii(pTHX_ HV *map, const unsigned char *key,
                                   STRLEN len, int index) {
    (void)hv_store(map, (const char *)key, (I32)len, newSViv((IV)index), 0);
}

/* --- string encoders (value mode) --- */
static void wr_short_or_long_string_value_bytes(pTHX_ SV *out, const unsigned char *s,
                                                STRLEN len, int ascii,
                                                int *out_is_short,
                                                SV **out_short_key) {
    *out_is_short = (len <= 64) ? 1 : 0;
    *out_short_key = NULL;

    if (len == 0) {
        wr_u8(aTHX_ out, 0x20);
        return;
    }

    if (ascii) {
        if (len <= 32) {
            wr_u8(aTHX_ out, (unsigned char)(0x40 + (len - 1)));
            wr_bytes(aTHX_ out, s, (size_t)len);
        } else if (len <= 64) {
            wr_u8(aTHX_ out, (unsigned char)(0x60 + (len - 33)));
            wr_bytes(aTHX_ out, s, (size_t)len);
        } else {
            wr_u8(aTHX_ out, 0xE0);
            wr_bytes(aTHX_ out, s, (size_t)len);
            wr_u8(aTHX_ out, 0xFC);
        }
    } else {
        if (len >= 2 && len <= 33) {
            wr_u8(aTHX_ out, (unsigned char)(0x80 + (len - 2)));
            wr_bytes(aTHX_ out, s, (size_t)len);
        } else if (len >= 34 && len <= 65) {
            wr_u8(aTHX_ out, (unsigned char)(0xA0 + (len - 34)));
            wr_bytes(aTHX_ out, s, (size_t)len);
        } else {
            wr_u8(aTHX_ out, 0xE4);
            wr_bytes(aTHX_ out, s, (size_t)len);
            wr_u8(aTHX_ out, 0xFC);
        }
    }

    if (*out_is_short) {
        /* stable key for hash lookup: byte string of UTF-8 payload */
        *out_short_key = newSVpvn((const char *)s, len);
        if (!ascii)
            SvUTF8_on(*out_short_key);
    }
}

static void wr_short_or_long_string_value(pTHX_ SV *out, SV *sv, int *out_is_short,
                                          SV **out_short_key) {
    STRLEN len = 0;
    SV *tmp = sv_mortalcopy(sv);

    if (SvUTF8(tmp))
        (void)SvPVutf8(tmp, len);
    const unsigned char *s = (const unsigned char *)SvPVbyte(tmp, len);
    int ascii = is_ascii_bytes(s, (size_t)len);

    wr_short_or_long_string_value_bytes(aTHX_ out, s, len, ascii, out_is_short,
                                        out_short_key);
}

/* --- key encoder (key mode) --- */
static void wr_key_name(pTHX_ SV *out, SV *keysv, int *out_is_trackable, SV **out_key_for_map) {
    STRLEN len = 0;
    SV *tmp = sv_mortalcopy(keysv);

    if (SvUTF8(tmp))
        (void)SvPVutf8(tmp, len);
    const unsigned char *s = (const unsigned char *)SvPVbyte(tmp, len);

    *out_is_trackable = 1;
    *out_key_for_map = NULL;

    if (len == 0) {
        wr_u8(aTHX_ out, 0x20);
        goto mkkey;
    }

    int ascii = is_ascii_bytes(s, (size_t)len);
    {
        if (ascii && len <= 64) {
            wr_u8(aTHX_ out, (unsigned char)(0x80 + (len - 1))); /* short ASCII key */
            wr_bytes(aTHX_ out, s, (size_t)len);
            goto mkkey;
        }
        if (!ascii && len >= 2 && len <= 57) {
            wr_u8(aTHX_ out, (unsigned char)(0xC0 + (len - 2))); /* short Unicode key */
            wr_bytes(aTHX_ out, s, (size_t)len);
            goto mkkey;
        }
        /* long */
        wr_u8(aTHX_ out, 0x34);
        wr_bytes(aTHX_ out, s, (size_t)len);
        wr_u8(aTHX_ out, 0xFC);
    }

mkkey:
    *out_key_for_map = newSVpvn((const char *)s, len);
    if (!ascii)
        SvUTF8_on(*out_key_for_map);
}

/* --- forward decls --- */
static void encode_value(pTHX_ SV *out, smile_enc_ctx_t *ctx, SV *sv);
static SV *decode_value(pTHX_ smile_reader_t *r, smile_dec_ctx_t *ctx);

static void encode_string_value(pTHX_ SV *out, smile_enc_ctx_t *ctx, SV *sv) {
    if (ctx->shared_values) {
        int is_short = 0;
        SV *vkey = NULL;
        HV *shared_map = (HV *)SvRV(ctx->seen_values_map);

        STRLEN len = 0;
        SV *tmp = sv_mortalcopy(sv);
        if (SvUTF8(tmp))
            (void)SvPVutf8(tmp, len);
        const unsigned char *s = (const unsigned char *)SvPVbyte(tmp, len);
        is_short = (len <= 64) ? 1 : 0;
        int ascii = is_ascii_bytes(s, (size_t)len);

        if (is_short && ascii) {
            int index = -1;
            if (enc_lookup_shared_ascii(aTHX_ shared_map, s, len, &index) &&
                index >= 0) {
                if (index < 31) {
                    wr_u8(aTHX_ out, (unsigned char)(index + 1));
                    return;
                }
                if (index < 1024) {
                    wr_u8(aTHX_ out, (unsigned char)(0xEC | ((index >> 8) & 0x03)));
                    wr_u8(aTHX_ out, (unsigned char)(index & 0xFF));
                    return;
                }
            }
        } else if (is_short) {
            vkey = newSVpvn((const char *)s, len);
            if (!ascii)
                SvUTF8_on(vkey);

            int index = -1;
            if (enc_lookup_shared(aTHX_ shared_map, vkey, &index) && index >= 0) {
                if (index < 31) {
                    wr_u8(aTHX_ out, (unsigned char)(index + 1));
                    SvREFCNT_dec(vkey);
                    return;
                }
                if (index < 1024) {
                    wr_u8(aTHX_ out, (unsigned char)(0xEC | ((index >> 8) & 0x03)));
                    wr_u8(aTHX_ out, (unsigned char)(index & 0xFF));
                    SvREFCNT_dec(vkey);
                    return;
                }
            }
        }

        int was_short = 0;
        SV *k2 = NULL;
        wr_short_or_long_string_value_bytes(aTHX_ out, s, len, ascii, &was_short, &k2);
        if (was_short) {
            int idx = ctx->seen_value_count;
            if (idx < MAX_SHARED_VALUES) {
                if (valid_backref_index(idx)) {
                    if (ascii)
                        enc_store_shared_ascii(aTHX_ shared_map, s, len, idx);
                    else
                        enc_store_shared(aTHX_ shared_map, k2, idx);
                }
                ctx->seen_value_count = idx + 1;
            } else {
                hv_clear(shared_map);
                ctx->seen_value_count = 0;
                if (valid_backref_index(0)) {
                    if (ascii)
                        enc_store_shared_ascii(aTHX_ shared_map, s, len, 0);
                    else
                        enc_store_shared(aTHX_ shared_map, k2, 0);
                }
                ctx->seen_value_count = 1;
            }
        }

        if (vkey)
            SvREFCNT_dec(vkey);
        if (k2)
            SvREFCNT_dec(k2);
        return;
    }

    {
        int dummy = 0;
        SV *k = NULL;
        wr_short_or_long_string_value(aTHX_ out, sv, &dummy, &k);
        if (k)
            SvREFCNT_dec(k);
    }
}

/* --- number encoder --- */
static void encode_number(pTHX_ SV *out, SV *sv) {
    if (SvUOK(sv) && !SvNOK(sv)) {
        uint64_t uv = (uint64_t)SvUV(sv);
        if (uv <= (uint64_t)INT64_MAX) {
            int64_t v = (int64_t)uv;
            if (v >= -16 && v <= 15) {
                unsigned char zz = (unsigned char)(zigzag_encode_i64(v) & 0x1F);
                wr_u8(aTHX_ out, (unsigned char)(0xC0 | zz));
                return;
            }
            if (v >= INT32_MIN && v <= INT32_MAX) {
                wr_u8(aTHX_ out, 0x24);
                wr_vint_i(aTHX_ out, v);
                return;
            }
            wr_u8(aTHX_ out, 0x25);
            wr_vint_i(aTHX_ out, v);
            return;
        }

        unsigned char be[9];
        size_t n = 8;
        for (int i = 7; i >= 0; i--) {
            be[i] = (unsigned char)(uv & 0xFF);
            uv >>= 8;
        }
        if (be[0] & 0x80) {
            memmove(be + 1, be, 8);
            be[0] = 0x00;
            n = 9;
        }

        wr_u8(aTHX_ out, 0x26);
        wr_vint_u(aTHX_ out, (uint64_t)n);
        wr_safe7_binary(aTHX_ out, be, n);
        return;
    }

    if (SvIOK(sv) && !SvNOK(sv)) {
        int64_t v = (int64_t)SvIV(sv);

        if (v >= -16 && v <= 15) {
            unsigned char zz = (unsigned char)(zigzag_encode_i64(v) & 0x1F);
            wr_u8(aTHX_ out, (unsigned char)(0xC0 | zz));
            return;
        }
        if (v >= INT32_MIN && v <= INT32_MAX) {
            wr_u8(aTHX_ out, 0x24);
            wr_vint_i(aTHX_ out, v);
            return;
        }
        wr_u8(aTHX_ out, 0x25);
        wr_vint_i(aTHX_ out, v);
        return;
    }

    wr_u8(aTHX_ out, 0x29); /* double */
    double d = (double)SvNV(sv);
    uint64_t u = 0;
    memcpy(&u, &d, sizeof(u));

    unsigned char be[8];
    for (int i = 7; i >= 0; i--) {
        be[i] = (unsigned char)(u & 0xFF);
        u >>= 8;
    }
    wr_ieee_as_7bit_groups(aTHX_ out, be, 64);
}

/* --- booleans --- */
static int is_json_boolean_sv(pTHX_ SV *sv, int *out_bool) {
    if (!SvROK(sv))
        return 0;
    SV *rv = SvRV(sv);
    if (!SvOBJECT(rv))
        return 0;

    const char *pkg = HvNAME(SvSTASH(rv));
    if (!pkg)
        return 0;

    if (strEQ(pkg, "JSON::PP::Boolean") || strEQ(pkg, "JSON::XS::Boolean") ||
        strEQ(pkg, "Cpanel::JSON::XS::Boolean")) {
        *out_bool = SvTRUE(sv) ? 1 : 0;
        return 1;
    }
    return 0;
}

/* --- hash/array encoder --- */
static void encode_hash_entry(pTHX_ SV *out, smile_enc_ctx_t *ctx, SV *k, SV *v) {
    /* shared name? */
    if (ctx->shared_names) {
        int index = -1;
        if (enc_lookup_shared(aTHX_(HV *) SvRV(ctx->seen_names_map), k, &index) && index >= 0) {
            if (index < 64) {
                wr_u8(aTHX_ out, (unsigned char)(0x40 | (index & 0x3F))); /* short shared key */
                encode_value(aTHX_ out, ctx, v);
                return;
            }
            if (index < 1024) {
                wr_u8(aTHX_ out, (unsigned char)(0x30 | ((index >> 8) & 0x03))); /* long shared key */
                wr_u8(aTHX_ out, (unsigned char)(index & 0xFF));
                encode_value(aTHX_ out, ctx, v);
                return;
            }
        }
    }

    int trackable = 0;
    SV *kkey = NULL;
    wr_key_name(aTHX_ out, k, &trackable, &kkey);

    if (ctx->shared_names && trackable) {
        int idx = ctx->seen_name_count;
        if (idx < MAX_SHARED_NAMES) {
            if (valid_backref_index(idx)) {
                enc_store_shared(aTHX_(HV *) SvRV(ctx->seen_names_map), kkey, idx);
            }
            ctx->seen_name_count = idx + 1;
        } else {
            /* reset */
            hv_clear((HV *)SvRV(ctx->seen_names_map));
            ctx->seen_name_count = 0;
            if (valid_backref_index(0))
                enc_store_shared(aTHX_(HV *) SvRV(ctx->seen_names_map), kkey, 0);
            ctx->seen_name_count = 1;
        }
    }
    if (kkey)
        SvREFCNT_dec(kkey);

    encode_value(aTHX_ out, ctx, v);
}

static void encode_hash(pTHX_ SV *out, smile_enc_ctx_t *ctx, HV *hv) {
    wr_u8(aTHX_ out, 0xFA); /* START_OBJECT */

    if (!ctx->canonical) {
        hv_iterinit(hv);
        HE *he;
        while ((he = hv_iternext(hv)) != NULL) {
            SV *k = hv_iterkeysv(he);
            SV *v = hv_iterval(hv, he);
            encode_hash_entry(aTHX_ out, ctx, k, v);
        }
    } else {
        SSize_t count = HvUSEDKEYS(hv);
        if (count > 0) {
            typedef struct {
                SV *k;
                SV *v;
            } smile_hash_entry_t;

            smile_hash_entry_t *entries;
            Newx(entries, (size_t)count, smile_hash_entry_t);

            hv_iterinit(hv);
            HE *he;
            SSize_t used = 0;
            while ((he = hv_iternext(hv)) != NULL) {
                entries[used].k = newSVsv(hv_iterkeysv(he));
                entries[used].v = hv_iterval(hv, he);
                used++;
            }

            for (SSize_t i = 1; i < used; i++) {
                smile_hash_entry_t current = entries[i];
                SSize_t j = i;
                while (j > 0 && sv_cmp(current.k, entries[j - 1].k) < 0) {
                    entries[j] = entries[j - 1];
                    j--;
                }
                entries[j] = current;
            }

            for (SSize_t i = 0; i < used; i++) {
                encode_hash_entry(aTHX_ out, ctx, entries[i].k, entries[i].v);
                SvREFCNT_dec(entries[i].k);
            }

            Safefree(entries);
        }
    }

    wr_u8(aTHX_ out, 0xFB); /* END_OBJECT */
}

static void encode_array(pTHX_ SV *out, smile_enc_ctx_t *ctx, AV *av) {
    wr_u8(aTHX_ out, 0xF8); /* START_ARRAY */
    SSize_t n = av_len(av);
    for (SSize_t i = 0; i <= n; i++) {
        SV **svp = av_fetch(av, i, 0);
        SV *v = svp ? *svp : &PL_sv_undef;
        encode_value(aTHX_ out, ctx, v);
    }
    wr_u8(aTHX_ out, 0xF9); /* END_ARRAY */
}

static void encode_value(pTHX_ SV *out, smile_enc_ctx_t *ctx, SV *sv) {
    if (!sv || !SvOK(sv)) {
        wr_u8(aTHX_ out, 0x21);
        return;
    }

    int b = 0;
    if (is_json_boolean_sv(aTHX_ sv, &b)) {
        wr_u8(aTHX_ out, b ? 0x23 : 0x22);
        return;
    }

    if (SvROK(sv)) {
        SV *maybe = maybe_to_json(aTHX_ sv);
        if (maybe != sv) {
            SV *mortal = sv_2mortal(maybe);
            encode_value(aTHX_ out, ctx, mortal);
            return;
        }

        SV *rv = SvRV(sv);
        if (SvTYPE(rv) == SVt_PVAV) {
            encode_array(aTHX_ out, ctx, (AV *)rv);
            return;
        }
        if (SvTYPE(rv) == SVt_PVHV) {
            encode_hash(aTHX_ out, ctx, (HV *)rv);
            return;
        }
        if (SvTYPE(rv) == SVt_PV) {
            encode_string_value(aTHX_ out, ctx, rv);
            return;
        }

        if (SvTYPE(rv) == SVt_IV || SvTYPE(rv) == SVt_NV || SvTYPE(rv) == SVt_PVIV ||
            SvTYPE(rv) == SVt_PVNV) {
            encode_number(aTHX_ out, rv);
            return;
        }

        croak("Unsupported reference type for Smile encoding");
    }

    if (SvOK(sv) && SvPOK(sv) && !SvIOK(sv) && !SvNOK(sv)) {
        encode_string_value(aTHX_ out, ctx, sv);
        return;
    }

    if (SvIOK(sv) || SvNOK(sv)) {
        encode_number(aTHX_ out, sv);
        return;
    }

    {
        encode_string_value(aTHX_ out, ctx, sv);
    }
}

/* --- decoding helpers --- */
static SV *rd_string_len(pTHX_ smile_reader_t *r, size_t len, int set_utf8) {
    /* newSV(len) + SvPOK_on can leave PVX in an unexpected state on some builds.
     * Allocate as a PV explicitly, then grow.
     */
    SV *sv = newSVpvn("", 0);
    SvGROW(sv, (STRLEN)len + 1);
    unsigned char *dst = (unsigned char *)SvPVX(sv);
    rd_bytes(aTHX_ r, dst, len);
    dst[len] = '\0';
    SvCUR_set(sv, (STRLEN)len);
    if (set_utf8)
        SvUTF8_on(sv);
    return sv;
}
static SV *rd_string_eos(pTHX_ smile_reader_t *r, int ascii_hint) {
	const unsigned char *start = r->p;
	const unsigned char *stop = (const unsigned char *)memchr(start, 0xFC, (size_t)(r->end - start));
	if (!stop)
		smile_croak(aTHX_ "Unexpected EOF");

	SV *sv = newSVpvn((const char *)start, (STRLEN)(stop - start));
	r->p = stop + 1;

	if (!ascii_hint)
		SvUTF8_on(sv);
	return sv;
}
static SV *nv_to_sv(pTHX_ NV n) {
    NV absn = n < 0 ? -n : n;
    if (absn >= 9.0e15) {
        if (n >= (NV)IV_MIN && n <= (NV)IV_MAX) {
            IV iv = (IV)n;
            if ((NV)iv == n)
                return newSViv(iv);
        }

        if (n >= 0.0 && n <= (NV)UV_MAX) {
            UV uv = (UV)n;
            if ((NV)uv == n)
                return newSVuv(uv);
        }
    }

    return newSVnv(n);
}

static SV *make_json_boolean(pTHX_ int b, int use_json_bool) {
    if (use_json_bool && json_true_cache && json_false_cache)
        return newSVsv( b ? json_true_cache : json_false_cache );
    return b ? &PL_sv_yes : &PL_sv_no;
}

static void dec_track_name(pTHX_ smile_dec_ctx_t *ctx, SV *name) {
	if (!ctx->shared_names)
		return;
	int idx = ctx->seen_name_count;
	if (idx >= MAX_SHARED_NAMES) {
		for (int i = 0; i < ctx->seen_name_count; i++)
			SvREFCNT_dec(ctx->seen_names[i]);
		ctx->seen_name_count = 0;
		idx = 0;
	}
	if (valid_backref_index(idx)) {
		ctx->seen_names[idx] = name;
		SvREFCNT_inc_simple_void_NN(name);
	} else {
		ctx->seen_names[idx] = &PL_sv_undef;
		SvREFCNT_inc(ctx->seen_names[idx]);
	}
	ctx->seen_name_count = idx + 1;
}
static void dec_track_value(pTHX_ smile_dec_ctx_t *ctx, SV *val) {
	if (!ctx->shared_values)
		return;
	STRLEN len = 0;
	(void)SvPVbyte(val, len);
	if (len > 64)
		return;

	int idx = ctx->seen_value_count;
	if (idx >= MAX_SHARED_VALUES) {
		for (int i = 0; i < ctx->seen_value_count; i++)
			SvREFCNT_dec(ctx->seen_values[i]);
		ctx->seen_value_count = 0;
		idx = 0;
	}
	if (valid_backref_index(idx)) {
		ctx->seen_values[idx] = val;
		SvREFCNT_inc_simple_void_NN(val);
	} else {
		ctx->seen_values[idx] = &PL_sv_undef;
		SvREFCNT_inc(ctx->seen_values[idx]);
	}
	ctx->seen_value_count = idx + 1;
}

static SV *decode_array(pTHX_ smile_reader_t *r, smile_dec_ctx_t *ctx) {
    AV *av = newAV();
    for (;;) {
        if (r->p >= r->end)
            smile_croak(aTHX_ "Unexpected EOF in array");
        unsigned char peek = *r->p;
        if (peek == 0xF9) {
            r->p++;
            break;
        }
        SV *v = decode_value(aTHX_ r, ctx);
        av_push(av, v);
    }
    return newRV_noinc((SV *)av);
}

static SV *decode_object(pTHX_ smile_reader_t *r, smile_dec_ctx_t *ctx) {
    HV *hv = newHV();

    for (;;) {
        unsigned char t = rd_u8(aTHX_ r);

        if (t == 0xFB)
            break; /* END_OBJECT */

        SV *key = NULL;

        if (t == 0x20) {
            key = newSVpvn("", 0);
        } else if (t >= 0x40 && t <= 0x7F) {
            /* short shared name ref: low 6 bits */
            int index = (int)(t & 0x3F);
            if (!ctx->shared_names || index >= ctx->seen_name_count)
                smile_croak(aTHX_ "Invalid shared name reference");
            key = ctx->seen_names[index];
            SvREFCNT_inc_simple_void_NN(key);
        } else if (t >= 0x80 && t <= 0xBF) {
            size_t len = (size_t)(t - 0x80) + 1;
            key = rd_string_len(aTHX_ r, len, 0);
            dec_track_name(aTHX_ ctx, key);
        } else if (t >= 0xC0 && t <= 0xF7) {
            size_t len = (size_t)(t - 0xC0) + 2;
            key = rd_string_len(aTHX_ r, len, 1);
            dec_track_name(aTHX_ ctx, key);
        } else if (t >= 0x30 && t <= 0x33) {
            int lo = rd_u8(aTHX_ r);
            int index = ((t & 0x03) << 8) | lo;
            if (!ctx->shared_names || index >= ctx->seen_name_count)
                smile_croak(aTHX_ "Invalid long shared name reference");
            key = ctx->seen_names[index];
            SvREFCNT_inc_simple_void_NN(key);
        } else if (t == 0x34) {
            key = rd_string_eos(aTHX_ r, 0);
            dec_track_name(aTHX_ ctx, key);
        } else {
            smile_croak(aTHX_ "Invalid key token");
        }

        SV *val = decode_value(aTHX_ r, ctx);
        hv_store_ent(hv, key, val, 0);
        SvREFCNT_dec(key);
    }

    return newRV_noinc((SV *)hv);
}

static SV *decode_value(pTHX_ smile_reader_t *r, smile_dec_ctx_t *ctx) {
    unsigned char t = rd_u8(aTHX_ r);

    if (t == 0xFF)
        return &PL_sv_undef;

    if (t == 0x20)
        return newSVpvn("", 0);
    if (t == 0x21)
        return &PL_sv_undef;
    if (t == 0x22)
        return make_json_boolean(aTHX_ 0, ctx->json_bool);
    if (t == 0x23)
        return make_json_boolean(aTHX_ 1, ctx->json_bool);

    if (t == 0xF8)
        return decode_array(aTHX_ r, ctx);
    if (t == 0xFA)
        return decode_object(aTHX_ r, ctx);

    /* shared string value refs
     *
     * Return a copy here, not the cached SV itself. Values that land in
     * Perl hashes/arrays must remain independently mutable.
     */
    if (t >= 0x01 && t <= 0x1F) {
        int index = (int)t - 1;
        if (!ctx->shared_values || index >= ctx->seen_value_count)
            smile_croak(aTHX_ "Invalid shared string value reference");
        return newSVsv(ctx->seen_values[index]);
    }
    if ((t & 0xFC) == 0xEC) {
        int lo = rd_u8(aTHX_ r);
        int index = ((t & 0x03) << 8) | lo;
        if (!ctx->shared_values || index >= ctx->seen_value_count)
            smile_croak(aTHX_ "Invalid long shared string value reference");
        return newSVsv(ctx->seen_values[index]);
    }

    /* tiny/short strings */
    if ((t & 0xE0) == 0x40) {
        size_t len = (size_t)(t & 0x1F) + 1;
        SV *sv = rd_string_len(aTHX_ r, len, 0);
        dec_track_value(aTHX_ ctx, sv);
        return sv;
    }
    if ((t & 0xE0) == 0x60) {
        size_t len = (size_t)(t & 0x1F) + 33;
        SV *sv = rd_string_len(aTHX_ r, len, 0);
        dec_track_value(aTHX_ ctx, sv);
        return sv;
    }
    if ((t & 0xE0) == 0x80) {
        size_t len = (size_t)(t & 0x1F) + 2;
        SV *sv = rd_string_len(aTHX_ r, len, 1);
        dec_track_value(aTHX_ ctx, sv);
        return sv;
    }
    if ((t & 0xE0) == 0xA0) {
        size_t len = (size_t)(t & 0x1F) + 34;
        SV *sv = rd_string_len(aTHX_ r, len, 1);
        dec_track_value(aTHX_ ctx, sv);
        return sv;
    }

    /* small int */
    if ((t & 0xE0) == 0xC0) {
        uint64_t zz = (uint64_t)(t & 0x1F);
        int64_t v = zigzag_decode_u64(zz);
        return newSViv((IV)v);
    }

    if (t == 0x24 || t == 0x25) {
        uint64_t u = rd_vint_u(aTHX_ r);
        int64_t v = zigzag_decode_u64(u);
        if (t == 0x24 && (v < INT32_MIN || v > INT32_MAX))
            smile_croak(aTHX_ "Invalid int32 VInt (out of range)");
        return newSViv((IV)v);
    }

    if (t == 0x26) {
        uint64_t raw_len_u = rd_vint_u(aTHX_ r);
        if (raw_len_u == 0)
            smile_croak(aTHX_ "Invalid BigInteger length");
        if (raw_len_u > 1024)
            smile_croak(aTHX_ "BigInteger too large");
        size_t raw_len = (size_t)raw_len_u;
        SV *bytes = rd_safe7_binary(aTHX_ r, raw_len);
        STRLEN n = 0;
        const unsigned char *bp = (const unsigned char *)SvPVbyte(bytes, n);

        int negative = (bp[0] & 0x80) ? 1 : 0;
        if (n <= 8 || (n == 9 && !negative && bp[0] == 0x00)) {
            const unsigned char *p = bp;
            if (n == 9) {
                p = bp + 1;
                n = 8;
            }
            uint64_t uv = 0;
            for (STRLEN i = 0; i < n; i++)
                uv = (uv << 8) | (uint64_t)p[i];
            SvREFCNT_dec(bytes);
            if (!negative) {
                if (uv <= (uint64_t)IV_MAX)
                    return newSViv((IV)uv);
                return newSVuv((UV)uv);
            }
            int64_t sv = (int64_t)uv;
            return newSViv((IV)sv);
        }

        /* fallback for very large integers: return decimal string via Math::BigInt if available */
        if (ctx->use_bigint && eval_pv("require Math::BigInt; 1", TRUE)) {
            SV *hex = newSVpvn(negative ? "-0x" : "0x", negative ? 3 : 2);
            for (STRLEN i = 0; i < n; i++) {
                sv_catpvf(hex, "%02x", (unsigned int)bp[i]);
            }
            dSP;
            ENTER;
            SAVETMPS;
            PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVpv("Math::BigInt", 0)));
            XPUSHs(sv_2mortal(hex));
            PUTBACK;
            call_method("from_hex", G_SCALAR);
            SPAGAIN;
            SV *ret = newSVsv(POPs);
            PUTBACK;
            FREETMPS;
            LEAVE;
            SvREFCNT_dec(bytes);
            return ret;
        }

        {
            NV mag = 0.0;
            for (STRLEN i = 0; i < n; i++) {
                mag = (mag * 256.0) + (NV)bp[i];
            }
            if (negative) {
                NV two_pow = 1.0;
                for (STRLEN i = 0; i < n * 8; i++)
                    two_pow *= 2.0;
                mag -= two_pow;
            }
            SvREFCNT_dec(bytes);
            return newSVnv(mag);
        }

        SvREFCNT_dec(bytes);
        smile_croak(aTHX_ "BigInteger decode failed");
    }

    if (t == 0x28)
        return nv_to_sv(aTHX_ rd_ieee_from_7bit_groups(aTHX_ r, 32));
    if (t == 0x29)
        return nv_to_sv(aTHX_ rd_ieee_from_7bit_groups(aTHX_ r, 64));

    if (t == 0xE0)
        return rd_string_eos(aTHX_ r, 1);
    if (t == 0xE4)
        return rd_string_eos(aTHX_ r, 0);

    smile_croak(aTHX_ "Unsupported token encountered");
    return &PL_sv_undef;
}
MODULE = Data::Smile::XS  PACKAGE = Data::Smile::XS
PROTOTYPES: DISABLE

BOOT:
  init_json_bool_cache(aTHX);

SV*
encode_smile(sv, ...)
  SV *sv
PREINIT:
  SV *opts = NULL;
  HV *opts_hv = NULL;
  HE *he = NULL;
  STRLEN klen = 0;
CODE:
  {
    if (items > 2) smile_croak(aTHX_ "encode_smile expects at most 2 arguments");
    if (items == 2) {
      opts = ST(1);
      if (SvOK(opts)) {
        if (!SvROK(opts) || SvTYPE(SvRV(opts)) != SVt_PVHV)
          smile_croak(aTHX_ "Options must be a hash reference");
        opts_hv = (HV*)SvRV(opts);
      }
    }

    SV *out = newSVpvn("", 0);

    int write_header = 1;
    int shared_names = 1;
    int shared_values = 1;
    int canonical = 0;

    if (opts_hv) {
      hv_iterinit(opts_hv);
      while ((he = hv_iternext(opts_hv))) {
        const char *k = HePV(he, klen);
        SV *v = HeVAL(he);
        if (klen == 12 && memEQ(k, "write_header", 12)) {
          write_header = SvTRUE(v) ? 1 : 0;
          continue;
        }
        if (klen == 12 && memEQ(k, "shared_names", 12)) {
          shared_names = SvTRUE(v) ? 1 : 0;
          continue;
        }
        if (klen == 13 && memEQ(k, "shared_values", 13)) {
          shared_values = SvTRUE(v) ? 1 : 0;
          continue;
        }
        if (klen == 9 && memEQ(k, "canonical", 9)) {
          canonical = SvTRUE(v) ? 1 : 0;
          continue;
        }
        smile_croak(aTHX_ "Unknown option for encode_smile");
      }
    }

    if (!write_header) {
      if (!hv_exists(opts_hv, "shared_values", 13)) {
        shared_values = 0;
      }
    }

    if (write_header) {
      unsigned char h3 = 0;
      if (shared_names) h3 |= 0x01;
      if (shared_values) h3 |= 0x02;
      unsigned char hdr[4] = { SMILE_HDR0, SMILE_HDR1, SMILE_HDR2, h3 };
      wr_bytes(aTHX_ out, hdr, 4);
    }

    smile_enc_ctx_t ctx;
    ctx.shared_names  = shared_names;
    ctx.shared_values = shared_values;
    ctx.canonical = canonical;
    ctx.seen_name_count  = 0;
    ctx.seen_value_count = 0;
    ctx.seen_names_map  = (SV*)newRV_noinc((SV*)newHV());
    ctx.seen_values_map = (SV*)newRV_noinc((SV*)newHV());

    encode_value(aTHX_ out, &ctx, sv);

    SvREFCNT_dec(ctx.seen_names_map);
    SvREFCNT_dec(ctx.seen_values_map);

    RETVAL = out;
  }
OUTPUT:
  RETVAL

SV*
decode_smile(bytes, ...)
  SV *bytes
PREINIT:
  SV *opts = NULL;
  HV *opts_hv = NULL;
  HE *he = NULL;
  STRLEN klen = 0;
  int require_header = 0;
CODE:
  {
    if (items > 2) smile_croak(aTHX_ "decode_smile expects at most 2 arguments");
    if (items == 2) {
      opts = ST(1);
      if (SvOK(opts)) {
        if (!SvROK(opts) || SvTYPE(SvRV(opts)) != SVt_PVHV)
          smile_croak(aTHX_ "Options must be a hash reference");
        opts_hv = (HV*)SvRV(opts);
      }
    }

    STRLEN len = 0;
    const unsigned char *p = (const unsigned char*)SvPVbyte(bytes, len);

    smile_reader_t r;
    r.p = p;
    r.end = p + len;

    smile_dec_ctx_t ctx;
    ctx.shared_names = 1;   /* default true if header missing :contentReference[oaicite:3]{index=3} */
    ctx.shared_values = 0;  /* default false if header missing :contentReference[oaicite:4]{index=4} */
    ctx.use_bigint = 1;
    ctx.json_bool = 1;
    ctx.seen_name_count = 0;
    ctx.seen_value_count = 0;
    for (int i = 0; i < MAX_SHARED_NAMES; i++) ctx.seen_names[i] = NULL;
    for (int i = 0; i < MAX_SHARED_VALUES; i++) ctx.seen_values[i] = NULL;

    if (opts_hv) {
      hv_iterinit(opts_hv);
      while ((he = hv_iternext(opts_hv))) {
        const char *k = HePV(he, klen);
        if (klen == 10 && memEQ(k, "use_bigint", 10)) {
          SV *v = HeVAL(he);
          ctx.use_bigint = SvTRUE(v) ? 1 : 0;
          continue;
        }
        if (klen == 14 && memEQ(k, "require_header", 14)) {
          SV *v = HeVAL(he);
          require_header = SvTRUE(v) ? 1 : 0;
          continue;
        }
        if (klen == 9 && memEQ(k, "json_bool", 9)) {
          SV *v = HeVAL(he);
          ctx.json_bool = SvTRUE(v) ? 1 : 0;
          continue;
        }
        smile_croak(aTHX_ "Unknown option for decode_smile");
      }
    }

    if ((size_t)(r.end - r.p) >= 4 && r.p[0] == SMILE_HDR0 && r.p[1] == SMILE_HDR1 && r.p[2] == SMILE_HDR2) {
      unsigned char h3 = r.p[3];
      r.p += 4;
      ctx.shared_names  = (h3 & 0x01) ? 1 : 0;
      ctx.shared_values = (h3 & 0x02) ? 1 : 0;
    }
    else if (require_header) {
      smile_croak(aTHX_ "Smile header required");
    }

    RETVAL = decode_value(aTHX_ &r, &ctx);

    for (int i = 0; i < ctx.seen_name_count; i++) if (ctx.seen_names[i]) SvREFCNT_dec(ctx.seen_names[i]);
    for (int i = 0; i < ctx.seen_value_count; i++) if (ctx.seen_values[i]) SvREFCNT_dec(ctx.seen_values[i]);
  }
OUTPUT:
  RETVAL
