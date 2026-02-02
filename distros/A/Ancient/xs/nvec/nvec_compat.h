/*
 * nvec_compat.h - Perl compatibility macros for nvec
 */

#ifndef NVEC_COMPAT_H
#define NVEC_COMPAT_H

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
#    ifdef USE_ITHREADS
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

/* op_append_elem - introduced in 5.14 */
#if !PERL_VERSION_GE(5,14,0)
#  define op_append_elem(type, first, last) Perl_append_elem(aTHX_ type, first, last)
#endif

/* Gv_AMupdate signature changed in 5.12 - added second argument */
#if !PERL_VERSION_GE(5,12,0)
#  define Gv_AMupdate_compat(stash, destructing) Gv_AMupdate(stash)
#else
#  define Gv_AMupdate_compat(stash, destructing) Gv_AMupdate(stash, destructing)
#endif

/* mg_findext - introduced in 5.14
 * Fallback: use mg_find with NULL vtbl check */
#if !PERL_VERSION_GE(5,14,0)
static MAGIC* nvec_compat_mg_findext(pTHX_ SV *sv, int type, const MGVTBL *vtbl) {
    MAGIC *mg;
    PERL_UNUSED_ARG(vtbl);
    for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
        if (mg->mg_type == type) {
            return mg;
        }
    }
    return NULL;
}
#  define mg_findext(sv, type, vtbl) nvec_compat_mg_findext(aTHX_ sv, type, vtbl)
#endif

/* pad_alloc - not exported until 5.14+ */
#if !PERL_VERSION_GE(5,14,0)
#  ifndef pad_alloc
#    define pad_alloc(optype, sv_type) 0
#  endif
#endif

/* op_convert_list - introduced in 5.22 */
#if !PERL_VERSION_GE(5,22,0)
#  ifndef op_convert_list
#    define op_convert_list(type, flags, op) Perl_convert(aTHX_ type, flags, op)
#  endif
#endif

#endif /* NVEC_COMPAT_H */
