#define PERL_NO_GET_CONTEXT
#include "xshelper.h"
#include "multicall.h"

/* When testing, also test this with DO_MULTICALL set to 0 */
#ifndef DO_MULTICALL
#define DO_MULTICALL 1
#endif

#ifndef CvISXSUB
#define CvISXSUB(cv) (CvXSUB(cv) != NULL)
#endif

#define IsObject(sv)    (SvROK(sv) && SvOBJECT(SvRV(sv)))
#define IsArrayRef(sv)  (SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) == SVt_PVAV)
#define IsHashRef(sv)   (SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) == SVt_PVHV)
#define IsCodeRef(sv)   (SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) == SVt_PVCV)
#define IsScalarRef(sv) (SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) <= SVt_PVMG)

#define INSTALL_CONST(module, name)   newCONSTSUB(module, #name, newSViv(name))
#define WRONG_NUMBER_OF_PARAMETERS    "Wrong number of parameters"

#define SV_SAFE_COPY(val)                                 \
    (                                                     \
        (SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVCV)     \
            ? newRV_inc(SvRV(val))                        \
            : newSVsv(val)                                \
    )

/* Utility macros, typedefs, etc. */
#include "src/types.c"
#include "src/should_return.c"
#include "src/unpacking.c"
#include "src/sorting.c"

/* Type-specific macros, typedefs, etc. */
#include "src/Array.c"
#include "src/String.c"

MODULE = Sub::HandlesVia::XS  PACKAGE = Sub::HandlesVia::XS

BOOT:
{
    HV *stash = gv_stashpv("Sub::HandlesVia::XS", GV_ADD);

    INSTALL_CONST(stash, TYPE_BASE_ANY);
    INSTALL_CONST(stash, TYPE_BASE_DEFINED);
    INSTALL_CONST(stash, TYPE_BASE_REF);
    INSTALL_CONST(stash, TYPE_BASE_BOOL);
    INSTALL_CONST(stash, TYPE_BASE_INT);
    INSTALL_CONST(stash, TYPE_BASE_PZINT);
    INSTALL_CONST(stash, TYPE_BASE_NUM);
    INSTALL_CONST(stash, TYPE_BASE_PZNUM);
    INSTALL_CONST(stash, TYPE_BASE_STR);
    INSTALL_CONST(stash, TYPE_BASE_NESTR);
    INSTALL_CONST(stash, TYPE_BASE_CLASSNAME);
    INSTALL_CONST(stash, TYPE_BASE_OBJECT);
    INSTALL_CONST(stash, TYPE_BASE_SCALARREF);
    INSTALL_CONST(stash, TYPE_BASE_CODEREF);
    INSTALL_CONST(stash, TYPE_OTHER);
    INSTALL_CONST(stash, TYPE_ARRAYREF);
    INSTALL_CONST(stash, TYPE_HASHREF);

    INSTALL_CONST(stash, ARRAY_SRC_INVOCANT);
    INSTALL_CONST(stash, ARRAY_SRC_DEREF_SCALAR);
    INSTALL_CONST(stash, ARRAY_SRC_DEREF_ARRAY);
    INSTALL_CONST(stash, ARRAY_SRC_DEREF_HASH);
    INSTALL_CONST(stash, ARRAY_SRC_CALL_METHOD);

    INSTALL_CONST(stash, STR_SRC_INVOCANT);
    INSTALL_CONST(stash, STR_SRC_DEREF_SCALAR);
    INSTALL_CONST(stash, STR_SRC_DEREF_ARRAY);
    INSTALL_CONST(stash, STR_SRC_DEREF_HASH);
    INSTALL_CONST(stash, STR_SRC_CALL_METHOD);

    INSTALL_CONST(stash, SHOULD_RETURN_NOTHING);
    INSTALL_CONST(stash, SHOULD_RETURN_UNDEF);
    INSTALL_CONST(stash, SHOULD_RETURN_FALSE);
    INSTALL_CONST(stash, SHOULD_RETURN_TRUE);
    INSTALL_CONST(stash, SHOULD_RETURN_INVOCANT);
    INSTALL_CONST(stash, SHOULD_RETURN_OTHER);
    INSTALL_CONST(stash, SHOULD_RETURN_ARRAY);
    INSTALL_CONST(stash, SHOULD_RETURN_ARRAYBLESS);
    INSTALL_CONST(stash, SHOULD_RETURN_OUT);
    INSTALL_CONST(stash, SHOULD_RETURN_OUTBLESS);
    INSTALL_CONST(stash, SHOULD_RETURN_VAL);
    INSTALL_CONST(stash, SHOULD_RETURN_COUNT);
    INSTALL_CONST(stash, SHOULD_RETURN_STRING);
}

#### array : accessor

void
shvxs_array_accessor (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_SETTER_SIG);
    GET_ARRAY_FROM_SOURCE;
    GET_INDEX_FROM_SOURCE(1);

    I32 len = av_len(array) + 1;
    I32 real_ix = ix;
    if (real_ix < 0)
        real_ix += len;

    /*
    warn("HERE, items=%d, sig.has_curried_sv=%d, sig.index=%d, sig.has_index=%d, ix=%d, real_ix=%d, has_ix=%d", items, sig->has_curried_sv, sig->index, sig->has_index, ix, real_ix, has_ix);
    Perl_sv_dump(sig->curried_sv);
    */

    if ( items > ( has_ix ? 1 : 2 ) || sig->has_curried_sv ) {

        GET_CURRIED_SV_FROM_SOURCE(has_ix ? 1 : 2);

        I32 expected = 3;
        if (has_ix) expected--;
        if (has_curried_sv) expected--;
        if ( items != expected ) croak(WRONG_NUMBER_OF_PARAMETERS);

        val = SV_SAFE_COPY(curried_sv);

        bool ok;
        CHECK_TYPE(ok, val, sig->element_type, sig->element_type_cv);
        TRY_COERCE_TYPE(ok, val, sig->element_type, sig->element_type_cv, sig->element_coercion_cv);
        if (!ok) {
            if ( has_ix && has_curried_sv ) {
                type_error(val, "$curried", 1, sig->element_type, sig->element_type_tiny);
            }
            else if ( has_curried_sv ) {
                type_error(val, "$curried", 0, sig->element_type, sig->element_type_tiny);
            }
            else if ( has_ix ) {
                type_error(val, "$_", 1, sig->element_type, sig->element_type_tiny);
            }
            else {
                type_error(val, "$_", 2, sig->element_type, sig->element_type_tiny);
            }
        }

        av_store(array, real_ix, val);
    }
    else {
        I32 expected = 2;
        if (has_ix) expected--;
        if ( items != expected ) croak(WRONG_NUMBER_OF_PARAMETERS);

        if (real_ix < 0 || real_ix >= len) {
            val = &PL_sv_undef;
        }
        else {
            SV **svp = av_fetch(array, real_ix, 0);
            val = svp ? *svp : &PL_sv_undef;
        }
    }

    RETURN_ARRAY_EXPECTATION;
}

#### array : all

void
shvxs_array_all (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    if ( items > 1 ) croak(WRONG_NUMBER_OF_PARAMETERS);

    UNPACK_SIG(shvxs_array_SIMPLE_SIG);
    GET_ARRAY_FROM_SOURCE;

    out = array;

    RETURN_ARRAY_EXPECTATION;
}

#### array : all_true

void
shvxs_array_all_true (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_CALLBACK_SIG);
    GET_ARRAY_FROM_SOURCE;

    GET_CALLBACK_FROM_SOURCE(1);
    if ( items != ( has_callback ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    val = &PL_sv_yes;

    SV *sv_dollar_underscore = get_sv("_", 0);
    I32 len = av_len(array) + 1;
    I32 i;

    if ( DO_MULTICALL && !CvISXSUB(callback) ) {
        dMULTICALL;
        U8 gimme = G_SCALAR;
        PUSH_MULTICALL(callback);
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            MULTICALL;
            if (!SvTRUEx(*PL_stack_sp)) {
                val = &PL_sv_no;
                break;
            }
        }
        POP_MULTICALL;
    }
    else {
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            PUSHMARK(SP);
            call_sv((SV*)callback, G_SCALAR);
            if (!SvTRUEx(*PL_stack_sp)) {
                val = &PL_sv_no;
                break;
            }
        }
    }

    FREETMPS;
    SAVETMPS;

    RETURN_ARRAY_EXPECTATION;
}

#### array : any

void
shvxs_array_any (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_CALLBACK_SIG);
    GET_ARRAY_FROM_SOURCE;

    GET_CALLBACK_FROM_SOURCE(1);
    if ( items != ( has_callback ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    val = &PL_sv_no;

    SV *sv_dollar_underscore = get_sv("_", 0);
    I32 len = av_len(array) + 1;
    I32 i;

    if ( DO_MULTICALL && !CvISXSUB(callback) ) {
        dMULTICALL;
        U8 gimme = G_SCALAR;
        PUSH_MULTICALL(callback);
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            MULTICALL;
            if (SvTRUEx(*PL_stack_sp)) {
                val = &PL_sv_yes;
                break;
            }
        }
        POP_MULTICALL;
    }
    else {
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            PUSHMARK(SP);
            call_sv((SV*)callback, G_SCALAR);
            if (SvTRUEx(*PL_stack_sp)) {
                val = &PL_sv_yes;
                break;
            }
        }
    }

    FREETMPS;
    SAVETMPS;

    RETURN_ARRAY_EXPECTATION;
}

#### array : clear

void
shvxs_array_clear (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    if ( items > 1 ) croak(WRONG_NUMBER_OF_PARAMETERS);

    UNPACK_SIG(shvxs_array_SIMPLE_SIG);
    GET_ARRAY_FROM_SOURCE;

    av_clear(array);

    RETURN_ARRAY_EXPECTATION;
}

#### array : count

void
shvxs_array_count (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    if ( items > 1 ) croak(WRONG_NUMBER_OF_PARAMETERS);

    UNPACK_SIG(shvxs_array_SIMPLE_SIG);
    GET_ARRAY_FROM_SOURCE;

    SETVAL_INT( av_len(array) + 1 );
    
    RETURN_ARRAY_EXPECTATION;
}

#### array : first

void
shvxs_array_first (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_CALLBACK_SIG);
    GET_ARRAY_FROM_SOURCE;

    GET_CALLBACK_FROM_SOURCE(1);
    if ( items != ( has_callback ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    val = &PL_sv_undef;

    SV *sv_dollar_underscore = get_sv("_", 0);
    I32 len = av_len(array) + 1;
    I32 i;

    if ( DO_MULTICALL && !CvISXSUB(callback) ) {
        dMULTICALL;
        U8 gimme = G_SCALAR;
        PUSH_MULTICALL(callback);
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            MULTICALL;
            if (SvTRUEx(*PL_stack_sp)) {
                val = newSVsv(*svp);
                break;
            }
        }
        POP_MULTICALL;
    }
    else {
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            if (!svp) continue;
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            PUSHMARK(SP);
            call_sv((SV*)callback, G_SCALAR);
            if (SvTRUEx(*PL_stack_sp)) {
                val = newSVsv(*svp);
                break;
            }
        }
    }

    FREETMPS;
    SAVETMPS;

    RETURN_ARRAY_EXPECTATION;
}

#### array : for_each

void
shvxs_array_for_each (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_CALLBACK_SIG);
    GET_ARRAY_FROM_SOURCE;

    GET_CALLBACK_FROM_SOURCE(1);
    if ( items != ( has_callback ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    SV *sv_dollar_underscore = get_sv("_", 0);
    SV *ixsv = sv_2mortal(newSViv(0));
    I32 len = av_len(array) + 1;
    I32 i;

    ENTER;
    SAVETMPS;

    for (i = 0; i < len; i++) {
        SV **svp = av_fetch(array, i, 0);
        if (!svp) continue;
        SV *elem = *svp;
        sv_setsv(sv_dollar_underscore, elem);
        sv_setiv(ixsv, i);

        PUSHMARK(SP);
        XPUSHs(elem);
        XPUSHs(ixsv);
        PUTBACK;

        call_sv((SV*)callback, G_VOID | G_DISCARD);
        SPAGAIN;

        FREETMPS;
        SAVETMPS;
    }

    FREETMPS;
    LEAVE;

    RETURN_ARRAY_EXPECTATION;
}

#### array : for_each2

void
shvxs_array_for_each2 (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_CALLBACK_SIG);
    GET_ARRAY_FROM_SOURCE;

    GET_CALLBACK_FROM_SOURCE(1);
    if ( items != ( has_callback ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    SV *sv_dollar_underscore = get_sv("_", 0);
    I32 len = av_len(array) + 1;
    I32 i;

    if ( DO_MULTICALL && !CvISXSUB(callback) ) {
        dMULTICALL;
        U8 gimme = G_VOID;
        PUSH_MULTICALL(callback);
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            MULTICALL;
        }
        POP_MULTICALL;
    }
    else {
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            if (!svp) continue;
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            PUSHMARK(SP);
            PUTBACK;
            call_sv((SV*)callback, G_VOID);
            SPAGAIN;
        }
    }

    FREETMPS;
    SAVETMPS;

    RETURN_ARRAY_EXPECTATION;
}

#### array : get

void
shvxs_array_get (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_INDEX_SIG);
    GET_ARRAY_FROM_SOURCE;

    GET_INDEX_FROM_SOURCE(1);
    if ( items != ( has_ix ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    I32 len = av_len(array) + 1;
    I32 real_ix = ix;
    if (real_ix < 0)
        real_ix += len;

    if (real_ix < 0 || real_ix >= len) {
        val = &PL_sv_undef;
    }
    else {
        SV **svp = av_fetch(array, real_ix, 0);
        val = svp ? *svp : &PL_sv_undef;
    }

    RETURN_ARRAY_EXPECTATION;
}

#### array : grep

void
shvxs_array_grep (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_CALLBACK_SIG);
    GET_ARRAY_FROM_SOURCE;

    GET_CALLBACK_FROM_SOURCE(1);
    if ( items != ( has_callback ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    out = newAV();

    SV *sv_dollar_underscore = get_sv("_", 0);
    I32 len = av_len(array) + 1;
    I32 i;

    if ( DO_MULTICALL && !CvISXSUB(callback) ) {
        dMULTICALL;
        U8 gimme = G_SCALAR;
        PUSH_MULTICALL(callback);
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            MULTICALL;
            if (SvTRUEx(*PL_stack_sp)) {
                av_push(out, SV_SAFE_COPY(*svp));
            }
        }
        POP_MULTICALL;
    }
    else {
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            if (!svp) continue;
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            PUSHMARK(SP);
            call_sv((SV*)callback, G_SCALAR);
            if (SvTRUEx(*PL_stack_sp)) {
                av_push(out, SV_SAFE_COPY(*svp));
            }
        }
    }

    FREETMPS;
    SAVETMPS;

    RETURN_ARRAY_EXPECTATION;
}

#### array : is_empty

void
shvxs_array_is_empty (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    if ( items > 1 ) croak(WRONG_NUMBER_OF_PARAMETERS);

    UNPACK_SIG(shvxs_array_SIMPLE_SIG);
    GET_ARRAY_FROM_SOURCE;

    SETVAL_BOOL( av_len(array) < 0 );

    RETURN_ARRAY_EXPECTATION;
}

#### array : join

void
shvxs_array_join (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_SV_SIG);
    GET_ARRAY_FROM_SOURCE;

    MAYBE_GET_CURRIED_SV_FROM_SOURCE(1);
    if ( items > ( has_curried_sv ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    SV* joiner = curried_sv ? curried_sv : sv_2mortal(newSVpv(",", 1));
    if ( !joiner || !SvOK(joiner) || SvROK(joiner) || isGV(joiner) ) {
        if ( has_curried_sv ) type_error(joiner, "$curried", 0, TYPE_BASE_STR, NULL);
        type_error(joiner, "$_", 1, TYPE_BASE_STR, NULL);
    }

    STRLEN sep_len;
    const char *sep = SvPV(joiner, sep_len);

    val = newSVpv("", 0);

    I32 len = av_len(array) + 1;
    I32 i;

    for (i = 0; i < len; i++) {
        SV **svp = av_fetch(array, i, 0);

        if (i > 0)
            sv_catpvn(val, sep, sep_len);

        if (svp && SvOK(*svp)) {
            STRLEN l;
            const char *p = SvPV(*svp, l);
            sv_catpvn(val, p, l);
        }
    }

    RETURN_ARRAY_EXPECTATION;
}

#### array : map

void
shvxs_array_map (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_CALLBACK_SIG);
    GET_ARRAY_FROM_SOURCE;

    GET_CALLBACK_FROM_SOURCE(1);
    if ( items != ( has_callback ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    out = newAV();

    SV *sv_dollar_underscore = get_sv("_", 0);
    I32 len = av_len(array) + 1;
    I32 i, j;

    ENTER;
    SAVETMPS;

    for (i = 0; i < len; i++) {
        SV **svp = av_fetch(array, i, 0);
        if (!svp) continue;
        SV *elem = *svp;
        sv_setsv(sv_dollar_underscore, elem);

        PUSHMARK(SP);
        PUTBACK;

        I32 count = call_sv((SV *)callback, G_ARRAY);
        SPAGAIN;

        /* stack is LIFO; preserve order */
        if (count > 0) {
            SV **results = SP - count + 1;
            for (j = 0; j < count; j++) {
                av_push(out, SV_SAFE_COPY(results[j]));
            }
            SP -= count;
        }
        
        PUTBACK;
        FREETMPS;
        SAVETMPS;
    }

    FREETMPS;
    LEAVE;

    RETURN_ARRAY_EXPECTATION;
}

#### array : none

void
shvxs_array_none (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_CALLBACK_SIG);
    GET_ARRAY_FROM_SOURCE;

    GET_CALLBACK_FROM_SOURCE(1);
    if ( items != ( has_callback ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    val = &PL_sv_yes;

    SV *sv_dollar_underscore = get_sv("_", 0);
    I32 len = av_len(array) + 1;
    I32 i;

    if ( DO_MULTICALL && !CvISXSUB(callback) ) {
        dMULTICALL;
        U8 gimme = G_SCALAR;
        PUSH_MULTICALL(callback);
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            MULTICALL;
            if (SvTRUEx(*PL_stack_sp)) {
                val = &PL_sv_no;
                break;
            }
        }
        POP_MULTICALL;
    }
    else {
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            PUSHMARK(SP);
            call_sv((SV*)callback, G_SCALAR);
            if (SvTRUEx(*PL_stack_sp)) {
                val = &PL_sv_no;
                break;
            }
        }
    }

    FREETMPS;
    SAVETMPS;

    RETURN_ARRAY_EXPECTATION;
}

#### array : not_all_true

void
shvxs_array_not_all_true (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_CALLBACK_SIG);
    GET_ARRAY_FROM_SOURCE;

    GET_CALLBACK_FROM_SOURCE(1);
    if ( items != ( has_callback ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);

    val = &PL_sv_no;

    SV *sv_dollar_underscore = get_sv("_", 0);
    I32 len = av_len(array) + 1;
    I32 i;

    if ( DO_MULTICALL && !CvISXSUB(callback) ) {
        dMULTICALL;
        U8 gimme = G_SCALAR;
        PUSH_MULTICALL(callback);
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            MULTICALL;
            if (!SvTRUEx(*PL_stack_sp)) {
                val = &PL_sv_yes;
                break;
            }
        }
        POP_MULTICALL;
    }
    else {
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            SV *elem = svp ? *svp : &PL_sv_undef;
            sv_setsv(sv_dollar_underscore, elem);
            PUSHMARK(SP);
            call_sv((SV*)callback, G_SCALAR);
            if (!SvTRUEx(*PL_stack_sp)) {
                val = &PL_sv_yes;
                break;
            }
        }
    }

    FREETMPS;
    SAVETMPS;

    RETURN_ARRAY_EXPECTATION;
}

#### array : pop

void
shvxs_array_pop (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    if ( items > 1 ) croak(WRONG_NUMBER_OF_PARAMETERS);

    UNPACK_SIG(shvxs_array_SIMPLE_SIG);
    GET_ARRAY_FROM_SOURCE;

    val = (SV*)av_pop(array);
    if (val) {
        SvREFCNT_inc(val);
    }
    else {
        val = newSV(0);
    }

    RETURN_ARRAY_EXPECTATION;
}

#### array : push

void
shvxs_array_push (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_NEW_ELEMS_SIG);
    GET_ARRAY_FROM_SOURCE;

    bool ok;
    I32 i;
    for (i = 1; i < items; i++) {
        val = ST(i);
        CHECK_TYPE(ok, newSVsv(val), sig->element_type, sig->element_type_cv);
        TRY_COERCE_TYPE(ok, val, sig->element_type, sig->element_type_cv, sig->element_coercion_cv);
        if (!ok) type_error(val, "$_", i, sig->element_type, sig->element_type_tiny);
        av_push(array, SV_SAFE_COPY(val));
    }

    RETURN_ARRAY_EXPECTATION;
}

#### array : reverse

void
shvxs_array_reverse (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    if ( items > 1 ) croak(WRONG_NUMBER_OF_PARAMETERS);

    UNPACK_SIG(shvxs_array_SIMPLE_SIG);
    GET_ARRAY_FROM_SOURCE;

    out = newAV();
    I32 len = av_len(array);
    if (len >= 0)
        av_extend(out, len);

    I32 i;
    SV **svp;
    for (i = len; i >= 0; i--) {
        svp = av_fetch(array, i, 0);
        av_push(out, svp ? newSVsv(*svp) : &PL_sv_undef);
    }

    RETURN_ARRAY_EXPECTATION;
}

#### array : set

void
shvxs_array_set (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_SETTER_SIG);
    GET_ARRAY_FROM_SOURCE;
    GET_INDEX_FROM_SOURCE(1);
    GET_CURRIED_SV_FROM_SOURCE(has_ix ? 1 : 2);

    I32 expected = 3;
    if (has_ix) expected--;
    if (has_curried_sv) expected--;
    if ( items != expected ) croak(WRONG_NUMBER_OF_PARAMETERS);

    I32 len = av_len(array) + 1;
    I32 real_ix = ix;
    if (real_ix < 0)
        real_ix += len;

    val = SV_SAFE_COPY(curried_sv);

    bool ok;
    CHECK_TYPE(ok, val, sig->element_type, sig->element_type_cv);
    TRY_COERCE_TYPE(ok, val, sig->element_type, sig->element_type_cv, sig->element_coercion_cv);
    if (!ok) {
        if ( has_ix && has_curried_sv ) {
            type_error(val, "$curried", 1, sig->element_type, sig->element_type_tiny);
        }
        else if ( has_curried_sv ) {
            type_error(val, "$curried", 0, sig->element_type, sig->element_type_tiny);
        }
        else if ( has_ix ) {
            type_error(val, "$_", 1, sig->element_type, sig->element_type_tiny);
        }
        else {
            type_error(val, "$_", 2, sig->element_type, sig->element_type_tiny);
        }
    }

    av_store(array, real_ix, val);

    RETURN_ARRAY_EXPECTATION;
}

#### array : shift

void
shvxs_array_shift (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    if ( items > 1 ) croak(WRONG_NUMBER_OF_PARAMETERS);

    UNPACK_SIG(shvxs_array_SIMPLE_SIG);
    GET_ARRAY_FROM_SOURCE;

    val = (SV*)av_shift(array);
    if (val) {
        SvREFCNT_inc(val);
    }
    else {
        val = newSV(0);
    }

    RETURN_ARRAY_EXPECTATION;
}

#### array : sort

void
shvxs_array_sort (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_CALLBACK_SIG);
    GET_ARRAY_FROM_SOURCE;

    MAYBE_GET_CALLBACK_FROM_SOURCE(1);
    if ( items > ( has_callback ? 1 : 2 ) ) croak(WRONG_NUMBER_OF_PARAMETERS);
    if ( !has_callback && items == 2 && !callback && !IsCodeRef(ST(1)) ) {
        type_error(ST(1), "$_", 1, TYPE_BASE_CODEREF, NULL);
    }

    out = newAV();

    I32 len = av_len(array) + 1;
    if (len > 1) {
        SV **elems = (SV **)malloc(len * sizeof(SV *));
        if (!elems)
            croak("Out of memory");

        I32 i;
        for (i = 0; i < len; i++) {
            SV **svp = av_fetch(array, i, 0);
            elems[i] = svp ? *svp : &PL_sv_undef;
        }

        sort_ctx_t ctx;
#ifdef USE_ITHREADS
        ctx.my_perl = my_perl;
#endif
        ctx.callback = NULL;
        ctx.err = NULL;
        if ( callback )
            ctx.callback = callback;

        SHVXS_QSORT(elems, len, sizeof(SV *), &ctx);

        av_extend(out, len - 1);

        for (i = 0; i < len; i++) {
            av_push(out, newSVsv(elems[i]));
        }

        free(elems);

        if (ctx.err) {
            SV *e = ctx.err;
            ctx.err = NULL;
            croak_sv(e);
        }
    }

    RETURN_ARRAY_EXPECTATION;
}

#### array : unshift

void
shvxs_array_unshift (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_array_NEW_ELEMS_SIG);
    GET_ARRAY_FROM_SOURCE;

    bool ok;
    I32 i;
    for (i = items - 1; i >= 1; i--) {
        val = ST(i);
        CHECK_TYPE(ok, newSVsv(val), sig->element_type, sig->element_type_cv);
        TRY_COERCE_TYPE(ok, val, sig->element_type, sig->element_type_cv, sig->element_coercion_cv);
        if (!ok) type_error(val, "$_", i, sig->element_type, sig->element_type_tiny);
        av_unshift(array, 1);
        av_store(array, 0, SV_SAFE_COPY(val));
    }

    RETURN_ARRAY_EXPECTATION;
}

#### array : INSTALL(SIMPLE)

void
INSTALL_shvxs_array_SIMPLE(SV *name, SV *href)
ALIAS:
    INSTALL_shvxs_array_all          = 1
    INSTALL_shvxs_array_clear        = 2
    INSTALL_shvxs_array_count        = 3
    INSTALL_shvxs_array_is_empty     = 4
    INSTALL_shvxs_array_pop          = 5
    INSTALL_shvxs_array_reverse      = 6
    INSTALL_shvxs_array_shift        = 7
CODE:
{
    dTHX;

    XSUBADDR_t op;
    enum ReturnPattern rp;
    switch ( ix ) {
        case 1:
            op = XS_Sub__HandlesVia__XS_shvxs_array_all;
            rp = SHOULD_RETURN_OUT;
            break;
        case 2:
            op = XS_Sub__HandlesVia__XS_shvxs_array_clear;
            rp = SHOULD_RETURN_NOTHING;
            break;
        case 3:
            op = XS_Sub__HandlesVia__XS_shvxs_array_count;
            rp = SHOULD_RETURN_VAL;
            break;
        case 4:
            op = XS_Sub__HandlesVia__XS_shvxs_array_is_empty;
            rp = SHOULD_RETURN_VAL;
            break;
        case 5:
            op = XS_Sub__HandlesVia__XS_shvxs_array_pop;
            rp = SHOULD_RETURN_VAL;
            break;
        case 6:
            op = XS_Sub__HandlesVia__XS_shvxs_array_reverse;
            rp = SHOULD_RETURN_OUT;
            break;
        case 7:
            op = XS_Sub__HandlesVia__XS_shvxs_array_shift;
            rp = SHOULD_RETURN_VAL;
            break;
        default:
            croak("PANIC!");
    }

    shvxs_array_SIMPLE_SIG *sig;
    Newxz(sig, 1, shvxs_array_SIMPLE_SIG);
    UNPACKING_HV_FROM_SV (href, hv);
    UNPACKING_GET_ENUM   (hv, sig, arr_source,            ARRAY_SRC_INVOCANT, ArraySource);
    UNPACKING_GET_STRING (hv, sig, arr_source_string,     NULL);
    UNPACKING_GET_STRING (hv, sig, arr_source_fallback,   NULL);
    UNPACKING_GET_I32    (hv, sig, arr_source_index,      0);
    UNPACKING_GET_ENUM   (hv, sig, method_return_pattern, rp, ReturnPattern);
    UNPACKING_GET_STRING (hv, sig, method_return_class,       NULL);
    UNPACKING_GET_STRING (hv, sig, method_return_constructor, NULL);

    CV *cv = newXS( SvPV_nolen(name), op, (char *)__FILE__ );
    CvXSUBANY(cv).any_ptr = sig;
    XSRETURN_EMPTY;
}

#### array : INSTALL(CALLBACK)

void
INSTALL_shvxs_array_CALLBACK(SV *name, SV *href)
ALIAS:
    INSTALL_shvxs_array_for_each     = 1
    INSTALL_shvxs_array_grep         = 2
    INSTALL_shvxs_array_map          = 3
    INSTALL_shvxs_array_first        = 4
    INSTALL_shvxs_array_any          = 5
    INSTALL_shvxs_array_all_true     = 6
    INSTALL_shvxs_array_sort         = 7
    INSTALL_shvxs_array_for_each2    = 8
    INSTALL_shvxs_array_none         = 9
    INSTALL_shvxs_array_not_all_true = 10
CODE:
{
    dTHX;

    XSUBADDR_t op;
    enum ReturnPattern rp;
    switch ( ix ) {
        case 1:
            op = XS_Sub__HandlesVia__XS_shvxs_array_for_each;
            rp = SHOULD_RETURN_INVOCANT;
            break;
        case 2:
            op = XS_Sub__HandlesVia__XS_shvxs_array_grep;
            rp = SHOULD_RETURN_OUT;
            break;
        case 3:
            op = XS_Sub__HandlesVia__XS_shvxs_array_map;
            rp = SHOULD_RETURN_OUT;
            break;
        case 4:
            op = XS_Sub__HandlesVia__XS_shvxs_array_first;
            rp = SHOULD_RETURN_VAL;
            break;
        case 5:
            op = XS_Sub__HandlesVia__XS_shvxs_array_any;
            rp = SHOULD_RETURN_VAL;
            break;
        case 6:
            op = XS_Sub__HandlesVia__XS_shvxs_array_all_true;
            rp = SHOULD_RETURN_VAL;
            break;
        case 7:
            op = XS_Sub__HandlesVia__XS_shvxs_array_sort;
            rp = SHOULD_RETURN_OUT;
            break;
        case 8:
            op = XS_Sub__HandlesVia__XS_shvxs_array_for_each2;
            rp = SHOULD_RETURN_INVOCANT;
            break;
        case 9:
            op = XS_Sub__HandlesVia__XS_shvxs_array_none;
            rp = SHOULD_RETURN_VAL;
            break;
        case 10:
            op = XS_Sub__HandlesVia__XS_shvxs_array_not_all_true;
            rp = SHOULD_RETURN_VAL;
            break;
        default:
            croak("PANIC!");
    }

    shvxs_array_CALLBACK_SIG *sig;
    Newxz(sig, 1, shvxs_array_CALLBACK_SIG);
    UNPACKING_HV_FROM_SV (href, hv);
    UNPACKING_GET_ENUM   (hv, sig, arr_source,            ARRAY_SRC_INVOCANT, ArraySource);
    UNPACKING_GET_STRING (hv, sig, arr_source_string,     NULL);
    UNPACKING_GET_STRING (hv, sig, arr_source_fallback,   NULL);
    UNPACKING_GET_I32    (hv, sig, arr_source_index,      0);
    UNPACKING_GET_CV     (hv, sig, callback);
    UNPACKING_GET_ENUM   (hv, sig, method_return_pattern, rp, ReturnPattern);
    UNPACKING_GET_STRING (hv, sig, method_return_class,       NULL);
    UNPACKING_GET_STRING (hv, sig, method_return_constructor, NULL);

    CV *cv = newXS( SvPV_nolen(name), op, (char *)__FILE__ );
    CvXSUBANY(cv).any_ptr = sig;
    XSRETURN_EMPTY;
}

#### array : INSTALL(SV)

void
INSTALL_shvxs_array_SV(SV *name, SV *href)
ALIAS:
    INSTALL_shvxs_array_join         = 1
CODE:
{
    dTHX;

    XSUBADDR_t op;
    enum ReturnPattern rp;
    switch ( ix ) {
        case 1:
            op = XS_Sub__HandlesVia__XS_shvxs_array_join;
            rp = SHOULD_RETURN_VAL;
            break;
        default:
            croak("PANIC!");
    }

    shvxs_array_SV_SIG *sig;
    Newxz(sig, 1, shvxs_array_SV_SIG);
    UNPACKING_HV_FROM_SV (href, hv);
    UNPACKING_GET_ENUM   (hv, sig, arr_source,            ARRAY_SRC_INVOCANT, ArraySource);
    UNPACKING_GET_STRING (hv, sig, arr_source_string,     NULL);
    UNPACKING_GET_STRING (hv, sig, arr_source_fallback,   NULL);
    UNPACKING_GET_I32    (hv, sig, arr_source_index,      0);
    UNPACKING_MAYBE_SV   (hv, sig, curried_sv,            has_curried_sv);
    UNPACKING_GET_ENUM   (hv, sig, method_return_pattern, rp, ReturnPattern);
    UNPACKING_GET_STRING (hv, sig, method_return_class,       NULL);
    UNPACKING_GET_STRING (hv, sig, method_return_constructor, NULL);

    CV *cv = newXS( SvPV_nolen(name), op, (char *)__FILE__ );
    CvXSUBANY(cv).any_ptr = sig;
    XSRETURN_EMPTY;
}

#### array : INSTALL(NEW_ELEMS)

void
INSTALL_shvxs_array_NEW_ELEMS(SV *name, SV *href)
ALIAS:
    INSTALL_shvxs_array_push         = 1
    INSTALL_shvxs_array_unshift      = 2
CODE:
{
    dTHX;

    XSUBADDR_t op;
    enum ReturnPattern rp;
    switch ( ix ) {
        case 1:
            op = XS_Sub__HandlesVia__XS_shvxs_array_push;
            rp = SHOULD_RETURN_COUNT;
            break;
        case 2:
            op = XS_Sub__HandlesVia__XS_shvxs_array_unshift;
            rp = SHOULD_RETURN_COUNT;
            break;
        default:
            croak("PANIC!");
    }

    shvxs_array_NEW_ELEMS_SIG *sig;
    Newxz(sig, 1, shvxs_array_NEW_ELEMS_SIG);
    UNPACKING_HV_FROM_SV (href, hv);
    UNPACKING_GET_ENUM   (hv, sig, arr_source,            ARRAY_SRC_INVOCANT, ArraySource);
    UNPACKING_GET_STRING (hv, sig, arr_source_string,     NULL);
    UNPACKING_GET_STRING (hv, sig, arr_source_fallback,   NULL);
    UNPACKING_GET_I32    (hv, sig, arr_source_index,      0);
    UNPACKING_GET_I32    (hv, sig, element_type,          TYPE_BASE_ANY);
    UNPACKING_GET_CV     (hv, sig, element_type_cv);
    UNPACKING_MAYBE_SV   (hv, sig, element_type_tiny,     has_element_type_tiny);
    UNPACKING_GET_CV     (hv, sig, element_coercion_cv);
    UNPACKING_GET_ENUM   (hv, sig, method_return_pattern, rp, ReturnPattern);
    UNPACKING_GET_STRING (hv, sig, method_return_class,       NULL);
    UNPACKING_GET_STRING (hv, sig, method_return_constructor, NULL);

    if (sig->element_type != TYPE_BASE_ANY && sig->element_type_cv == NULL) {
        croak("element_type_cv is required unless element_type is TYPE_BASE_ANY");
    }

    CV *cv = newXS( SvPV_nolen(name), op, (char *)__FILE__ );
    CvXSUBANY(cv).any_ptr = sig;
    XSRETURN_EMPTY;
}

#### array : INSTALL(INDEX)

void
INSTALL_shvxs_array_INDEX(SV *name, SV *href)
ALIAS:
    INSTALL_shvxs_array_get          = 1
    INSTALL_shvxs_array_peek         = 2
    INSTALL_shvxs_array_peekend      = 3
CODE:
{
    dTHX;

    XSUBADDR_t op;
    enum ReturnPattern rp;
    switch ( ix ) {
        case 1:
        case 2:
        case 3:
            op = XS_Sub__HandlesVia__XS_shvxs_array_get;
            rp = SHOULD_RETURN_VAL;
            break;
        default:
            croak("PANIC!");
    }

    shvxs_array_INDEX_SIG *sig;
    Newxz(sig, 1, shvxs_array_INDEX_SIG);
    UNPACKING_HV_FROM_SV (href, hv);
    UNPACKING_GET_ENUM   (hv, sig, arr_source,            ARRAY_SRC_INVOCANT, ArraySource);
    UNPACKING_GET_STRING (hv, sig, arr_source_string,     NULL);
    UNPACKING_GET_STRING (hv, sig, arr_source_fallback,   NULL);
    UNPACKING_GET_I32    (hv, sig, arr_source_index,      0);
    UNPACKING_MAYBE_I32  (hv, sig, index, has_index);
    UNPACKING_GET_ENUM   (hv, sig, method_return_pattern, rp, ReturnPattern);
    UNPACKING_GET_STRING (hv, sig, method_return_class,       NULL);
    UNPACKING_GET_STRING (hv, sig, method_return_constructor, NULL);

    if ( ix == 2 ) {
        sig->has_index = TRUE;
        sig->index     = 0;
    }
    else if ( ix == 3 ) {
        sig->has_index = TRUE;
        sig->index     = -1;
    }

    CV *cv = newXS( SvPV_nolen(name), op, (char *)__FILE__ );
    CvXSUBANY(cv).any_ptr = sig;
    XSRETURN_EMPTY;
}

#### array : INSTALL(SETTER)

void
INSTALL_shvxs_array_SETTER(SV *name, SV *href)
ALIAS:
    INSTALL_shvxs_array_set          = 1
    INSTALL_shvxs_array_accessor     = 2
CODE:
{
    dTHX;

    XSUBADDR_t op;
    enum ReturnPattern rp;
    switch ( ix ) {
        case 1:
            op = XS_Sub__HandlesVia__XS_shvxs_array_set;
            rp = SHOULD_RETURN_VAL;
            break;
        case 2:
            op = XS_Sub__HandlesVia__XS_shvxs_array_accessor;
            rp = SHOULD_RETURN_VAL;
            break;
        default:
            croak("PANIC!");
    }

    shvxs_array_SETTER_SIG *sig;
    Newxz(sig, 1, shvxs_array_SETTER_SIG);
    UNPACKING_HV_FROM_SV (href, hv);
    UNPACKING_GET_ENUM   (hv, sig, arr_source,            ARRAY_SRC_INVOCANT, ArraySource);
    UNPACKING_GET_STRING (hv, sig, arr_source_string,     NULL);
    UNPACKING_GET_STRING (hv, sig, arr_source_fallback,   NULL);
    UNPACKING_GET_I32    (hv, sig, arr_source_index,      0);
    UNPACKING_MAYBE_I32  (hv, sig, index, has_index);
    UNPACKING_MAYBE_SV   (hv, sig, curried_sv, has_curried_sv);
    UNPACKING_GET_I32    (hv, sig, element_type,          TYPE_BASE_ANY);
    UNPACKING_GET_CV     (hv, sig, element_type_cv);
    UNPACKING_MAYBE_SV   (hv, sig, element_type_tiny,     has_element_type_tiny);
    UNPACKING_GET_CV     (hv, sig, element_coercion_cv);
    UNPACKING_GET_ENUM   (hv, sig, method_return_pattern, rp, ReturnPattern);
    UNPACKING_GET_STRING (hv, sig, method_return_class,       NULL);
    UNPACKING_GET_STRING (hv, sig, method_return_constructor, NULL);

    if (sig->element_type != TYPE_BASE_ANY && sig->element_type_cv == NULL) {
        croak("element_type_cv is required unless element_type is TYPE_BASE_ANY");
    }

    CV *cv = newXS( SvPV_nolen(name), op, (char *)__FILE__ );
    CvXSUBANY(cv).any_ptr = sig;
    XSRETURN_EMPTY;
}

#### string : append

void
shvxs_string_append (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_SETTER_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SV *tmp = newSVsv(string);
    SvREFCNT_inc(tmp);
    sv_catsv(tmp, curried_sv);

    CHECK_TYPE(ok, tmp, sig->type, sig->type_cv);
    TRY_COERCE_TYPE(ok, tmp, sig->type, sig->type_cv, sig->coercion_cv);
    if (!ok) type_error(tmp, "$newvalue", -1, sig->type, sig->type_tiny);

    SET_STRING(tmp);
    SvREFCNT_dec(tmp);

    RETURN_STRING_EXPECTATION;
}

#### string : cmp

void
shvxs_string_cmp (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_INT( sv_cmp(string, curried_sv) );

    RETURN_STRING_EXPECTATION;
}

#### string : cmpi

void
shvxs_string_cmpi (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_INT( SV_CMP_CI(string, curried_sv) );

    RETURN_STRING_EXPECTATION;
}

#### string : eq

void
shvxs_string_eq (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( sv_eq(string, curried_sv) );

    RETURN_STRING_EXPECTATION;
}

#### string : eqi

void
shvxs_string_eqi (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( SV_CMP_CI(string, curried_sv)==0 );

    RETURN_STRING_EXPECTATION;
}

#### string : ge

void
shvxs_string_ge (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( sv_cmp(string, curried_sv) >= 0 );

    RETURN_STRING_EXPECTATION;
}

#### string : gei

void
shvxs_string_gei (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( SV_CMP_CI(string, curried_sv) >= 0 );

    RETURN_STRING_EXPECTATION;
}

#### string : gt

void
shvxs_string_gt (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( sv_cmp(string, curried_sv) > 0 );

    RETURN_STRING_EXPECTATION;
}

#### string : gti

void
shvxs_string_gti (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( SV_CMP_CI(string, curried_sv) > 0 );

    RETURN_STRING_EXPECTATION;
}

#### string : le

void
shvxs_string_le (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( sv_cmp(string, curried_sv) <= 0 );

    RETURN_STRING_EXPECTATION;
}

#### string : lei

void
shvxs_string_lei (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( SV_CMP_CI(string, curried_sv) <= 0 );

    RETURN_STRING_EXPECTATION;
}

#### string : lt

void
shvxs_string_lt (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( sv_cmp(string, curried_sv) < 0 );

    RETURN_STRING_EXPECTATION;
}

#### string : lti

void
shvxs_string_lti (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( SV_CMP_CI(string, curried_sv) < 0 );

    RETURN_STRING_EXPECTATION;
}

#### string : ne

void
shvxs_string_ne (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( !sv_eq(string, curried_sv) );

    RETURN_STRING_EXPECTATION;
}

#### string : nei

void
shvxs_string_nei (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_CMP_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SETVAL_BOOL( SV_CMP_CI(string, curried_sv)!=0 );

    RETURN_STRING_EXPECTATION;
}

#### string : prepend

void
shvxs_string_prepend (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_SETTER_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;
    CHECK_CURRIED_SV_IS_STRING;

    SV *tmp = newSVsv(curried_sv);
    SvREFCNT_inc(tmp);
    sv_catsv(tmp, string);

    CHECK_TYPE(ok, tmp, sig->type, sig->type_cv);
    TRY_COERCE_TYPE(ok, tmp, sig->type, sig->type_cv, sig->coercion_cv);
    if (!ok) type_error(tmp, "$newvalue", -1, sig->type, sig->type_tiny);

    SET_STRING(tmp);
    SvREFCNT_dec(tmp);

    RETURN_STRING_EXPECTATION;
}

#### string : set

void
shvxs_string_set (SV *invocant, ...)
CODE:
{
    dTHX;
    dSP;

    UNPACK_SIG(shvxs_string_SETTER_SIG);
    GET_STRING_FROM_SOURCE;
    GET_CURRIED_SV_FROM_SOURCE(1);
    COMMON_STRING_PARAM_COUNT_CHECK;

    bool ok;
    CHECK_TYPE(ok, curried_sv, sig->type, sig->type_cv);
    TRY_COERCE_TYPE(ok, curried_sv, sig->type, sig->type_cv, sig->coercion_cv);
    if (!ok) {
        if (has_curried_sv) {
            type_error(curried_sv, "$curried", 0, sig->type, sig->type_tiny);
        }
        else {
            type_error(curried_sv, "$_", 1, sig->type, sig->type_tiny);
        }
    }

    SET_STRING(curried_sv);

    RETURN_STRING_EXPECTATION;
}

#### string : INSTALL(CMP)

void
INSTALL_shvxs_string_CMP(SV *name, SV *href)
ALIAS:
    INSTALL_shvxs_string_eq          = 1
    INSTALL_shvxs_string_ne          = 2
    INSTALL_shvxs_string_gt          = 3
    INSTALL_shvxs_string_ge          = 4
    INSTALL_shvxs_string_lt          = 5
    INSTALL_shvxs_string_le          = 6
    INSTALL_shvxs_string_cmp         = 7
    INSTALL_shvxs_string_eqi         = 17
    INSTALL_shvxs_string_nei         = 18
    INSTALL_shvxs_string_gti         = 19
    INSTALL_shvxs_string_gei         = 20
    INSTALL_shvxs_string_lti         = 21
    INSTALL_shvxs_string_lei         = 22
    INSTALL_shvxs_string_cmpi        = 23
CODE:
{
    dTHX;

    XSUBADDR_t op;
    enum ReturnPattern rp;
    switch ( ix ) {
        case 1:
            op = XS_Sub__HandlesVia__XS_shvxs_string_eq;
            rp = SHOULD_RETURN_VAL;
            break;
        case 2:
            op = XS_Sub__HandlesVia__XS_shvxs_string_ne;
            rp = SHOULD_RETURN_VAL;
            break;
        case 3:
            op = XS_Sub__HandlesVia__XS_shvxs_string_gt;
            rp = SHOULD_RETURN_VAL;
            break;
        case 4:
            op = XS_Sub__HandlesVia__XS_shvxs_string_ge;
            rp = SHOULD_RETURN_VAL;
            break;
        case 5:
            op = XS_Sub__HandlesVia__XS_shvxs_string_lt;
            rp = SHOULD_RETURN_VAL;
            break;
        case 6:
            op = XS_Sub__HandlesVia__XS_shvxs_string_le;
            rp = SHOULD_RETURN_VAL;
            break;
        case 7:
            op = XS_Sub__HandlesVia__XS_shvxs_string_cmp;
            rp = SHOULD_RETURN_VAL;
            break;
        case 17:
            op = XS_Sub__HandlesVia__XS_shvxs_string_eqi;
            rp = SHOULD_RETURN_VAL;
            break;
        case 18:
            op = XS_Sub__HandlesVia__XS_shvxs_string_nei;
            rp = SHOULD_RETURN_VAL;
            break;
        case 19:
            op = XS_Sub__HandlesVia__XS_shvxs_string_gti;
            rp = SHOULD_RETURN_VAL;
            break;
        case 20:
            op = XS_Sub__HandlesVia__XS_shvxs_string_gei;
            rp = SHOULD_RETURN_VAL;
            break;
        case 21:
            op = XS_Sub__HandlesVia__XS_shvxs_string_lti;
            rp = SHOULD_RETURN_VAL;
            break;
        case 22:
            op = XS_Sub__HandlesVia__XS_shvxs_string_lei;
            rp = SHOULD_RETURN_VAL;
            break;
        case 23:
            op = XS_Sub__HandlesVia__XS_shvxs_string_cmpi;
            rp = SHOULD_RETURN_VAL;
            break;
        default:
            croak("PANIC!");
    }

    shvxs_string_CMP_SIG *sig;
    Newxz(sig, 1, shvxs_string_CMP_SIG);
    UNPACKING_HV_FROM_SV (href, hv);
    UNPACKING_GET_ENUM   (hv, sig, str_source,            ARRAY_SRC_INVOCANT, ArraySource);
    UNPACKING_GET_STRING (hv, sig, str_source_string,     NULL);
    UNPACKING_GET_STRING (hv, sig, str_source_fallback,   NULL);
    UNPACKING_GET_I32    (hv, sig, str_source_index,      0);
    UNPACKING_MAYBE_SV   (hv, sig, curried_sv, has_curried_sv);
    UNPACKING_GET_ENUM   (hv, sig, method_return_pattern, rp, ReturnPattern);
    UNPACKING_GET_STRING (hv, sig, method_return_class,       NULL);
    UNPACKING_GET_STRING (hv, sig, method_return_constructor, NULL);

    CV *cv = newXS( SvPV_nolen(name), op, (char *)__FILE__ );
    CvXSUBANY(cv).any_ptr = sig;
    XSRETURN_EMPTY;
}

#### string : INSTALL(SETTER)

void
INSTALL_shvxs_string_SETTER(SV *name, SV *href)
ALIAS:
    INSTALL_shvxs_string_set         = 1
    INSTALL_shvxs_string_append      = 2
    INSTALL_shvxs_string_prepend     = 3
CODE:
{
    dTHX;

    XSUBADDR_t op;
    enum ReturnPattern rp;
    switch ( ix ) {
        case 1:
            op = XS_Sub__HandlesVia__XS_shvxs_string_set;
            rp = SHOULD_RETURN_STRING;
            break;
        case 2:
            op = XS_Sub__HandlesVia__XS_shvxs_string_append;
            rp = SHOULD_RETURN_STRING;
            break;
        case 3:
            op = XS_Sub__HandlesVia__XS_shvxs_string_prepend;
            rp = SHOULD_RETURN_STRING;
            break;
        default:
            croak("PANIC!");
    }

    shvxs_string_SETTER_SIG *sig;
    Newxz(sig, 1, shvxs_string_SETTER_SIG);
    UNPACKING_HV_FROM_SV (href, hv);
    UNPACKING_GET_ENUM   (hv, sig, str_source,            ARRAY_SRC_INVOCANT, ArraySource);
    UNPACKING_GET_STRING (hv, sig, str_source_string,     NULL);
    UNPACKING_GET_STRING (hv, sig, str_source_fallback,   NULL);
    UNPACKING_GET_I32    (hv, sig, str_source_index,      0);
    UNPACKING_MAYBE_SV   (hv, sig, curried_sv, has_curried_sv);
    UNPACKING_GET_I32    (hv, sig, type,                  TYPE_BASE_ANY);
    UNPACKING_GET_CV     (hv, sig, type_cv);
    UNPACKING_MAYBE_SV   (hv, sig, type_tiny,             has_type_tiny);
    UNPACKING_GET_CV     (hv, sig, coercion_cv);
    UNPACKING_GET_ENUM   (hv, sig, method_return_pattern, rp, ReturnPattern);
    UNPACKING_GET_STRING (hv, sig, method_return_class,       NULL);
    UNPACKING_GET_STRING (hv, sig, method_return_constructor, NULL);

    if (sig->type != TYPE_BASE_ANY && sig->type_cv == NULL) {
        croak("type_cv is required unless type is TYPE_BASE_ANY");
    }

    CV *cv = newXS( SvPV_nolen(name), op, (char *)__FILE__ );
    CvXSUBANY(cv).any_ptr = sig;
    XSRETURN_EMPTY;
}
