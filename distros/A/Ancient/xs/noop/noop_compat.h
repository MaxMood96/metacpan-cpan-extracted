/*
 * noop_compat.h - Perl compatibility macros for noop
 * Boot macros and XS helpers (5.22+)
 */

#ifndef NOOP_COMPAT_H
#define NOOP_COMPAT_H

/* Devel::PPPort compatibility - provides many backported macros */
#include "ppport.h"

/* Include shared XOP compatibility for custom ops (5.14+ fallback) */
#include "../xop_compat.h"

/* Version checking */
#ifndef PERL_VERSION_DECIMAL
#  define PERL_VERSION_DECIMAL(r,v,s) ((r)*1000000 + (v)*1000 + (s))
#endif
#ifndef PERL_DECIMAL_VERSION
#  define PERL_DECIMAL_VERSION \
      PERL_VERSION_DECIMAL(PERL_REVISION, PERL_VERSION, PERL_SUBVERSION)
#endif
#ifndef PERL_VERSION_GE
#  define PERL_VERSION_GE(r,v,s) \
      (PERL_DECIMAL_VERSION >= PERL_VERSION_DECIMAL(r,v,s))
#endif

/* XS boot macros - 5.22+ */
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

/* XS_EXTERNAL - 5.16+ */
#ifndef XS_EXTERNAL
#  define XS_EXTERNAL(name) XS(name)
#endif

/* Unused arg/var macros */
#ifndef PERL_UNUSED_ARG
#  define PERL_UNUSED_ARG(x) ((void)(x))
#endif

#ifndef PERL_UNUSED_VAR
#  define PERL_UNUSED_VAR(x) ((void)(x))
#endif

#endif /* NOOP_COMPAT_H */
