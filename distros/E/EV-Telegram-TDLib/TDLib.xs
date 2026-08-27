#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "EVAPI.h"
#include <td/telegram/td_json_client.h>

#include "tdpump.h"

MODULE = EV::Telegram::TDLib   PACKAGE = EV::Telegram::TDLib

PROTOTYPES: DISABLE

BOOT:
    I_EV_API ("EV::Telegram::TDLib");
    td_pump_boot(aTHX);

SV *
_execute(request)
    SV *request
  PREINIT:
    const char *res;
    STRLEN len;
    const char *req;
  CODE:
    /* JSON crosses as UTF-8 octets in both directions: SvPVutf8 would
       double-encode the ->utf8 encoder's output, and the decoder expects
       unflagged octets back, so no SvUTF8_on either. */
    TD_CHECK_FORK();
    req = SvPVbyte(request, len);
    res = td_execute(req);
    RETVAL = res ? newSVpv(res, 0) : &PL_sv_undef;
  OUTPUT:
    RETVAL

int
_create_client_id()
  CODE:
    TD_CHECK_FORK();
    td_pump_start(aTHX);
    RETVAL = td_create_client_id();
  OUTPUT:
    RETVAL

void
_send(client_id, request)
    int client_id
    SV *request
  PREINIT:
    STRLEN len;
  CODE:
    TD_CHECK_FORK();
    td_send(client_id, SvPVbyte(request, len));

void
_set_dispatch(cb)
    SV *cb
  PREINIT:
    SV *old;
  CODE:
    TD_CHECK_FORK();
    /* swap first: a dying newSVsv leaves the old dispatch in place, and a
       DESTROY re-entering _set_dispatch from the dec sees the new value */
    old = PUMP.dispatch;
    PUMP.dispatch = newSVsv(cb);
    if (old) SvREFCNT_dec(old);

void
_shutdown()
  CODE:
    TD_CHECK_FORK();
    td_pump_stop(aTHX);

void
_pump_ref()
  CODE:
    TD_CHECK_FORK();
    if (PUMP.refcnt++ == 0)
        ev_ref(EV_DEFAULT_UC);

void
_pump_unref()
  CODE:
    TD_CHECK_FORK();
    if (PUMP.refcnt > 0 && --PUMP.refcnt == 0)
        ev_unref(EV_DEFAULT_UC);

# test hook: keepalive accounting is otherwise invisible from Perl
int
_pump_refcnt()
  CODE:
    TD_CHECK_FORK();
    RETVAL = PUMP.refcnt;
  OUTPUT:
    RETVAL
