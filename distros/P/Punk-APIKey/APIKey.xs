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
pak_mg_findext(pTHX_ const SV *sv, int type, const MGVTBL *vtbl)
{
    MAGIC *mg;
    if (sv && SvTYPE(sv) >= SVt_PVMG)
        for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic)
            if (mg->mg_type == type && mg->mg_virtual == vtbl)
                return mg;
    return NULL;
}
#define mg_findext(sv, type, vtbl) pak_mg_findext(aTHX_ (sv), (type), (vtbl))
#endif

#include <time.h>

#include "pak/pak_clos.h"      /* closures, calls, and the small predicates */
#include "pak/pak_hash.h"      /* CRC32 and base62: the key's checksum      */
#include "pak/pak_reg.h"       /* boot-time devices: options, install, %INC */

/* The plugin in three parts, and in this order: the state and the writers,
 * then the per-request bodies, then `register` - which installs the bodies
 * and so has to come after them. */
#include "pak/pak_key.h"          /* the key format: mint, parse, digest     */
#include "pak/pak_apikey_reg.h"   /* state, issue, revoke, list, standing    */
#include "pak/pak_apikey.h"       /* the guard and the OpenAPI checker       */
#include "pak/pak_apikey_boot.h"  /* register                                */

MODULE = Punk::APIKey    PACKAGE = Punk::APIKey

PROTOTYPES: DISABLE

BOOT:
    /* nothing to resolve: this distribution reaches Punk through its
     * ordinary Perl surface, not through a C ABI table. pk_abi.h is here for
     * the context accessors in pak_clos.h and nothing else. */
    ;

INCLUDE: xs/apikey.xs
