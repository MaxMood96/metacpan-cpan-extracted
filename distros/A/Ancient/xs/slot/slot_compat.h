/*
 * slot_compat.h - Perl compatibility macros for slot
 * Op sibling navigation (5.22+), refcount macros, and boot macros
 */

#ifndef SLOT_COMPAT_H
#define SLOT_COMPAT_H

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

/* PADNAME compatibility - PADNAME type introduced in 5.18, PadnameFLAGS in 5.21.7 */
#if !PERL_VERSION_GE(5,18,0)
/* Pre-5.18: PADNAME doesn't exist, pad names are SVs */
typedef SV PADNAME;
#  define PadnamelistMAX(pn) (AvFILLp(pn))
#  define PadnamelistARRAY(pn) ((PADNAME**)AvARRAY(pn))
#  define PadnameFLAGS(pn) (SvFLAGS(pn))
#  ifndef PADNAMEf_CONST
#    define PADNAMEf_CONST 0  /* Flag doesn't exist pre-5.18, always false */
#  endif
#elif !PERL_VERSION_GE(5,22,0)
/* 5.18-5.21: PADNAME exists but PadnameFLAGS may not be available/lvalue.
 * PadnameFLAGS was added in 5.21.7 but may have issues on some compilers.
 * Use SvFLAGS directly on the underlying SV for these versions. */
#  ifndef PadnameFLAGS
#    define PadnameFLAGS(pn) (SvFLAGS((SV*)(pn)))
#  endif
#  ifndef PADNAMEf_CONST
#    define PADNAMEf_CONST 0x40  /* May not be defined in all 5.18-5.21 versions */
#  endif
#endif

#endif /* SLOT_COMPAT_H */
