#ifndef PPK_ABI_H
#define PPK_ABI_H

/* Resolvers for the two house C ABIs Punk::Passkey builds on: jws_abi
 * (Crypt::JWS - ECDSA and RSA verification, SHA-256, base64url, the
 * constant-time compare and the CSPRNG) and frj_abi (File::Raw::JSON -
 * clientDataJSON). Both are hard prereqs, so a failure to resolve is a
 * boot-environment error rather than something to degrade around.
 *
 * There is no third. The whole reason this dist is a week of work and
 * not a month is that WebAuthn's cryptography is signature
 * verification over a digest, and both already exist behind an ABI
 * this workspace ships. */

#include "jws_abi.h"
#include "frj_abi.h"

static const jws_abi *PPK_JWS = NULL;
static const frj_abi *PPK_FRJ = NULL;

static IV ppk_call_abi_ptr(pTHX_ const char *require_stmt, const char *fn) {
    dSP;
    int count;
    IV p = 0;
    eval_pv(require_stmt, FALSE);
    SPAGAIN;
    if (SvTRUE(ERRSV)) return 0;
    ENTER; SAVETMPS; PUSHMARK(SP); PUTBACK;
    count = call_pv(fn, G_SCALAR | G_EVAL);
    SPAGAIN;
    if (!SvTRUE(ERRSV) && count > 0) p = POPi;
    else if (count > 0)              (void)POPs;
    PUTBACK; FREETMPS; LEAVE;
    return p;
}

/* >= and not ==: the table is append-only, so a Crypt::JWS newer than
 * this header is always safe, and equality would turn every append
 * into a breaking change for a consumer already shipped. The number is
 * the version whose members this dist actually calls - verify,
 * sha256, b64url both ways, ct_eq, random_bytes, key_from_pem, all of
 * which are version 1 - and NOT the installed header's
 * JWS_ABI_VERSION, so building against a newer Crypt::JWS must not
 * raise this dist's runtime requirement. */
#define PPK_JWS_NEED 1

static const jws_abi *ppk_jws(pTHX) {
    if (!PPK_JWS) {
        IV p = ppk_call_abi_ptr(aTHX_ "require Crypt::JWS;",
                                "Crypt::JWS::_abi_ptr");
        const jws_abi *a = p ? INT2PTR(const jws_abi *, p) : NULL;
        if (a && a->version >= PPK_JWS_NEED) PPK_JWS = a;
    }
    if (!PPK_JWS)
        croak("Punk::Passkey: Crypt::JWS with a compatible C ABI is "
              "required (jws_abi version %d or newer)", PPK_JWS_NEED);
    return PPK_JWS;
}

static const frj_abi *ppk_frj(pTHX) {
    if (!PPK_FRJ) {
        IV p = ppk_call_abi_ptr(aTHX_ "require File::Raw::JSON;",
                                "File::Raw::JSON::_abi_ptr");
        const frj_abi *a = p ? INT2PTR(const frj_abi *, p) : NULL;
        if (a && a->abi_version >= FRJ_ABI_VERSION) PPK_FRJ = a;
    }
    if (!PPK_FRJ)
        croak("Punk::Passkey: File::Raw::JSON with a compatible C ABI is "
              "required (FRJ_ABI_VERSION %d)", FRJ_ABI_VERSION);
    return PPK_FRJ;
}

#endif /* PPK_ABI_H */
