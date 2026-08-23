#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* G_LIST is the 5.36 name for G_ARRAY */
#ifndef G_LIST
#define G_LIST G_ARRAY
#endif

/* XS_INTERNAL is 5.16+ and mg_findext 5.14+; the floor is 5.10 */
#ifndef XS_INTERNAL
#define XS_INTERNAL(name) static void name(pTHX_ CV *cv)
#endif
#ifndef mg_findext
static MAGIC *
pt_mg_findext(pTHX_ const SV *sv, int type, const MGVTBL *vtbl)
{
    MAGIC *mg;
    if (sv && SvTYPE(sv) >= SVt_PVMG)
        for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic)
            if (mg->mg_type == type && mg->mg_virtual == vtbl)
                return mg;
    return NULL;
}
#define mg_findext(sv, type, vtbl) pt_mg_findext(aTHX_ (sv), (type), (vtbl))
#endif

#include <time.h>

#include "frh_abi.h"
#include "qr_abi.h"
#include "ptotp/ptotp_b32.h"
#include "ptotp/ptotp_rand.h"
#include "ptotp/ptotp_otp.h"

/* Punk::TOTP - the engine. 100% XS; the .pm is a version number and
 * the POD. HMAC comes from File::Raw::Hash's frh_abi, resolved once
 * at boot; nothing links and nothing here touches libcrypto. */

#define PTOTP_FRH_NEED 1

static const frh_abi *PT_FRH = NULL;

typedef struct {
    const char *name;      /* as otpauth:// spells it */
    int         frh_id;
    size_t      secret_bytes;
} pt_alg_t;

static pt_alg_t PT_ALGS[3] = {
    { "SHA1",   -1, 20 },
    { "SHA256", -1, 32 },
    { "SHA512", -1, 64 },
};

static void pt_boot(pTHX)
{
    IV p = 0;
    dSP;

    ENTER; SAVETMPS;
    eval_pv("require File::Raw::Hash;", TRUE);
    PUSHMARK(SP); PUTBACK;
    if (call_pv("File::Raw::Hash::_abi_ptr", G_SCALAR | G_EVAL) > 0) {
        SPAGAIN;
        p = POPi;
        PUTBACK;
    }
    FREETMPS; LEAVE;

    PT_FRH = p ? INT2PTR(const frh_abi *, p) : NULL;
    if (!PT_FRH || PT_FRH->version < PTOTP_FRH_NEED)
        croak("Punk::TOTP: File::Raw::Hash with frh_abi version %d or "
              "newer is required", PTOTP_FRH_NEED);

    {
        const frh_algo_t *a;
        if (!(a = PT_FRH->algo_by_name("sha1", 4)) || !a->hmac_able)
            croak("Punk::TOTP: the frh_abi registry has no hmac-able sha1");
        PT_ALGS[0].frh_id = a->id;
        if (!(a = PT_FRH->algo_by_name("sha256", 6)) || !a->hmac_able)
            croak("Punk::TOTP: the frh_abi registry has no hmac-able sha256");
        PT_ALGS[1].frh_id = a->id;
        if (!(a = PT_FRH->algo_by_name("sha512", 6)) || !a->hmac_able)
            croak("Punk::TOTP: the frh_abi registry has no hmac-able sha512");
        PT_ALGS[2].frh_id = a->id;
    }
}

/* ---- options ------------------------------------------------------------- */

static HV *pt_pairs(pTHX_ const char *what, SV **base, I32 from, I32 items)
{
    HV *hv = newHV();
    I32 i;

    sv_2mortal((SV *)hv);
    if ((items - from) % 2)
        croak("odd number of options given to %s", what);
    for (i = from; i < items; i += 2) {
        STRLEN kl;
        const char *k = SvPV_const(base[i], kl);
        (void)hv_store(hv, k, (I32)kl, SvREFCNT_inc(base[i + 1]), 0);
    }
    return hv;
}

static void pt_check_keys(pTHX_ const char *what, HV *hv,
                          const char *const *ok, int nok)
{
    HE *he;

    hv_iterinit(hv);
    while ((he = hv_iternext(hv))) {
        const char *k = HePV(he, PL_na);
        int j, found = 0;
        for (j = 0; j < nok; j++)
            if (strEQ(k, ok[j])) { found = 1; break; }
        if (!found)
            croak("unknown %s option '%s'", what, k);
    }
}

static SV *pt_fetch(pTHX_ HV *hv, const char *key)
{
    SV **svp = hv_fetch(hv, key, (I32)strlen(key), 0);
    return (svp && SvOK(*svp)) ? *svp : NULL;
}

static const pt_alg_t *pt_alg_of(pTHX_ SV *sv)
{
    STRLEN n;
    const char *p;
    int i;

    if (!sv)
        return &PT_ALGS[0];
    p = SvPV_const(sv, n);
    for (i = 0; i < 3; i++) {
        const char *want = PT_ALGS[i].name;
        size_t wl = strlen(want);
        size_t j;
        if (n != wl)
            continue;
        for (j = 0; j < wl; j++)
            if (toUPPER(p[j]) != want[j])
                break;
        if (j == wl)
            return &PT_ALGS[i];
    }
    croak("algorithm must be sha1, sha256 or sha512, not '%.*s'",
          (int)n, p);
    return NULL;
}

static int pt_digits_of(pTHX_ SV *sv)
{
    IV d;
    if (!sv)
        return 6;
    d = SvIV(sv);
    if (d < 6 || d > 8)
        croak("digits must be 6, 7 or 8, not %" IVdf, d);
    return (int)d;
}

static unsigned pt_period_of(pTHX_ SV *sv)
{
    IV s;
    if (!sv)
        return 30;
    s = SvIV(sv);
    if (s < 1 || s > 300)
        croak("period must be 1 to 300 seconds, not %" IVdf, s);
    return (unsigned)s;
}

static ptotp_u64 pt_time_of(pTHX_ SV *sv)
{
    if (!sv)
        return (ptotp_u64)time(NULL);
    /* through NV, deliberately: the RFC 6238 vectors reach
     * 20000000000, past IV on the 32-bit smokers */
    return (ptotp_u64)SvNV(sv);
}

/* Decode a base32 secret into a mortal buffer. */
static unsigned char *pt_secret_of(pTHX_ SV *sv, size_t *outlen)
{
    STRLEN n;
    const char *p = SvPV_const(sv, n);
    unsigned char *buf;
    long got;

    Newx(buf, n ? (n * 5) / 8 + 1 : 1, unsigned char);
    SAVEFREEPV(buf);
    got = ptotp_b32_decode(buf, p, n);
    if (got < 0)
        croak("secret is not valid base32");
    if (got == 0)
        croak("secret is empty");
    *outlen = (size_t)got;
    return buf;
}

/* ---- uri ----------------------------------------------------------------- */

static void pt_uri_escape(pTHX_ SV *out, const char *p, STRLEN n)
{
    static const char hexd[] = "0123456789ABCDEF";
    STRLEN i;

    for (i = 0; i < n; i++) {
        unsigned char c = (unsigned char)p[i];
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '_' ||
            c == '.' || c == '~') {
            sv_catpvn(out, (const char *)&p[i], 1);
        } else {
            char esc[3];
            esc[0] = '%';
            esc[1] = hexd[c >> 4];
            esc[2] = hexd[c & 15];
            sv_catpvn(out, esc, 3);
        }
    }
}

#include "ptotp/ptotp_plugin.h"   /* the plugin: needs the helpers above */

MODULE = Punk::TOTP    PACKAGE = Punk::TOTP

PROTOTYPES: DISABLE

BOOT:
    pt_boot(aTHX);

SV *
secret(class, ...)
    SV *class
  CODE:
    {
        static const char *const ok[] = { "algorithm", "bytes" };
        HV *opt = pt_pairs(aTHX_ "secret", &ST(0), 1, items);
        const pt_alg_t *alg;
        unsigned char raw[128];
        char b32[((sizeof raw + 4) / 5) * 8 + 1];
        size_t nbytes;
        SV *sv;

        PERL_UNUSED_VAR(class);
        pt_check_keys(aTHX_ "secret", opt, ok, 2);
        alg = pt_alg_of(aTHX_ pt_fetch(aTHX_ opt, "algorithm"));
        nbytes = alg->secret_bytes;
        if ((sv = pt_fetch(aTHX_ opt, "bytes"))) {
            IV b = SvIV(sv);
            if (b < 16 || b > (IV)sizeof raw)
                croak("bytes must be 16 to %d, not %" IVdf,
                      (int)sizeof raw, b);
            nbytes = (size_t)b;
        }
        if (ptotp_random_bytes(raw, nbytes) != 0)
            croak("Punk::TOTP: the entropy source failed; refusing to "
                  "degrade");
        ptotp_b32_encode(b32, raw, nbytes);
        RETVAL = newSVpv(b32, 0);
    }
  OUTPUT:
    RETVAL

SV *
uri(class, secret, ...)
    SV *class
    SV *secret
  CODE:
    {
        static const char *const ok[] =
            { "issuer", "account", "algorithm", "digits", "period" };
        HV *opt = pt_pairs(aTHX_ "uri", &ST(0), 2, items);
        const pt_alg_t *alg;
        SV *issuer, *account;
        STRLEN sn, in, an;
        const char *sec, *ip, *ap;
        int digits;
        unsigned period;
        SV *out;

        PERL_UNUSED_VAR(class);
        pt_check_keys(aTHX_ "uri", opt, ok, 5);
        issuer  = pt_fetch(aTHX_ opt, "issuer");
        account = pt_fetch(aTHX_ opt, "account");
        if (!issuer || !account)
            croak("uri needs both issuer and account");
        alg    = pt_alg_of(aTHX_ pt_fetch(aTHX_ opt, "algorithm"));
        digits = pt_digits_of(aTHX_ pt_fetch(aTHX_ opt, "digits"));
        period = pt_period_of(aTHX_ pt_fetch(aTHX_ opt, "period"));

        /* validate the secret decodes before advertising it */
        {
            size_t slen;
            (void)pt_secret_of(aTHX_ secret, &slen);
        }

        sec = SvPV_const(secret, sn);
        ip = SvPV_const(issuer, in);
        ap = SvPV_const(account, an);

        /* The issuer appears twice - label prefix and query parameter -
         * because different apps read different ones. The label colon
         * is the separator and is NEVER percent-encoded; everything
         * else is. Non-default algorithm/digits/period are included,
         * defaults omitted to keep the QR payload small. */
        out = newSVpvs("otpauth://totp/");
        pt_uri_escape(aTHX_ out, ip, in);
        sv_catpvs(out, ":");
        pt_uri_escape(aTHX_ out, ap, an);
        sv_catpvs(out, "?secret=");
        sv_catpvn(out, sec, sn);
        sv_catpvs(out, "&issuer=");
        pt_uri_escape(aTHX_ out, ip, in);
        if (alg != &PT_ALGS[0]) {
            sv_catpvs(out, "&algorithm=");
            sv_catpv(out, alg->name);
        }
        if (digits != 6)
            sv_catpvf(out, "&digits=%d", digits);
        if (period != 30)
            sv_catpvf(out, "&period=%u", period);
        RETVAL = out;
    }
  OUTPUT:
    RETVAL

SV *
hotp(class, secret, counter, ...)
    SV *class
    SV *secret
    SV *counter
  CODE:
    {
        static const char *const ok[] = { "algorithm", "digits" };
        HV *opt = pt_pairs(aTHX_ "hotp", &ST(0), 3, items);
        const pt_alg_t *alg;
        unsigned char *sec;
        size_t slen;
        unsigned long code;
        int digits;
        char buf[9];

        PERL_UNUSED_VAR(class);
        pt_check_keys(aTHX_ "hotp", opt, ok, 2);
        alg    = pt_alg_of(aTHX_ pt_fetch(aTHX_ opt, "algorithm"));
        digits = pt_digits_of(aTHX_ pt_fetch(aTHX_ opt, "digits"));
        sec    = pt_secret_of(aTHX_ secret, &slen);

        code = ptotp_hotp(PT_FRH, alg->frh_id, sec, slen,
                          (ptotp_u64)SvNV(counter), digits);
        if (code == (unsigned long)-1)
            croak("Punk::TOTP: hmac failed");
        ptotp_render(code, digits, buf);
        RETVAL = newSVpv(buf, (STRLEN)digits);
    }
  OUTPUT:
    RETVAL

SV *
code(class, secret, ...)
    SV *class
    SV *secret
  CODE:
    {
        static const char *const ok[] =
            { "algorithm", "digits", "period", "time" };
        HV *opt = pt_pairs(aTHX_ "code", &ST(0), 2, items);
        const pt_alg_t *alg;
        unsigned char *sec;
        size_t slen;
        unsigned long c;
        int digits;
        char buf[9];

        PERL_UNUSED_VAR(class);
        pt_check_keys(aTHX_ "code", opt, ok, 4);
        alg    = pt_alg_of(aTHX_ pt_fetch(aTHX_ opt, "algorithm"));
        digits = pt_digits_of(aTHX_ pt_fetch(aTHX_ opt, "digits"));
        sec    = pt_secret_of(aTHX_ secret, &slen);

        c = ptotp_totp_at(PT_FRH, alg->frh_id, sec, slen,
                          pt_time_of(aTHX_ pt_fetch(aTHX_ opt, "time")),
                          pt_period_of(aTHX_ pt_fetch(aTHX_ opt, "period")),
                          digits);
        if (c == (unsigned long)-1)
            croak("Punk::TOTP: hmac failed");
        ptotp_render(c, digits, buf);
        RETVAL = newSVpv(buf, (STRLEN)digits);
    }
  OUTPUT:
    RETVAL

void
verify(class, secret, code, ...)
    SV *class
    SV *secret
    SV *code
  PPCODE:
    {
        static const char *const ok[] =
            { "algorithm", "digits", "period", "time", "skew",
              "last_counter" };
        HV *opt = pt_pairs(aTHX_ "verify", &ST(0), 3, items);
        const pt_alg_t *alg;
        unsigned char *sec;
        size_t slen;
        STRLEN cn;
        const char *cp;
        SV *sv;
        unsigned skew = 1;
        ptotp_u64 last = (ptotp_u64)-1, matched = 0;
        int ok_rc;

        PERL_UNUSED_VAR(class);
        pt_check_keys(aTHX_ "verify", opt, ok, 6);
        alg = pt_alg_of(aTHX_ pt_fetch(aTHX_ opt, "algorithm"));
        sec = pt_secret_of(aTHX_ secret, &slen);
        cp  = SvPV_const(code, cn);

        if ((sv = pt_fetch(aTHX_ opt, "skew"))) {
            IV s = SvIV(sv);
            if (s < 0 || s > 10)
                croak("skew must be 0 to 10 steps, not %" IVdf, s);
            skew = (unsigned)s;
        }
        if ((sv = pt_fetch(aTHX_ opt, "last_counter")))
            last = (ptotp_u64)SvNV(sv);

        ok_rc = ptotp_verify(PT_FRH, alg->frh_id, sec, slen,
            pt_time_of(aTHX_ pt_fetch(aTHX_ opt, "time")),
            pt_period_of(aTHX_ pt_fetch(aTHX_ opt, "period")),
            pt_digits_of(aTHX_ pt_fetch(aTHX_ opt, "digits")),
            cp, (size_t)cn, skew, last, &matched);

        if (GIMME_V == G_LIST) {
            EXTEND(SP, 2);
            mPUSHi(ok_rc);
            if (ok_rc)
                mPUSHs(newSVnv((NV)matched));
            else
                mPUSHs(newSV(0));
        } else {
            mXPUSHi(ok_rc);
        }
    }

SV *
b32_encode(class, bytes)
    SV *class
    SV *bytes
  CODE:
    {
        STRLEN n;
        const unsigned char *p =
            (const unsigned char *)SvPVbyte(bytes, n);
        char *out;

        PERL_UNUSED_VAR(class);
        Newx(out, ptotp_b32_elen(n) + 1, char);
        SAVEFREEPV(out);
        ptotp_b32_encode(out, p, n);
        RETVAL = newSVpv(out, 0);
    }
  OUTPUT:
    RETVAL

SV *
b32_decode(class, text)
    SV *class
    SV *text
  CODE:
    {
        STRLEN n;
        const char *p = SvPV_const(text, n);
        unsigned char *out;
        long got;

        PERL_UNUSED_VAR(class);
        Newx(out, n ? (n * 5) / 8 + 1 : 1, unsigned char);
        SAVEFREEPV(out);
        got = ptotp_b32_decode(out, p, n);
        if (got < 0)
            croak("not valid base32");
        RETVAL = newSVpvn((const char *)out, (STRLEN)got);
    }
  OUTPUT:
    RETVAL

INCLUDE: xs/plugin.xs
