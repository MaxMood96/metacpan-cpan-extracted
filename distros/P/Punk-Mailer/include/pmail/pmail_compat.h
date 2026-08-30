#ifndef PMAIL_COMPAT_H
#define PMAIL_COMPAT_H

/* pmail_compat.h - the system headers every other pmail header needs, and
 * the few portability guards. Nothing here is Perl-specific except the
 * 64-bit size type. */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>

/* XS_INTERNAL, XS_EXTERNAL and XSPROTO arrived in XSUB.h at 5.16. The
 * plugin's helpers (pmail_plugin.h) are declared XS_INTERNAL, and without
 * these the older compiler reads `XS_INTERNAL(pm_mw)` as a K&R function
 * definition NAMED XS_INTERNAL - so the diagnostic is `cv undeclared`
 * inside it and `pm_mw undeclared` at every call, which names neither the
 * macro nor the version. Same shim as Punk, Punk::OAuth2 and Hyperman. */
#ifndef XSPROTO
#  define XSPROTO(name) void name(pTHX_ CV *cv)
#endif
#ifndef XS_INTERNAL
#  define XS_INTERNAL(name) STATIC XSPROTO(name)
#endif
#ifndef XS_EXTERNAL
#  define XS_EXTERNAL(name) XSPROTO(name)
#endif

/* mg_findext is 5.14. pm_cap_of uses it to reach the magic carrying a
 * closure's captures, and an implicit declaration there is worse than a
 * missing one: it returns int, so the MAGIC* is truncated to 32 bits and
 * the helper reads a wild pointer on the platforms that got that far.
 * Same shim as Punk. */
#if PERL_REVISION == 5 && PERL_VERSION < 14

static MAGIC *pmail_mg_findext(SV *sv, int type, const MGVTBL *vtbl) {
    if (sv) {
        MAGIC *mg;
        for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic)
            if (mg->mg_type == type && (const MGVTBL *)mg->mg_virtual == vtbl)
                return mg;
    }
    return NULL;
}
#  define mg_findext(sv, type, vtbl) pmail_mg_findext((sv), (type), (vtbl))

#endif

/* Message and attachment sizes. Never IV: on the 32-bit smokers an IV is
 * 32 bits and a file can be larger than that. unsigned long long is C99
 * and every compiler on the matrix, including the FreeBSD 9 gcc 4.2, has
 * it. Printed through %llu with an explicit cast. */
typedef unsigned long long pmail_u64;

#define PMAIL_CRLF "\r\n"

/* 7bit text may not carry a line over 998 bytes (RFC 5322 2.1.1) */
#define PMAIL_MAX_LINE 998

/* a header line folds at this width when it can (RFC 5322 2.1.1) */
#define PMAIL_FOLD_AT 78

#endif /* PMAIL_COMPAT_H */
