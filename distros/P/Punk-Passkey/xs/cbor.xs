MODULE = Punk::Passkey    PACKAGE = Punk::Passkey

PROTOTYPES: DISABLE

# The phase-0 surface: the decoder and the two conversions, exposed to
# Perl only as far as the tests need them. Every name here is
# underscore-private and none is documented as an interface - the
# public surface is the ceremonies in phases 1 and 2, and a decoder
# that applications call directly is a decoder whose refusals become
# somebody's compatibility problem.
#
# All three return undef rather than dying on bad input, because bad
# input is the normal case for something reading the network, and set
# $Punk::Passkey::ERR to the reason. The reason is for the log; it is
# never for the client, who would be reading a list of which check to
# defeat next.

# _abi_info() - the two house ABIs this dist runs on, resolved and
# version-reported: (jws_abi version, frj_abi version).
#
# It exists so an environment problem is a sentence at install time
# rather than a puzzle in the middle of a login three phases from now:
# both tables are resolved lazily on first use, and without this the
# first use of frj would be in the authentication ceremony.
void
_abi_info()
    PPCODE:
    {
        const jws_abi *J = ppk_jws(aTHX);
        const frj_abi *F = ppk_frj(aTHX);
        EXTEND(SP, 2);
        PUSHs(sv_2mortal(newSViv(J->version)));
        PUSHs(sv_2mortal(newSViv(F->abi_version)));
    }

# _decode_cbor($bytes) - one complete item, nothing trailing.
SV *
_decode_cbor(bytes)
        SV *bytes
    CODE:
    {
        STRLEN len;
        const unsigned char *p;
        const char *why = NULL;
        SV *out;
        if (!SvOK(bytes)) XSRETURN_UNDEF;
        p = (const unsigned char *)SvPV_const(bytes, len);
        out = ppk_cbor_decode(aTHX_ p, len, &why);
        sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD),
                 why ? why : "");
        if (!out) XSRETURN_UNDEF;
        RETVAL = out;
    }
    OUTPUT:
        RETVAL

# _decode_cbor_prefix($bytes) - (item, bytes_consumed), for a document
# with something legitimate behind it (authData's extensions).
void
_decode_cbor_prefix(bytes)
        SV *bytes
    PPCODE:
    {
        STRLEN len, used = 0;
        const unsigned char *p;
        const char *why = NULL;
        SV *out;
        if (!SvOK(bytes)) XSRETURN_EMPTY;
        p = (const unsigned char *)SvPV_const(bytes, len);
        out = ppk_cbor_decode_prefix(aTHX_ p, len, &used, &why);
        sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD), why ? why : "");
        if (!out) XSRETURN_EMPTY;
        EXTEND(SP, 2);
        PUSHs(sv_2mortal(out));
        PUSHs(sv_2mortal(newSVuv((UV)used)));
    }

# _cose_to_pem($decoded) - a decoded COSE map as a PEM public key.
# Returns (pem, alg) so the caller knows which algorithm to verify
# with rather than trusting a second copy of it from elsewhere.
void
_cose_to_pem(decoded)
        SV *decoded
    PPCODE:
    {
        const char *why = NULL;
        IV alg = 0;
        SV *pem = ppk_cose_to_pem(aTHX_ decoded, &alg, &why);
        sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD), why ? why : "");
        if (!pem) XSRETURN_EMPTY;
        EXTEND(SP, 2);
        PUSHs(sv_2mortal(pem));
        PUSHs(sv_2mortal(newSViv(alg)));
    }

# _sig_der_to_raw($der) - an ECDSA signature as ES256 verify wants it.
SV *
_sig_der_to_raw(der)
        SV *der
    CODE:
    {
        STRLEN len;
        const unsigned char *p;
        const char *why = NULL;
        SV *out;
        if (!SvOK(der)) XSRETURN_UNDEF;
        p = (const unsigned char *)SvPV_const(der, len);
        out = ppk_sig_der_to_raw(aTHX_ p, len, &why);
        sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD), why ? why : "");
        if (!out) XSRETURN_UNDEF;
        RETVAL = out;
    }
    OUTPUT:
        RETVAL

# _verify($pem, $alg, $input, $sig) - the seam proof: import a key this
# dist encoded and verify with it through jws_abi. ES256 signatures
# arrive in DER from an authenticator and are converted here; RS256 is
# already the width JOSE wants and passes through.
SV *
_verify(pem, alg, input, sig)
        SV *pem
        IV  alg
        SV *input
        SV *sig
    CODE:
    {
        const jws_abi *J = ppk_jws(aTHX);
        STRLEN pl, il, sl;
        const char *pp = SvPV_const(pem, pl);
        const unsigned char *ip = (const unsigned char *)SvPV_const(input, il);
        const unsigned char *sp = (const unsigned char *)SvPV_const(sig, sl);
        const char *name = (alg == PPK_COSE_ALG_RS256) ? "RS256" : "ES256";
        SV *raw = NULL;
        void *key;
        int ok;

        if (alg == PPK_COSE_ALG_ES256) {
            const char *why = NULL;
            raw = ppk_sig_der_to_raw(aTHX_ sp, sl, &why);
            if (!raw) {
                sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD),
                         why ? why : "bad signature");
                XSRETURN_UNDEF;
            }
            sp = (const unsigned char *)SvPV_const(raw, sl);
        }
        key = J->key_from_pem(aTHX_ pp, pl);
        if (!key) {
            if (raw) SvREFCNT_dec(raw);
            sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD),
                     "the key did not import");
            XSRETURN_UNDEF;
        }
        ok = J->verify(aTHX_ key, name, strlen(name), ip, il, sp, sl);
        J->key_free(aTHX_ key);
        if (raw) SvREFCNT_dec(raw);
        sv_setpv(get_sv("Punk::Passkey::ERR", GV_ADD), ok ? "" : "bad signature");
        RETVAL = newSViv(ok ? 1 : 0);
    }
    OUTPUT:
        RETVAL
