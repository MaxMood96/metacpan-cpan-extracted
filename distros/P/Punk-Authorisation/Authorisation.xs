#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* G_LIST is the 5.36 name for G_ARRAY */
#ifndef G_LIST
#define G_LIST G_ARRAY
#endif

/* XS_INTERNAL is 5.16+ and mg_findext 5.14+; the floor is 5.10 */
#ifndef XS_INTERNAL
#define XS_INTERNAL(name) static void name(pTHX_ CV *cv)
#endif
#ifndef mg_findext
static MAGIC *
pau_mg_findext(pTHX_ const SV *sv, int type, const MGVTBL *vtbl)
{
    MAGIC *mg;
    if (sv && SvTYPE(sv) >= SVt_PVMG)
        for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic)
            if (mg->mg_type == type && mg->mg_virtual == vtbl)
                return mg;
    return NULL;
}
#define mg_findext(sv, type, vtbl) pau_mg_findext(aTHX_ (sv), (type), (vtbl))
#endif

#include <time.h>

#include "pau/pau_clos.h"      /* closures, calls, and the small predicates */
#include "pau/pau_reg.h"       /* boot-time devices: options, install, %INC */

/* The plugin in two parts, and in this order: the rule registry and the
 * per-request bodies, then `register` - which installs the bodies and so has
 * to come after them. */
#include "pau/pau_authz.h"       /* rules, may, deny, rank, the grants half */
#include "pau/pau_authz_boot.h"  /* register                                */

MODULE = Punk::Authorisation    PACKAGE = Punk::Authorisation

PROTOTYPES: DISABLE

BOOT:
    /* nothing to resolve: this distribution reaches Punk through its
     * ordinary Perl surface, not through a C ABI table. See the note in
     * Makefile.PL about what pk_abi.h is and is not. */
    ;

INCLUDE: xs/authz.xs
