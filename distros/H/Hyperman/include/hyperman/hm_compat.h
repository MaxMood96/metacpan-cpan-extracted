#ifndef HM_COMPAT_H
#define HM_COMPAT_H

/* Hyperman - perl API compatibility shims.
 *
 * The C core is written against a modern perl API but the distribution
 * supports older toolchains. This header backfills the handful of macros
 * and functions the core relies on that only appeared in later perls, so
 * hm_core.h / hm_future.h / hm_http2.h / hm_tls.h compile unchanged.
 *
 * Must be included after EXTERN.h / perl.h / XSUB.h (it needs the perl
 * headers for XS, MAGIC, SvMAGIC, ERRSV, croak, etc.).
 *
 * Coverage (declared floor is perl 5.10):
 *   XS_INTERNAL / XS_EXTERNAL  - added 5.15.4 (5.16)
 *   mg_findext                 - added 5.13.7 (5.14)
 *   croak_sv                   - added 5.13.1
 * On 5.10-5.15 one or more of these is absent; everything the core needs
 * beyond them (sv_magicext, hv_fetchs, ...) exists from 5.10 onward. */

/* XSUB entry points. Before the internal/external split every XSUB used
 * XS(name), which already supplies the pTHX_/CV* cv signature; fall back
 * to it so the "cv" the callbacks reference stays in scope. */
#ifndef XS_INTERNAL
#  define XS_INTERNAL(name) XS(name)
#endif
#ifndef XS_EXTERNAL
#  define XS_EXTERNAL(name) XS(name)
#endif

/* mg_findext: find the ext-magic slot on an SV matching a given vtbl.
 * Trivially reconstructed from the magic chain on perls that lack it. */
#ifndef mg_findext
static MAGIC *
hm_mg_findext(const SV *sv, int type, const MGVTBL *vtbl)
{
    if (sv) {
        const MAGIC *mg;
        for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
            if (mg->mg_type == type && mg->mg_virtual == vtbl)
                return (MAGIC *)mg;
        }
    }
    return NULL;
}
#  define mg_findext(sv, type, vtbl) hm_mg_findext((sv), (type), (vtbl))
#endif

/* croak_sv: throw an SV as the exception, preserving objects/refs (a
 * failed Future can carry a blessed error).
 *
 * A reference goes through $@ and croak(NULL), which raises the current
 * ERRSV - the only spelling that keeps a blessed exception blessed.
 *
 * A plain string must NOT take that route. croak_sv appends
 * " at FILE line N.\n" to a message that does not already end in a
 * newline; on every perl old enough to need this shim croak(NULL)
 * raises ERRSV verbatim instead, so a string failure came out stripped
 * of its location (0.41 FAILed t/38 on 5.10.1 and 5.12.5 with a bare
 * 'Oopsie'). Modern perls route croak(NULL) through mess_sv and DO
 * append, which is why no current perl can reproduce it. Hand the
 * string to croak as an argument and croak does the appending itself,
 * on every perl.
 *
 * hm_croak_sv is compiled EVERYWHERE, not only where croak_sv is
 * missing, so that Hyperman->_croak_sv_selftest can drive it on a
 * modern perl and t/38 can hold it to the same assertions it holds the
 * native croak_sv to. A shim that only exists on the perls you cannot
 * run is a shim nobody ever tests - which is how the bug above shipped. */

/* 5.10.0 only: croak() leaves ERRSV's UTF8 flag alone, so carry it over. */
#if PERL_REVISION == 5 && PERL_VERSION == 10 && PERL_SUBVERSION == 0
#  define HM_ERRSV_UTF8_FROM(sv) STMT_START {                   \
        SV *e_ = ERRSV;                                         \
        SvFLAGS(e_) = (SvFLAGS(e_) & ~SVf_UTF8)                 \
                    | (SvFLAGS(sv) & SVf_UTF8);                 \
    } STMT_END
#else
#  define HM_ERRSV_UTF8_FROM(sv) STMT_START { } STMT_END
#endif
static void
hm_croak_sv(pTHX_ SV *sv)
{
    if (SvROK(sv)) {
        sv_setsv(ERRSV, sv);
        croak(NULL);
    }
    HM_ERRSV_UTF8_FROM(sv);
    croak("%" SVf, SVfARG(sv));
}
#ifndef croak_sv
#  define croak_sv(sv) hm_croak_sv(aTHX_ (sv))
#endif

#endif /* HM_COMPAT_H */
