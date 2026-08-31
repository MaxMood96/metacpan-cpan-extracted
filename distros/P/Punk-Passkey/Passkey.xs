#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* G_LIST is the 5.36 name for G_ARRAY; the floor is 5.10 */
#ifndef G_LIST
#define G_LIST G_ARRAY
#endif

#include <string.h>

#include "ppk/ppk_abi.h"
#include "ppk/ppk_cbor.h"
#include "ppk/ppk_ctx.h"
#include "ppk/ppk_cose.h"
#include "ppk/ppk_sig.h"
#include "ppk/ppk_reg.h"
#include "ppk/ppk_auth.h"
#include "ppk/ppk_plugin.h"

MODULE = Punk::Passkey        PACKAGE = Punk::Passkey

PROTOTYPES: DISABLE

INCLUDE: xs/cbor.xs
INCLUDE: xs/register.xs
INCLUDE: xs/authenticate.xs
INCLUDE: xs/plugin.xs
