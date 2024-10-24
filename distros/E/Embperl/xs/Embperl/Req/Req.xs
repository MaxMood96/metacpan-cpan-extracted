
/*
 * *********** WARNING **************
 * This file generated by Embperl::WrapXS/2.0.0
 * Any changes made here will be lost
 * ***********************************
 * 1. /usr/share/perl5/ExtUtils/XSBuilder/WrapXS.pm:52
 * 2. /usr/share/perl5/ExtUtils/XSBuilder/WrapXS.pm:2070
 * 3. xsbuilder/xs_generate.pl:6
 */


#include "ep.h"

#include "epmacro.h"

#include "epdat2.h"

#include "eppublic.h"

#include "eptypes.h"

#include "EXTERN.h"

#include "perl.h"

#include "XSUB.h"

#include "ep_xs_sv_convert.h"

#include "ep_xs_typedefs.h"



void Embperl__Req_destroy (pTHX_ Embperl__Req  obj) {
            if (obj -> pApacheReqSV)
                SvREFCNT_dec(obj -> pApacheReqSV);
            if (obj -> pErrArray)
                SvREFCNT_dec(obj -> pErrArray);
            if (obj -> pErrSV)
                SvREFCNT_dec(obj -> pErrSV);
            if (obj -> pCleanupAV)
                SvREFCNT_dec(obj -> pCleanupAV);
            if (obj -> pCleanupPackagesHV)
                SvREFCNT_dec(obj -> pCleanupPackagesHV);
            if (obj -> pMessages)
                SvREFCNT_dec(obj -> pMessages);
            if (obj -> pDefaultMessages)
                SvREFCNT_dec(obj -> pDefaultMessages);

};



void Embperl__Req_new_init (pTHX_ Embperl__Req  obj, SV * item, int overwrite) {

    SV * * tmpsv ;

    if (SvTYPE(item) == SVt_PVMG) 
        memcpy (obj, (void *)SvIVX(item), sizeof (*obj)) ;
    else if (SvTYPE(item) == SVt_PVHV) {
        if ((tmpsv = hv_fetch((HV *)item, "apache_req", sizeof("apache_req") - 1, 0)) || overwrite) {
            SV * tmpobj = ((SV *)epxs_sv2_SVPTR((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> pApacheReqSV = (SV *)SvREFCNT_inc(tmpobj);
            else
                obj -> pApacheReqSV = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "app", sizeof("app") - 1, 0)) || overwrite) {
            obj -> pApp = (tApp *)epxs_sv2_Embperl__App((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "thread", sizeof("thread") - 1, 0)) || overwrite) {
            obj -> pThread = (tThreadData *)epxs_sv2_Embperl__Thread((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "request_count", sizeof("request_count") - 1, 0)) || overwrite) {
            obj -> nRequestCount = (int)epxs_sv2_IV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "request_time", sizeof("request_time") - 1, 0)) || overwrite) {
            obj -> nRequestTime = (time_t)epxs_sv2_NV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "iotype", sizeof("iotype") - 1, 0)) || overwrite) {
            obj -> nIOType = (int)epxs_sv2_IV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "session_mgnt", sizeof("session_mgnt") - 1, 0)) || overwrite) {
            obj -> nSessionMgnt = (int)epxs_sv2_IV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "session_id", sizeof("session_id") - 1, 0)) || overwrite) {
            char * tmpobj = ((char *)epxs_sv2_PV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> sSessionID = (char *)ep_pstrdup(obj->pPool,tmpobj);
            else
                obj -> sSessionID = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "session_user_id", sizeof("session_user_id") - 1, 0)) || overwrite) {
            char * tmpobj = ((char *)epxs_sv2_PV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> sSessionUserID = (char *)ep_pstrdup(obj->pPool,tmpobj);
            else
                obj -> sSessionUserID = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "session_state_id", sizeof("session_state_id") - 1, 0)) || overwrite) {
            char * tmpobj = ((char *)epxs_sv2_PV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> sSessionStateID = (char *)ep_pstrdup(obj->pPool,tmpobj);
            else
                obj -> sSessionStateID = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "cookie_expires", sizeof("cookie_expires") - 1, 0)) || overwrite) {
            char * tmpobj = ((char *)epxs_sv2_PV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> sCookieExpires = (char *)ep_pstrdup(obj->pPool,tmpobj);
            else
                obj -> sCookieExpires = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "had_exit", sizeof("had_exit") - 1, 0)) || overwrite) {
            obj -> bExit = (int)epxs_sv2_IV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "log_file_start_pos", sizeof("log_file_start_pos") - 1, 0)) || overwrite) {
            obj -> nLogFileStartPos = (long)epxs_sv2_IV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "error", sizeof("error") - 1, 0)) || overwrite) {
            obj -> bError = (int)epxs_sv2_IV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "errors", sizeof("errors") - 1, 0)) || overwrite) {
            AV * tmpobj = ((AV *)epxs_sv2_AVREF((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> pErrArray = (AV *)SvREFCNT_inc(tmpobj);
            else
                obj -> pErrArray = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "errdat1", sizeof("errdat1") - 1, 0)) || overwrite) {
            STRLEN l = 0;
            if (tmpsv) {
                char * s = SvPV(*tmpsv,l) ;
                if (l > (ERRDATLEN)-1) l = (ERRDATLEN) - 1 ;
                strncpy(obj->errdat1, s, l) ;
            }
            obj->errdat1[l] = '\0';
        }
        if ((tmpsv = hv_fetch((HV *)item, "errdat2", sizeof("errdat2") - 1, 0)) || overwrite) {
            STRLEN l = 0;
            if (tmpsv) {
                char * s = SvPV(*tmpsv,l) ;
                if (l > (ERRDATLEN)-1) l = (ERRDATLEN) - 1 ;
                strncpy(obj->errdat2, s, l) ;
            }
            obj->errdat2[l] = '\0';
        }
        if ((tmpsv = hv_fetch((HV *)item, "lastwarn", sizeof("lastwarn") - 1, 0)) || overwrite) {
            STRLEN l = 0;
            if (tmpsv) {
                char * s = SvPV(*tmpsv,l) ;
                if (l > (ERRDATLEN)-1) l = (ERRDATLEN) - 1 ;
                strncpy(obj->lastwarn, s, l) ;
            }
            obj->lastwarn[l] = '\0';
        }
        if ((tmpsv = hv_fetch((HV *)item, "errobj", sizeof("errobj") - 1, 0)) || overwrite) {
            SV * tmpobj = ((SV *)epxs_sv2_SVPTR((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> pErrSV = (SV *)SvREFCNT_inc(tmpobj);
            else
                obj -> pErrSV = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "cleanup_vars", sizeof("cleanup_vars") - 1, 0)) || overwrite) {
            AV * tmpobj = ((AV *)epxs_sv2_AVREF((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> pCleanupAV = (AV *)SvREFCNT_inc(tmpobj);
            else
                obj -> pCleanupAV = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "cleanup_packages", sizeof("cleanup_packages") - 1, 0)) || overwrite) {
            HV * tmpobj = ((HV *)epxs_sv2_HVREF((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> pCleanupPackagesHV = (HV *)SvREFCNT_inc(tmpobj);
            else
                obj -> pCleanupPackagesHV = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "initial_cwd", sizeof("initial_cwd") - 1, 0)) || overwrite) {
            char * tmpobj = ((char *)epxs_sv2_PV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> sInitialCWD = (char *)ep_pstrdup(obj->pPool,tmpobj);
            else
                obj -> sInitialCWD = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "messages", sizeof("messages") - 1, 0)) || overwrite) {
            AV * tmpobj = ((AV *)epxs_sv2_AVREF((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> pMessages = (AV *)SvREFCNT_inc(tmpobj);
            else
                obj -> pMessages = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "default_messages", sizeof("default_messages") - 1, 0)) || overwrite) {
            AV * tmpobj = ((AV *)epxs_sv2_AVREF((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)));
            if (tmpobj)
                obj -> pDefaultMessages = (AV *)SvREFCNT_inc(tmpobj);
            else
                obj -> pDefaultMessages = NULL ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "startclock", sizeof("startclock") - 1, 0)) || overwrite) {
            obj -> startclock = (clock_t)epxs_sv2_IV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
        if ((tmpsv = hv_fetch((HV *)item, "stsv_count", sizeof("stsv_count") - 1, 0)) || overwrite) {
            obj -> stsv_count = (I32)epxs_sv2_IV((tmpsv && *tmpsv?*tmpsv:&PL_sv_undef)) ;
        }
   ; }

    else
        croak ("initializer for Embperl::Req::new is not a hash or object reference") ;

} ;


MODULE = Embperl::Req    PACKAGE = Embperl::Req   PREFIX = embperl_

int
embperl_cleanup(r)
    Embperl::Req r
CODE:
    RETVAL = embperl_CleanupRequest(r);
OUTPUT:
    RETVAL


MODULE = Embperl::Req    PACKAGE = Embperl::Req   PREFIX = embperl_

int
embperl_execute_component(r, pPerlParam)
    Embperl::Req r
    SV * pPerlParam
CODE:
    RETVAL = embperl_ExecuteComponent(r, pPerlParam);
OUTPUT:
    RETVAL


MODULE = Embperl::Req    PACKAGE = Embperl::Req   PREFIX = embperl_

const char *
embperl_gettext(r, sMsgId)
    Embperl::Req r
    const char * sMsgId
CODE:
    RETVAL = embperl_GetText(r, sMsgId);
OUTPUT:
    RETVAL


MODULE = Embperl::Req    PACKAGE = Embperl::Req   PREFIX = embperl_

int
embperl_run(r)
    Embperl::Req r
CODE:
    RETVAL = embperl_RunRequest(r);
OUTPUT:
    RETVAL


MODULE = Embperl::Req    PACKAGE = Embperl::Req   PREFIX = embperl_

int
embperl_setup_component(r, pPerlParam)
    Embperl::Req r
    SV * pPerlParam
PREINIT:
    tComponent * ppComponent;
PPCODE:
    RETVAL = embperl_SetupComponent(r, pPerlParam, &ppComponent);
    XSprePUSH;
    EXTEND(SP, 2) ;
    PUSHs(epxs_IV_2obj(RETVAL)) ;
    PUSHs(epxs_Embperl__Component_2obj(ppComponent)) ;

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

SV *
apache_req(obj, val=NULL)
    Embperl::Req obj
    SV * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (SV *)  obj->pApacheReqSV;

    if (items > 1) {
        obj->pApacheReqSV = (SV *)SvREFCNT_inc(val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

Embperl::Req::Config
config(obj, val=NULL)
    Embperl::Req obj
    Embperl::Req::Config val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (Embperl__Req__Config) & obj->Config;
    if (items > 1) {
         croak ("Config is read only") ;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

Embperl::Req::Param
param(obj, val=NULL)
    Embperl::Req obj
    Embperl::Req::Param val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (Embperl__Req__Param) & obj->Param;
    if (items > 1) {
         croak ("Param is read only") ;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

Embperl::Component
component(obj, val=NULL)
    Embperl::Req obj
    Embperl::Component val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (Embperl__Component) & obj->Component;
    if (items > 1) {
         croak ("Component is read only") ;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

Embperl::App
app(obj, val=NULL)
    Embperl::Req obj
    Embperl::App val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (Embperl__App)  obj->pApp;

    if (items > 1) {
        obj->pApp = (Embperl__App) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

Embperl::Thread
thread(obj, val=NULL)
    Embperl::Req obj
    Embperl::Thread val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (Embperl__Thread)  obj->pThread;

    if (items > 1) {
        obj->pThread = (Embperl__Thread) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

int
request_count(obj, val=0)
    Embperl::Req obj
    int val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (int)  obj->nRequestCount;

    if (items > 1) {
        obj->nRequestCount = (int) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

time_t
request_time(obj, val=0)
    Embperl::Req obj
    time_t val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (time_t)  obj->nRequestTime;

    if (items > 1) {
        obj->nRequestTime = (time_t) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

int
iotype(obj, val=0)
    Embperl::Req obj
    int val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (int)  obj->nIOType;

    if (items > 1) {
        obj->nIOType = (int) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

int
session_mgnt(obj, val=0)
    Embperl::Req obj
    int val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (int)  obj->nSessionMgnt;

    if (items > 1) {
        obj->nSessionMgnt = (int) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

char *
session_id(obj, val=NULL)
    Embperl::Req obj
    char * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (char *)  obj->sSessionID;

    if (items > 1) {
        obj->sSessionID = (char *)ep_pstrdup(obj->pPool,val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

char *
session_user_id(obj, val=NULL)
    Embperl::Req obj
    char * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (char *)  obj->sSessionUserID;

    if (items > 1) {
        obj->sSessionUserID = (char *)ep_pstrdup(obj->pPool,val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

char *
session_state_id(obj, val=NULL)
    Embperl::Req obj
    char * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (char *)  obj->sSessionStateID;

    if (items > 1) {
        obj->sSessionStateID = (char *)ep_pstrdup(obj->pPool,val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

char *
cookie_expires(obj, val=NULL)
    Embperl::Req obj
    char * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (char *)  obj->sCookieExpires;

    if (items > 1) {
        obj->sCookieExpires = (char *)ep_pstrdup(obj->pPool,val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

int
had_exit(obj, val=0)
    Embperl::Req obj
    int val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (int)  obj->bExit;

    if (items > 1) {
        obj->bExit = (int) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

long
log_file_start_pos(obj, val=0)
    Embperl::Req obj
    long val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (long)  obj->nLogFileStartPos;

    if (items > 1) {
        obj->nLogFileStartPos = (long) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

int
error(obj, val=0)
    Embperl::Req obj
    int val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (int)  obj->bError;

    if (items > 1) {
        obj->bError = (int) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

AV *
errors(obj, val=NULL)
    Embperl::Req obj
    AV * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (AV *)  obj->pErrArray;

    if (items > 1) {
        obj->pErrArray = (AV *)SvREFCNT_inc(val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

char *
errdat1(obj, val=0)
    Embperl::Req obj
    char * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (char *)  obj->errdat1;

    if (items > 1) {
        strncpy(obj->errdat1, (char *) val, (ERRDATLEN) - 1) ;
        obj->errdat1[(ERRDATLEN)-1] = '\0';
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

char *
errdat2(obj, val=0)
    Embperl::Req obj
    char * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (char *)  obj->errdat2;

    if (items > 1) {
        strncpy(obj->errdat2, (char *) val, (ERRDATLEN) - 1) ;
        obj->errdat2[(ERRDATLEN)-1] = '\0';
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

char *
lastwarn(obj, val=0)
    Embperl::Req obj
    char * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (char *)  obj->lastwarn;

    if (items > 1) {
        strncpy(obj->lastwarn, (char *) val, (ERRDATLEN) - 1) ;
        obj->lastwarn[(ERRDATLEN)-1] = '\0';
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

SV *
errobj(obj, val=NULL)
    Embperl::Req obj
    SV * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (SV *)  obj->pErrSV;

    if (items > 1) {
        obj->pErrSV = (SV *)SvREFCNT_inc(val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

AV *
cleanup_vars(obj, val=NULL)
    Embperl::Req obj
    AV * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (AV *)  obj->pCleanupAV;

    if (items > 1) {
        obj->pCleanupAV = (AV *)SvREFCNT_inc(val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

HV *
cleanup_packages(obj, val=NULL)
    Embperl::Req obj
    HV * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (HV *)  obj->pCleanupPackagesHV;

    if (items > 1) {
        obj->pCleanupPackagesHV = (HV *)SvREFCNT_inc(val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

char *
initial_cwd(obj, val=NULL)
    Embperl::Req obj
    char * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (char *)  obj->sInitialCWD;

    if (items > 1) {
        obj->sInitialCWD = (char *)ep_pstrdup(obj->pPool,val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

AV *
messages(obj, val=NULL)
    Embperl::Req obj
    AV * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (AV *)  obj->pMessages;

    if (items > 1) {
        obj->pMessages = (AV *)SvREFCNT_inc(val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

AV *
default_messages(obj, val=NULL)
    Embperl::Req obj
    AV * val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (AV *)  obj->pDefaultMessages;

    if (items > 1) {
        obj->pDefaultMessages = (AV *)SvREFCNT_inc(val);
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

clock_t
startclock(obj, val=0)
    Embperl::Req obj
    clock_t val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (clock_t)  obj->startclock;

    if (items > 1) {
        obj->startclock = (clock_t) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 

I32
stsv_count(obj, val=0)
    Embperl::Req obj
    I32 val
  PREINIT:
    /*nada*/

  CODE:
    RETVAL = (I32)  obj->stsv_count;

    if (items > 1) {
        obj->stsv_count = (I32) val;
    }
  OUTPUT:
    RETVAL

MODULE = Embperl::Req    PACKAGE = Embperl::Req 



SV *
new (class,initializer=NULL)
    char * class
    SV * initializer 
PREINIT:
    SV * svobj ;
    Embperl__Req  cobj ;
    SV * tmpsv ;
CODE:
    epxs_Embperl__Req_create_obj(cobj,svobj,RETVAL,malloc(sizeof(*cobj))) ;

    if (initializer) {
        if (!SvROK(initializer) || !(tmpsv = SvRV(initializer))) 
            croak ("initializer for Embperl::Req::new is not a reference") ;

        if (SvTYPE(tmpsv) == SVt_PVHV || SvTYPE(tmpsv) == SVt_PVMG)  
            Embperl__Req_new_init (aTHX_ cobj, tmpsv, 0) ;
        else if (SvTYPE(tmpsv) == SVt_PVAV) {
            int i ;
            SvGROW(svobj, sizeof (*cobj) * av_len((AV *)tmpsv)) ;     
            for (i = 0; i <= av_len((AV *)tmpsv); i++) {
                SV * * itemrv = av_fetch((AV *)tmpsv, i, 0) ;
                SV * item ;
                if (!itemrv || !*itemrv || !SvROK(*itemrv) || !(item = SvRV(*itemrv))) 
                    croak ("array element of initializer for Embperl::Req::new is not a reference") ;
                Embperl__Req_new_init (aTHX_ &cobj[i], item, 1) ;
            }
        }
        else {
             croak ("initializer for Embperl::Req::new is not a hash/array/object reference") ;
        }
    }
OUTPUT:
    RETVAL 

MODULE = Embperl::Req    PACKAGE = Embperl::Req 



void
DESTROY (obj)
    Embperl::Req  obj 
CODE:
    Embperl__Req_destroy (aTHX_ obj) ;

PROTOTYPES: disabled

BOOT:
    items = items; /* -Wall */

