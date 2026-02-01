/*
 * lru_compat.h - Perl compatibility macros for lru
 */

#ifndef LRU_COMPAT_H
#define LRU_COMPAT_H

/* Version checking macro */
#ifndef PERL_VERSION_GE
#  define PERL_VERSION_GE(r,v,s) \
      (PERL_REVISION > (r) || (PERL_REVISION == (r) && \
       (PERL_VERSION > (v) || (PERL_VERSION == (v) && PERL_SUBVERSION >= (s)))))
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

/* newSVpvn_flags */
#ifndef newSVpvn_flags
#  define newSVpvn_flags(s,len,flags) newSVpvn(s,len)
#endif

#endif /* LRU_COMPAT_H */
