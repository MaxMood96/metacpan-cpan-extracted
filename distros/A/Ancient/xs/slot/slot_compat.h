/*
 * slot_compat.h - Perl compatibility macros for slot
 * Op sibling navigation (5.22+), refcount macros, and boot macros
 */

#ifndef SLOT_COMPAT_H
#define SLOT_COMPAT_H

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

#if !PERL_VERSION_GE(5,22,0)
#  ifndef Perl_xs_boot_epilog
#    define Perl_xs_boot_epilog(aTHX_ ax) XSRETURN_YES
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

#endif /* SLOT_COMPAT_H */
