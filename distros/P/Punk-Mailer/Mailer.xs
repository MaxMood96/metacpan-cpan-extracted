#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* G_LIST is the 5.36 name for G_ARRAY */
#ifndef G_LIST
#define G_LIST G_ARRAY
#endif

/* Punk::Mailer - outbound mail. 100% XS: the .pm files are a version
 * number and the POD. Everything lives under include/pmail/, in the order
 * the pieces depend on each other; the XSUBs are in xs/ and INCLUDEd at
 * the end. */

#include "fetch_abi.h"
#include "frj_abi.h"
#include "st_abi.h"

/* The two C ABIs this dist calls through, resolved once at boot. Building
 * a message needs neither; the transports do - the HTTP ones go through
 * Fetch's request table and File::Raw::JSON's encoder, the SMTP one
 * through Fetch's tunnel (ABI 3 for STARTTLS) - and each croaks naming
 * the version it needs when the running provider is older. PM_FETCH_SEEN
 * is what the installed Fetch offered, 0 when none loaded, so that
 * message can say which. */
static const fetch_abi *PM_FETCH = NULL;
static IV PM_FETCH_SEEN = 0;
static const frj_abi *PM_FRJ = NULL;

#include "pmail/pmail_compat.h"
#include "pmail/pmail_rand.h"
#include "pmail/pmail_sink.h"
#include "pmail/pmail_b64.h"
#include "pmail/pmail_qp.h"
#include "pmail/pmail_hdr.h"
#include "pmail/pmail_mime.h"
#include "pmail/pmail_result.h"
#include "pmail/pmail_tx.h"
#include "pmail/pmail_tx_capture.h"
#include "pmail/pmail_tx_log.h"
#include "pmail/pmail_tx_sendmail.h"
#include "pmail/pmail_tx_http.h"
#include "pmail/pmail_tx_smtp.h"
#include "pmail/pmail_engine.h"
#include "pmail/pmail_plugin.h"

static IV pm_abi_ptr(pTHX_ const char *module, const char *sub)
{
    IV p = 0;
    dSP;
    ENTER; SAVETMPS;
    eval_pv(form("require %s;", module), FALSE);
    SPAGAIN;
    if (!SvTRUE(ERRSV)) {
        int count;
        PUSHMARK(SP); PUTBACK;
        count = call_pv(sub, G_SCALAR | G_EVAL);
        SPAGAIN;
        if (!SvTRUE(ERRSV) && count > 0) p = POPi;
        else if (count > 0) (void)POPs;
        PUTBACK;
    }
    FREETMPS; LEAVE;
    return p;
}

static void pm_boot(pTHX)
{
    IV p = pm_abi_ptr(aTHX_ "Fetch", "Fetch::_abi_ptr");
    if (p) {
        const fetch_abi *a = INT2PTR(const fetch_abi *, p);
        if (a) {
            PM_FETCH_SEEN = a->abi_version;
            if (a->abi_version >= 2) PM_FETCH = a;     /* >= : append-only */
        }
    }
    p = pm_abi_ptr(aTHX_ "File::Raw::JSON", "File::Raw::JSON::_abi_ptr");
    if (p) {
        const frj_abi *a = INT2PTR(const frj_abi *, p);
        if (a && a->abi_version >= FRJ_ABI_VERSION) PM_FRJ = a;
    }
}

MODULE = Punk::Mailer    PACKAGE = Punk::Mailer

PROTOTYPES: DISABLE

BOOT:
    pm_boot(aTHX);

# What the running Fetch's table reports, or 0 when Fetch did not load.
IV
_fetch_abi_version()
    CODE:
        RETVAL = PM_FETCH_SEEN;
    OUTPUT:
        RETVAL

INCLUDE: xs/build.xs
INCLUDE: xs/engine.xs
INCLUDE: xs/transport.xs
INCLUDE: xs/plugin.xs
