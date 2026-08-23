#ifndef POX_COMPAT_H
#define POX_COMPAT_H

/* Perl-version portability shims, so the dist builds on every perl it
 * claims (5.10.0+). Include after EXTERN.h / perl.h / XSUB.h / ppport.h
 * and before any pox/ header, so the definitions are in scope everywhere
 * below. Each shim is the standard definition of the thing it stands in
 * for; on a perl new enough to have the real one, none of it is compiled.
 * ppport.h already covers av_count, mPUSHs and newSVpvn_flags. */

/* XS_INTERNAL / XS_EXTERNAL (and XSPROTO) arrived in XSUB.h at 5.16. The
 * checker's C closures (pox_checker.h) are declared XS_INTERNAL. */
#ifndef XSPROTO
#  define XSPROTO(name) void name(pTHX_ CV *cv)
#endif
#ifndef XS_INTERNAL
#  define XS_INTERNAL(name) STATIC XSPROTO(name)
#endif
#ifndef XS_EXTERNAL
#  define XS_EXTERNAL(name) XSPROTO(name)
#endif

/* A true value for a set-membership slot that the container will own.
 *
 * &PL_sv_yes must never be stored bare: hv_store takes over a reference,
 * and the matching decrement when the hash is freed lands on an immortal
 * that nobody incremented. From perl 5.20 the immortals shrug that off;
 * before it the refcount really walks down and the process dies the next
 * time anything touches yes/no/undef. Taking the reference first costs
 * nothing - same singleton, no allocation - and keeps the books straight
 * on every perl. See t/46-immortal-refcount.t. */
#define POX_SET_TRUE SvREFCNT_inc_simple_NN(&PL_sv_yes)

/* Is this one of the immortals? A value that came back from Perl may be
 * &PL_sv_undef itself (a method that returned undef, or nothing). Such a
 * value is borrowed, never owned: do not mortalise it, and do not hand it
 * to anything that will release a reference to it. */
#define POX_IMMORTAL(sv) \
  ((SV *)(sv) == &PL_sv_undef || (SV *)(sv) == &PL_sv_yes \
   || (SV *)(sv) == &PL_sv_no)

#endif /* POX_COMPAT_H */
