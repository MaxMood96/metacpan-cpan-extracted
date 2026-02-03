/*
 * util_compat.h - Perl compatibility macros for util
 * Op sibling navigation (5.22+), refcount, and boot macros
 */

#ifndef UTIL_COMPAT_H
#define UTIL_COMPAT_H

/* Devel::PPPort compatibility - provides many backported macros */
#include "ppport.h"

/* Include shared XOP compatibility for custom ops (5.14+ fallback) */
#include "../xop_compat.h"

/* Version checking macro */
#ifndef PERL_VERSION_GE
#  define PERL_VERSION_GE(r,v,s) \
      (PERL_REVISION > (r) || (PERL_REVISION == (r) && \
       (PERL_VERSION > (v) || (PERL_VERSION == (v) && PERL_SUBVERSION >= (s)))))
#endif

/* Op sibling macros - introduced in 5.22 */
#ifndef OpHAS_SIBLING
#  define OpHAS_SIBLING(o)      ((o)->op_sibling != NULL)
#endif

#ifndef OpSIBLING
#  define OpSIBLING(o)          ((o)->op_sibling)
#endif

#ifndef OpMORESIB_set
#  define OpMORESIB_set(o, sib) ((o)->op_sibling = (sib))
#endif

#ifndef OpLASTSIB_set
#  define OpLASTSIB_set(o, parent) ((o)->op_sibling = NULL)
#endif

/* Refcount macros */
#ifndef SvREFCNT_inc_simple_NN
#  define SvREFCNT_inc_simple_NN(sv) SvREFCNT_inc(sv)
#endif

#ifndef SvREFCNT_dec_NN
#  define SvREFCNT_dec_NN(sv) SvREFCNT_dec(sv)
#endif

/* XS boot macros - introduced in 5.22 */
#ifndef dXSBOOTARGSXSAPIVERCHK
#  define dXSBOOTARGSXSAPIVERCHK dXSARGS
#endif

/* Perl_xs_boot_epilog - introduced in 5.21.6 (use 5.22 as safe boundary)
 * Use PERL_IMPLICIT_CONTEXT not USE_ITHREADS - that's what controls aTHX_ expansion */
#if !PERL_VERSION_GE(5,22,0)
#  ifndef Perl_xs_boot_epilog
#    ifdef PERL_IMPLICIT_CONTEXT
#      define Perl_xs_boot_epilog(ctx, ax) XSRETURN_YES
#    else
#      define Perl_xs_boot_epilog(ax) XSRETURN_YES
#    endif
#  endif
#endif

/* XS_EXTERNAL - introduced in 5.16 */
#ifndef XS_EXTERNAL
#  define XS_EXTERNAL(name) XS(name)
#endif

/* Utility macros */
#ifndef PERL_UNUSED_VAR
#  define PERL_UNUSED_VAR(x) ((void)(x))
#endif

#ifndef PERL_UNUSED_ARG
#  define PERL_UNUSED_ARG(x) ((void)(x))
#endif

/* DEFSV macros - DEFSV_set was added in 5.24.0 */
#ifndef DEFSV_set
#  define DEFSV_set(sv) (GvSV(PL_defgv) = (sv))
#endif

#ifndef SAVE_DEFSV
#  define SAVE_DEFSV SAVESPTR(GvSV(PL_defgv))
#endif

/* PL_sv_zero - introduced in 5.28 */
#if !PERL_VERSION_GE(5,28,0)
/* Pre-5.28: PL_sv_zero doesn't exist, use sv_2mortal(newSViv(0)) */
#  define PL_sv_zero (*util_compat_get_sv_zero(aTHX))
static SV* util_compat_get_sv_zero(pTHX) {
    static SV* sv_zero = NULL;
    if (!sv_zero) {
        sv_zero = newSViv(0);
        SvREADONLY_on(sv_zero);
    }
    return sv_zero;
}
#endif

/* GvCV_set - introduced in 5.22 */
#if !PERL_VERSION_GE(5,22,0)
#  ifndef GvCV_set
#    define GvCV_set(gv, cv) (GvCV(gv) = (cv))
#  endif
#endif

/* Perl_call_checker - introduced in 5.14 */
#if !PERL_VERSION_GE(5,14,0)
typedef OP * (*Perl_call_checker)(pTHX_ OP *, GV *, SV *);
#endif

/* pad_alloc - not exported until 5.15.1 (use 5.16 as safe boundary)
 * Fallback: return 0 (disables pad optimization) */
#if !PERL_VERSION_GE(5,16,0)
#  ifndef pad_alloc
#    define pad_alloc(optype, sv_type) 0
#  endif
#endif

/* op_convert_list - introduced in 5.22
 * Fallback: use Perl_convert which exists in older Perls */
#if !PERL_VERSION_GE(5,22,0)
#  ifndef op_convert_list
#    define op_convert_list(type, flags, op) Perl_convert(aTHX_ type, flags, op)
#  endif
#endif

#endif /* UTIL_COMPAT_H */
