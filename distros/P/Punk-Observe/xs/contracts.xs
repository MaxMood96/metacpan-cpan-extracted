MODULE = Punk::Observe   PACKAGE = Punk::Observe   PREFIX = po_

# The contract surface. Nothing here is a feature; it exists so that
# t/0001-contracts.t can assert from Perl the things phase 0 promised, on every
# perl in the smoker matrix rather than only on the one that built it.

# --- struct layout ----------------------------------------------------------

UV
po_rec_size(...)
    CODE:
        RETVAL = (UV)sizeof(po_rec);
    OUTPUT:
        RETVAL

UV
po_rec_declared_size(...)
    CODE:
        RETVAL = (UV)PO_REC_SIZE;
    OUTPUT:
        RETVAL

# Every member's offset, so a padding surprise on an unusual ABI is a failing
# test naming the member rather than a silently misread segment.
void
po_rec_offsets(...)
    PPCODE:
        {
            /* offsetof, not (char *)&((T *)0)->m - (char *)0. The hand-rolled
             * form is undefined behaviour on a null pointer and clang says so
             * under -Wnull-pointer-subtraction; stddef.h has had the correct
             * spelling since C89. */
#define OFF(name) \
    do { mXPUSHp(#name, sizeof(#name) - 1); \
         mXPUSHu((UV)offsetof(po_rec, name)); } while (0)
            OFF(t_unix_nano);  OFF(series);
            OFF(trace_id_hi);  OFF(trace_id_lo);
            OFF(span_id);      OFF(parent_span_id);
            OFF(dur_nano);     OFF(value);
            OFF(body_off);     OFF(body_len);
            OFF(attr_off);     OFF(attr_len);
            OFF(severity);     OFF(flags);
            OFF(kind);         OFF(aux);
#undef OFF
        }

# --- 64-bit fidelity --------------------------------------------------------

# Round-trip a value through po_rec's uint64_t field and back out through the
# documented Perl representation. On a 32-bit IV perl the return is a decimal
# string; the point of the test is that it is the SAME value either way.
SV *
po_u64_roundtrip(SV *in)
    CODE:
        {
            po_u64 v = 0;
            po_rec r;
            if (!po_sv_to_u64(aTHX_ in, &v))
                croak("not a non-negative integer");
            po_rec_zero(&r);
            r.t_unix_nano = v;              /* through the real field */
            RETVAL = po_u64_to_sv(r.t_unix_nano);
        }
    OUTPUT:
        RETVAL

# Does this perl need the string path? The test asserts that it is actually
# taken where IVSIZE < 8, rather than assuming the branch is reachable.
UV
po_uvsize(...)
    CODE:
        RETVAL = (UV)UVSIZE;
    OUTPUT:
        RETVAL

# The decimal formatter, called directly.
#
# On a 64-bit UV perl the string branch is never TAKEN - every po_u64 fits a
# UV - so po_u64_string_sv would ship untested everywhere except the 32-bit
# smokers, which is the wrong way round: it would be exercised for the first
# time on the platform least able to report why it broke. A branch that is
# never exercised is a branch that is wrong.
SV *
po_u64_to_string(SV *in)
    CODE:
        {
            po_u64 v = 0;
            if (!po_sv_to_u64(aTHX_ in, &v)) croak("not an integer");
            RETVAL = po_u64_string_sv(aTHX_ v);
        }
    OUTPUT:
        RETVAL

int
po_u64_is_string(SV *in)
    CODE:
        {
            po_u64 v = 0;
            SV *out;
            if (!po_sv_to_u64(aTHX_ in, &v)) croak("not an integer");
            out = po_u64_to_sv(v);
            RETVAL = SvPOK(out) && !SvIOK(out) ? 1 : 0;
            SvREFCNT_dec(out);
        }
    OUTPUT:
        RETVAL

# --- the clock seam ---------------------------------------------------------

void
po_clock_freeze(SV *at)
    CODE:
        {
            po_u64 v = 0;
            if (!po_sv_to_u64(aTHX_ at, &v)) croak("not an integer");
            po_clock_freeze(v);
        }

void
po_clock_step(SV *by)
    CODE:
        {
            po_u64 v = 0;
            if (!po_sv_to_u64(aTHX_ by, &v)) croak("not an integer");
            po_clock_step(v);
        }

void
po_clock_real(...)
    CODE:
        po_clock_real();

SV *
po_now_ns(...)
    CODE:
        RETVAL = po_u64_to_sv(po_now_ns());
    OUTPUT:
        RETVAL

int
po_have_monotonic(...)
    CODE:
        RETVAL = po_have_monotonic();
    OUTPUT:
        RETVAL

SV *
po_block_start(SV *t)
    CODE:
        {
            po_u64 v = 0;
            if (!po_sv_to_u64(aTHX_ t, &v)) croak("not an integer");
            RETVAL = po_u64_to_sv(po_block_start(v));
        }
    OUTPUT:
        RETVAL

# A clock that stepped backwards gives end < start. In a uint64_t that is not
# a small negative number, it is about 1.8e19, so it clamps and is counted.
SV *
po_duration(SV *start, SV *end)
    CODE:
        {
            po_u64 a = 0, b = 0;
            if (!po_sv_to_u64(aTHX_ start, &a) || !po_sv_to_u64(aTHX_ end, &b))
                croak("not an integer");
            RETVAL = po_u64_to_sv(po_duration(a, b));
        }
    OUTPUT:
        RETVAL

# --- the tenant boundary ----------------------------------------------------

int
po_tenant_ok(SV *id)
    CODE:
        {
            STRLEN len;
            const char *p;
            if (!SvOK(id)) { RETVAL = 0; }
            else {
                p = SvPV(id, len);       /* on its own line, deliberately:  */
                RETVAL = po_tenant_ok(p, len);   /* f(SvPV(sv,n), n) is UB  */
            }
        }
    OUTPUT:
        RETVAL

# Returns the constructed root, or undef if the id was refused. The test
# asserts on the STRING, not on the filesystem: a path for tenant A must not
# resolve inside tenant B whether or not either directory exists.
SV *
po_store_root(SV *data, SV *tenant)
    CODE:
        {
            po_store s;
            STRLEN dlen, tlen = 0;
            const char *d, *t = NULL;
            d = SvPV(data, dlen);
            if (SvOK(tenant)) t = SvPV(tenant, tlen);
            if (!po_store_init(&s, d, t, tlen)) RETVAL = &PL_sv_undef;
            else RETVAL = newSVpv(s.root, 0);
        }
    OUTPUT:
        RETVAL

SV *
po_store_join(SV *data, SV *tenant, SV *rel)
    CODE:
        {
            po_store s;
            char out[PO_PATH_MAX];
            STRLEN dlen, tlen = 0, rlen;
            const char *d, *t = NULL, *r;
            size_t n;
            d = SvPV(data, dlen);
            if (SvOK(tenant)) t = SvPV(tenant, tlen);
            r = SvPV(rel, rlen);
            if (!po_store_init(&s, d, t, tlen)) RETVAL = &PL_sv_undef;
            else if (!(n = po_store_path(&s, r, out, sizeof(out))))
                RETVAL = &PL_sv_undef;
            else RETVAL = newSVpvn(out, n);
        }
    OUTPUT:
        RETVAL

# --- the arena --------------------------------------------------------------

# Round-trip bytes through the arena, so that the offset discipline po_rec
# depends on is exercised rather than assumed.
SV *
po_arena_roundtrip(SV *in)
    CODE:
        {
            po_arena a;
            STRLEN len;
            const char *p;
            uint32_t off;
            p = SvPV(in, len);
            if (!po_arena_init(&a, 16)) croak("arena");
            off = po_arena_put(&a, p, (size_t)len);
            if (off == PO_ARENA_ERR) { po_arena_free(&a); croak("arena full"); }
            RETVAL = newSVpvn(a.base + off, len);
            po_arena_free(&a);
        }
    OUTPUT:
        RETVAL

# --- build facts ------------------------------------------------------------

void
po_build_info(...)
    PPCODE:
        {
#define FACT(k, v) \
    do { mXPUSHp(k, sizeof(k) - 1); mXPUSHi(v); } while (0)
#ifdef PO_HAVE_CLOCK_GETTIME
            FACT("clock_gettime", 1);
#else
            FACT("clock_gettime", 0);
#endif
#ifdef PO_HAVE_CLOCK_MONOTONIC
            FACT("clock_monotonic", 1);
#else
            FACT("clock_monotonic", 0);
#endif
#ifdef PO_HAVE_ATOMICS
            FACT("atomics", 1);
#else
            FACT("atomics", 0);
#endif
#ifdef PO_BIG_ENDIAN
            FACT("big_endian", 1);
#else
            FACT("big_endian", 0);
#endif
#undef FACT
        }
