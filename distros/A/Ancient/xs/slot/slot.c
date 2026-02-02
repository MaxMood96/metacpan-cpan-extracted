#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "slot_compat.h"

/* PADNAMEf_CONST - compile-time constant flag (0x40 is unused in standard perl) */
#define PADNAMEf_CONST 0x40

/* Custom op support */
static XOP slot_get_xop;
static XOP slot_set_xop;
static XOP slot_watch_xop;
static XOP slot_unwatch_xop;
static XOP slot_unwatch_one_xop;
static XOP slot_clear_xop;

/* Simple SV* registry - just store pointers, manage refcounts */
static SV **g_slots = NULL;
static IV g_slots_size = 0;
static IV g_slots_count = 0;
static char *g_has_watchers = NULL;  /* Quick flag per slot */

/* Mappings */
static HV *g_slot_index = NULL;
static HV *g_slot_names = NULL;
static HV *g_watchers = NULL;

/* Forward declaration */
static void fire_watchers(pTHX_ IV idx, SV *new_val);

/* ============================================
   Custom OP implementations - fastest path
   ============================================ */

static OP* pp_slot_get(pTHX) {
    dSP;
    IV idx = PL_op->op_targ;
#ifdef DEBUGGING
    EXTEND(SP, 1);  /* Ensure stack space - only needed for DEBUGGING builds */
#endif
    PUSHs(g_slots[idx]);
    RETURN;
}

static OP* pp_slot_set(pTHX) {
    dSP;
    IV idx = PL_op->op_targ;
    SV **slot = &g_slots[idx];
    SV *old = *slot;
    SV *new_val = TOPs;  /* Don't pop - just peek and replace */

    *slot = SvREFCNT_inc_simple_NN(new_val);
    SvREFCNT_dec_NN(old);

    if (g_has_watchers[idx]) fire_watchers(aTHX_ idx, new_val);

    /* Value already on stack as result */
    RETURN;
}

/* pp_slot_watch - register watcher, idx in op_targ, callback on stack */
static OP* pp_slot_watch(pTHX) {
    dSP;
    IV idx = PL_op->op_targ;
    SV *callback = POPs;
    char key[32];
    int klen = snprintf(key, sizeof(key), "%ld", (long)idx);
    SV **name_svp = hv_fetch(g_slot_names, key, klen, 0);
    
    if (name_svp) {
        STRLEN name_len;
        const char *name = SvPV(*name_svp, name_len);
        SV **existing = hv_fetch(g_watchers, name, name_len, 0);
        AV *callbacks;
        
        if (existing && SvROK(*existing)) {
            callbacks = (AV*)SvRV(*existing);
        } else {
            callbacks = newAV();
            hv_store(g_watchers, name, name_len, newRV_noinc((SV*)callbacks), 0);
        }
        av_push(callbacks, SvREFCNT_inc(callback));
        g_has_watchers[idx] = 1;
    }
    RETURN;
}

/* pp_slot_unwatch - unregister all watchers, idx in op_targ */
static OP* pp_slot_unwatch(pTHX) {
    IV idx = PL_op->op_targ;
    char key[32];
    int klen = snprintf(key, sizeof(key), "%ld", (long)idx);
    SV **name_svp = hv_fetch(g_slot_names, key, klen, 0);
    
    if (name_svp) {
        STRLEN name_len;
        const char *name = SvPV(*name_svp, name_len);
        hv_delete(g_watchers, name, name_len, G_DISCARD);
        g_has_watchers[idx] = 0;
    }
    return NORMAL;
}

/* pp_slot_unwatch_one - unregister specific watcher, idx in op_targ, callback on stack */
static OP* pp_slot_unwatch_one(pTHX) {
    dSP;
    IV idx = PL_op->op_targ;
    SV *callback = POPs;
    char key[32];
    int klen = snprintf(key, sizeof(key), "%ld", (long)idx);
    SV **name_svp = hv_fetch(g_slot_names, key, klen, 0);
    
    if (name_svp) {
        STRLEN name_len;
        const char *name = SvPV(*name_svp, name_len);
        SV **existing = hv_fetch(g_watchers, name, name_len, 0);
        
        if (existing && SvROK(*existing)) {
            AV *callbacks = (AV*)SvRV(*existing);
            SSize_t i, len = av_len(callbacks);
            for (i = len; i >= 0; i--) {
                SV **cb = av_fetch(callbacks, i, 0);
                if (cb && SvRV(*cb) == SvRV(callback)) {
                    av_delete(callbacks, i, G_DISCARD);
                }
            }
            if (av_len(callbacks) < 0) {
                g_has_watchers[idx] = 0;
            }
        }
    }
    RETURN;
}

/* pp_slot_clear - reset slot to undef and clear watchers, idx in op_targ */
static OP* pp_slot_clear(pTHX) {
    IV idx = PL_op->op_targ;
    SV *old = g_slots[idx];
    char key[32];
    int klen = snprintf(key, sizeof(key), "%ld", (long)idx);
    SV **name_svp = hv_fetch(g_slot_names, key, klen, 0);
    
    g_slots[idx] = &PL_sv_undef;
    SvREFCNT_dec(old);
    
    if (name_svp) {
        STRLEN name_len;
        const char *name = SvPV(*name_svp, name_len);
        hv_delete(g_watchers, name, name_len, G_DISCARD);
    }
    g_has_watchers[idx] = 0;
    
    return NORMAL;
}

/* Call checker - replaces calls with custom ops */
static OP* slot_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    CV *cv = (CV*)ckobj;
    IV idx = CvXSUBANY(cv).any_iv;
    OP *pushop, *cvop, *argop;

    PERL_UNUSED_ARG(namegv);

    /* Get the argument list */
    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    /* Find first real arg (skip pushmark) */
    argop = OpSIBLING(pushop);

    /* Find the cv op (last sibling) */
    cvop = argop;
    while (OpHAS_SIBLING(cvop)) {
        cvop = OpSIBLING(cvop);
    }

    if (argop == cvop) {
        /* No args - getter */
        OP *newop = newOP(OP_CUSTOM, 0);
        newop->op_ppaddr = pp_slot_get;
        newop->op_targ = idx;
        op_free(entersubop);
        return newop;
    } else if (OpSIBLING(argop) == cvop) {
        /* Single arg - setter */
        OP *arg = argop;
        OP *newop;

        /* Detach arg from list */
        OpMORESIB_set(pushop, cvop);
        OpLASTSIB_set(arg, NULL);

        /* Create setter op as unop with arg as child */
        newop = newUNOP(OP_CUSTOM, 0, arg);
        newop->op_ppaddr = pp_slot_set;
        newop->op_targ = idx;

        op_free(entersubop);
        return newop;
    }

    /* Multiple args or complex - fall through to XS */
    return entersubop;
}

/* Call checker for slot::get('constant_name') - optimize to custom op
 * Detects both literal strings and const::c() variables (via PADNAMEf_CONST) */
static OP* slot_get_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    OP *pushop, *cvop, *argop;
    SV *namesv = NULL;
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }
    argop = OpSIBLING(pushop);
    cvop = argop;
    while (OpHAS_SIBLING(cvop)) {
        cvop = OpSIBLING(cvop);
    }

    /* Must be single argument */
    if (argop == cvop || OpSIBLING(argop) != cvop)
        return entersubop;

    /* Check for literal string constant (OP_CONST) */
    if (argop->op_type == OP_CONST) {
        namesv = cSVOPx(argop)->op_sv;
    }
    /* Check for const::c() variable (OP_PADSV with PADNAMEf_CONST flag) */
    else if (argop->op_type == OP_PADSV) {
        PADOFFSET po = argop->op_targ;
        if (PL_comppad_name && po < PadnamelistMAX(PL_comppad_name) + 1) {
            PADNAME *pn = PadnamelistARRAY(PL_comppad_name)[po];
            if (pn && (PadnameFLAGS(pn) & PADNAMEf_CONST)) {
                /* Has our const flag - get value from compilation pad */
                if (PL_comppad) {
                    SV **svp = av_fetch(PL_comppad, po, 0);
                    if (svp && SvPOK(*svp)) {
                        namesv = *svp;
                    }
                }
            }
        }
    }

    /* If we got a slot name, optimize to custom op */
    if (namesv && SvPOK(namesv)) {
        STRLEN name_len;
        const char *name = SvPV(namesv, name_len);
        SV **svp = hv_fetch(g_slot_index, name, name_len, 0);
        if (svp) {
            IV idx = SvIV(*svp);
            OP *newop = newOP(OP_CUSTOM, 0);
            newop->op_ppaddr = pp_slot_get;
            newop->op_targ = idx;
            op_free(entersubop);
            return newop;
        }
    }
    return entersubop;
}

/* Call checker for slot::set('constant_name', $val) - optimize to custom op
 * Detects both literal strings and const::c() variables (via PADNAMEf_CONST) */
static OP* slot_set_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    OP *pushop, *cvop, *argop, *valop;
    SV *namesv = NULL;
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }
    argop = OpSIBLING(pushop);
    cvop = argop;
    while (OpHAS_SIBLING(cvop)) {
        cvop = OpSIBLING(cvop);
    }

    /* Must be two args */
    valop = OpSIBLING(argop);
    if (argop == cvop || !valop || valop == cvop || OpSIBLING(valop) != cvop)
        return entersubop;

    /* Check for literal string constant (OP_CONST) */
    if (argop->op_type == OP_CONST) {
        namesv = cSVOPx(argop)->op_sv;
    }
    /* Check for const::c() variable (OP_PADSV with PADNAMEf_CONST flag) */
    else if (argop->op_type == OP_PADSV) {
        PADOFFSET po = argop->op_targ;
        if (PL_comppad_name && po < PadnamelistMAX(PL_comppad_name) + 1) {
            PADNAME *pn = PadnamelistARRAY(PL_comppad_name)[po];
            if (pn && (PadnameFLAGS(pn) & PADNAMEf_CONST)) {
                if (PL_comppad) {
                    SV **svp = av_fetch(PL_comppad, po, 0);
                    if (svp && SvPOK(*svp)) {
                        namesv = *svp;
                    }
                }
            }
        }
    }

    /* If we got a slot name, optimize to custom op */
    if (namesv && SvPOK(namesv)) {
        STRLEN name_len;
        const char *name = SvPV(namesv, name_len);
        SV **svp = hv_fetch(g_slot_index, name, name_len, 0);
        if (svp) {
            IV idx = SvIV(*svp);
            OP *newop;

            /* Detach value arg from list */
            OpMORESIB_set(pushop, cvop);
            OpLASTSIB_set(valop, NULL);

            newop = newUNOP(OP_CUSTOM, 0, valop);
            newop->op_ppaddr = pp_slot_set;
            newop->op_targ = idx;
            op_free(entersubop);
            return newop;
        }
    }
    return entersubop;
}

/* Call checker for slot::index('constant_name') - fold to constant */
static OP* slot_index_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    OP *pushop, *cvop, *argop;
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }
    argop = OpSIBLING(pushop);
    cvop = argop;
    while (OpHAS_SIBLING(cvop)) {
        cvop = OpSIBLING(cvop);
    }

    /* Check if single constant string argument */
    if (argop != cvop && OpSIBLING(argop) == cvop && argop->op_type == OP_CONST) {
        SV *namesv = cSVOPx(argop)->op_sv;
        if (SvPOK(namesv)) {
            STRLEN name_len;
            const char *name = SvPV(namesv, name_len);
            SV **svp = hv_fetch(g_slot_index, name, name_len, 0);
            if (svp) {
                IV idx = SvIV(*svp);
                OP *newop = newSVOP(OP_CONST, 0, newSViv(idx));
                op_free(entersubop);
                return newop;
            }
        }
    }
    return entersubop;
}

/* Call checker for slot::watch('constant_name', $callback) */
static OP* slot_watch_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    OP *pushop, *cvop, *argop, *cbop;
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }
    argop = OpSIBLING(pushop);
    cvop = argop;
    while (OpHAS_SIBLING(cvop)) {
        cvop = OpSIBLING(cvop);
    }

    /* Check if two args, first is constant string */
    cbop = OpSIBLING(argop);
    if (argop != cvop && cbop && cbop != cvop && OpSIBLING(cbop) == cvop 
        && argop->op_type == OP_CONST) {
        SV *namesv = cSVOPx(argop)->op_sv;
        if (SvPOK(namesv)) {
            STRLEN name_len;
            const char *name = SvPV(namesv, name_len);
            SV **svp = hv_fetch(g_slot_index, name, name_len, 0);
            if (svp) {
                IV idx = SvIV(*svp);
                OP *newop;
                
                /* Detach callback arg from list */
                OpMORESIB_set(pushop, cvop);
                OpLASTSIB_set(cbop, NULL);
                
                newop = newUNOP(OP_CUSTOM, 0, cbop);
                newop->op_ppaddr = pp_slot_watch;
                newop->op_targ = idx;
                op_free(entersubop);
                return newop;
            }
        }
    }
    return entersubop;
}

/* Call checker for slot::unwatch('constant_name') or slot::unwatch('constant_name', $cb) */
static OP* slot_unwatch_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    OP *pushop, *cvop, *argop, *cbop;
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }
    argop = OpSIBLING(pushop);
    cvop = argop;
    while (OpHAS_SIBLING(cvop)) {
        cvop = OpSIBLING(cvop);
    }

    /* Check if first arg is constant string */
    if (argop != cvop && argop->op_type == OP_CONST) {
        SV *namesv = cSVOPx(argop)->op_sv;
        if (SvPOK(namesv)) {
            STRLEN name_len;
            const char *name = SvPV(namesv, name_len);
            SV **svp = hv_fetch(g_slot_index, name, name_len, 0);
            if (svp) {
                IV idx = SvIV(*svp);
                cbop = OpSIBLING(argop);
                
                if (cbop == cvop) {
                    /* Single arg - unwatch all */
                    OP *newop = newOP(OP_CUSTOM, 0);
                    newop->op_ppaddr = pp_slot_unwatch;
                    newop->op_targ = idx;
                    op_free(entersubop);
                    return newop;
                } else if (OpSIBLING(cbop) == cvop) {
                    /* Two args - unwatch specific callback */
                    OP *newop;
                    OpMORESIB_set(pushop, cvop);
                    OpLASTSIB_set(cbop, NULL);
                    
                    newop = newUNOP(OP_CUSTOM, 0, cbop);
                    newop->op_ppaddr = pp_slot_unwatch_one;
                    newop->op_targ = idx;
                    op_free(entersubop);
                    return newop;
                }
            }
        }
    }
    return entersubop;
}

/* Call checker for slot::clear('constant_name') */
static OP* slot_clear_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    OP *pushop, *cvop, *argop;
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }
    argop = OpSIBLING(pushop);
    cvop = argop;
    while (OpHAS_SIBLING(cvop)) {
        cvop = OpSIBLING(cvop);
    }

    /* Check if single constant string argument */
    if (argop != cvop && OpSIBLING(argop) == cvop && argop->op_type == OP_CONST) {
        SV *namesv = cSVOPx(argop)->op_sv;
        if (SvPOK(namesv)) {
            STRLEN name_len;
            const char *name = SvPV(namesv, name_len);
            SV **svp = hv_fetch(g_slot_index, name, name_len, 0);
            if (svp) {
                IV idx = SvIV(*svp);
                OP *newop = newOP(OP_CUSTOM, 0);
                newop->op_ppaddr = pp_slot_clear;
                newop->op_targ = idx;
                op_free(entersubop);
                return newop;
            }
        }
    }
    return entersubop;
}

/* ============================================
   XS Accessor - fallback for dynamic calls
   ============================================ */

static XS(xs_slot_accessor) {
    dXSARGS;
    IV idx = CvXSUBANY(cv).any_iv;
    SV **slot = &g_slots[idx];

    if (items) {
        SV *old = *slot;
        SV *new_val = ST(0);
        *slot = SvREFCNT_inc_simple_NN(new_val);
        SvREFCNT_dec_NN(old);
        if (g_has_watchers[idx]) fire_watchers(aTHX_ idx, new_val);
        ST(0) = new_val;
        XSRETURN(1);
    }
    ST(0) = *slot;
    XSRETURN(1);
}

/* ============================================
   Watchers
   ============================================ */

static void fire_watchers(pTHX_ IV idx, SV *new_val) {
    char key[32];
    int klen = snprintf(key, sizeof(key), "%ld", (long)idx);
    SV **name_sv = hv_fetch(g_slot_names, key, klen, 0);

    if (!name_sv || !SvOK(*name_sv)) return;

    STRLEN name_len;
    const char *name = SvPV(*name_sv, name_len);
    SV **svp = hv_fetch(g_watchers, name, name_len, 0);

    if (svp && SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVAV) {
        AV *callbacks = (AV*)SvRV(*svp);
        SSize_t i, len = av_len(callbacks);
        for (i = 0; i <= len; i++) {
            SV **cb = av_fetch(callbacks, i, 0);
            if (cb && SvROK(*cb)) {
                dSP;
                ENTER; SAVETMPS;
                PUSHMARK(SP);
                mXPUSHs(newSVpvn(name, name_len));
                XPUSHs(new_val);
                PUTBACK;
                call_sv(*cb, G_DISCARD);
                FREETMPS; LEAVE;
            }
        }
    }
}

/* ============================================
   Slot management
   ============================================ */

static void ensure_slot_capacity(IV needed) {
    if (needed >= g_slots_size) {
        IV new_size = g_slots_size ? g_slots_size * 2 : 16;
        IV i;
        while (new_size <= needed) new_size *= 2;
        Renew(g_slots, new_size, SV*);
        Renew(g_has_watchers, new_size, char);
        for (i = g_slots_size; i < new_size; i++) {
            g_slots[i] = &PL_sv_undef;
            g_has_watchers[i] = 0;
        }
        g_slots_size = new_size;
    }
}

static IV create_slot(pTHX_ const char *name, STRLEN name_len) {
    IV idx = g_slots_count++;
    char key[32];
    int klen;

    ensure_slot_capacity(idx);
    hv_store(g_slot_index, name, name_len, newSViv(idx), 0);
    klen = snprintf(key, sizeof(key), "%ld", (long)idx);
    hv_store(g_slot_names, key, klen, newSVpvn(name, name_len), 0);

    return idx;
}

static char* get_caller(pTHX) {
    return HvNAME((HV*)CopSTASH(PL_curcop));
}

static void install_accessor(pTHX_ const char *pkg, const char *name, IV idx) {
    char full[512];
    CV *cv;

    snprintf(full, sizeof(full), "%s::%s", pkg, name);
    cv = newXS(full, xs_slot_accessor, __FILE__);
    CvXSUBANY(cv).any_iv = idx;

    /* Install call checker for custom op optimization */
    cv_set_call_checker(cv, slot_call_checker, (SV*)cv);
}

static XS(xs_import) {
    dXSARGS;
    char *pkg = get_caller(aTHX);
    int i;

    for (i = 1; i < items; i++) {
        char *name = SvPV_nolen(ST(i));
        STRLEN name_len = SvCUR(ST(i));
        IV idx;
        SV **existing;

        existing = hv_fetch(g_slot_index, name, name_len, 0);
        if (existing) {
            idx = SvIV(*existing);
        } else {
            idx = create_slot(aTHX_ name, name_len);
        }
        install_accessor(aTHX_ pkg, name, idx);
    }
    XSRETURN_EMPTY;
}

/* ============================================
   Watch/unwatch API
   ============================================ */

static XS(xs_watch) {
    dXSARGS;
    if (items < 2) croak("Usage: slot::watch($name, $callback)");

    char *name = SvPV_nolen(ST(0));
    STRLEN name_len = SvCUR(ST(0));
    SV *callback = ST(1);
    SV **existing;
    AV *callbacks;
    SV **idx_sv;

    existing = hv_fetch(g_watchers, name, name_len, 0);
    if (existing && SvROK(*existing)) {
        callbacks = (AV*)SvRV(*existing);
    } else {
        callbacks = newAV();
        hv_store(g_watchers, name, name_len, newRV_noinc((SV*)callbacks), 0);
    }
    av_push(callbacks, SvREFCNT_inc(callback));

    /* Set the has_watchers flag for fast path */
    idx_sv = hv_fetch(g_slot_index, name, name_len, 0);
    if (idx_sv) {
        g_has_watchers[SvIV(*idx_sv)] = 1;
    }

    XSRETURN_EMPTY;
}

static XS(xs_unwatch) {
    dXSARGS;
    if (items < 1) croak("Usage: slot::unwatch($name, [$callback])");

    char *name = SvPV_nolen(ST(0));
    STRLEN name_len = SvCUR(ST(0));
    SV **idx_sv;
    int clear_flag = 0;

    if (items == 1) {
        hv_delete(g_watchers, name, name_len, G_DISCARD);
        clear_flag = 1;
    } else {
        SV *callback = ST(1);
        SV **existing = hv_fetch(g_watchers, name, name_len, 0);
        if (existing && SvROK(*existing)) {
            AV *callbacks = (AV*)SvRV(*existing);
            SSize_t i, len = av_len(callbacks);
            for (i = len; i >= 0; i--) {
                SV **cb = av_fetch(callbacks, i, 0);
                if (cb && SvRV(*cb) == SvRV(callback)) {
                    av_delete(callbacks, i, G_DISCARD);
                }
            }
            /* Check if all watchers removed */
            if (av_len(callbacks) < 0) {
                clear_flag = 1;
            }
        }
    }

    /* Clear the has_watchers flag if no watchers left */
    if (clear_flag) {
        idx_sv = hv_fetch(g_slot_index, name, name_len, 0);
        if (idx_sv) {
            g_has_watchers[SvIV(*idx_sv)] = 0;
        }
    }

    XSRETURN_EMPTY;
}

/* slot::index - get numeric index for a slot (for fast access) */
static XS(xs_index) {
    dXSARGS;
    if (items < 1) XSRETURN_UNDEF;
    STRLEN name_len;
    const char *name = SvPV(ST(0), name_len);
    SV **svp = hv_fetch(g_slot_index, name, name_len, 0);
    if (svp) {
        ST(0) = *svp;
        XSRETURN(1);
    }
    XSRETURN_UNDEF;
}

/* slot::get_by_idx - O(1) direct array access, no hash lookup */
static XS(xs_get_by_idx) {
    dXSARGS;
    if (items < 1) XSRETURN_UNDEF;
    IV idx = SvIV(ST(0));
    if (idx >= 0 && idx < g_slots_count) {
        ST(0) = g_slots[idx];
        XSRETURN(1);
    }
    XSRETURN_UNDEF;
}

/* slot::set_by_idx - O(1) direct array access, no hash lookup */
static XS(xs_set_by_idx) {
    dXSARGS;
    if (items < 2) XSRETURN_EMPTY;
    IV idx = SvIV(ST(0));
    if (idx >= 0 && idx < g_slots_count) {
        SV *old = g_slots[idx];
        g_slots[idx] = SvREFCNT_inc(ST(1));
        SvREFCNT_dec(old);
        if (g_has_watchers[idx]) fire_watchers(aTHX_ idx, g_slots[idx]);
        ST(0) = g_slots[idx];
        XSRETURN(1);
    }
    XSRETURN_EMPTY;
}

static XS(xs_get) {
    dXSARGS;
    if (items < 1) XSRETURN_UNDEF;
    STRLEN name_len;
    const char *name = SvPV(ST(0), name_len);
    SV **svp = hv_fetch(g_slot_index, name, name_len, 0);
    if (svp) {
        ST(0) = g_slots[SvIV(*svp)];
        XSRETURN(1);
    }
    XSRETURN_UNDEF;
}

static XS(xs_set) {
    dXSARGS;
    if (items < 2) XSRETURN_EMPTY;
    STRLEN name_len;
    const char *name = SvPV(ST(0), name_len);
    SV **svp = hv_fetch(g_slot_index, name, name_len, 0);
    if (svp) {
        IV idx = SvIV(*svp);
        SV *old = g_slots[idx];
        g_slots[idx] = SvREFCNT_inc(ST(1));
        SvREFCNT_dec(old);
        ST(0) = g_slots[idx];
        XSRETURN(1);
    }
    XSRETURN_EMPTY;
}

/* slot::add - create slot(s) without installing accessors (fastest path) */
static XS(xs_add) {
    dXSARGS;
    int i;
    for (i = 0; i < items; i++) {
        STRLEN name_len;
        const char *name = SvPV(ST(i), name_len);
        /* Only create if doesn't exist */
        if (!hv_fetch(g_slot_index, name, name_len, 0)) {
            create_slot(aTHX_ name, name_len);
        }
    }
    XSRETURN_EMPTY;
}

static XS(xs_slots) {
    dXSARGS;
    HE *entry;
    PERL_UNUSED_VAR(items);
    SP -= items;
    hv_iterinit(g_slot_index);
    while ((entry = hv_iternext(g_slot_index))) {
        XPUSHs(hv_iterkeysv(entry));
    }
    PUTBACK;
    return;
}

/* slot::exists - check if slot is defined */
static XS(xs_exists) {
    dXSARGS;
    STRLEN name_len;
    const char *name;
    if (items != 1) croak("Usage: slot::exists($name)");
    name = SvPV(ST(0), name_len);
    if (hv_exists(g_slot_index, name, name_len)) {
        XSRETURN_YES;
    }
    XSRETURN_NO;
}

/* slot::clear - reset slot value to undef and clear watchers */
static XS(xs_clear) {
    dXSARGS;
    int i;
    for (i = 0; i < items; i++) {
        STRLEN name_len;
        const char *name = SvPV(ST(i), name_len);
        SV **svp = hv_fetch(g_slot_index, name, name_len, 0);
        if (svp) {
            IV idx = SvIV(*svp);
            SV *old = g_slots[idx];
            /* Reset to undef */
            g_slots[idx] = &PL_sv_undef;
            SvREFCNT_dec(old);
            /* Clear watchers */
            hv_delete(g_watchers, name, name_len, G_DISCARD);
            g_has_watchers[idx] = 0;
        }
    }
    XSRETURN_EMPTY;
}

/* slot::clear_by_idx - reset slot value to undef and clear watchers by index */
static XS(xs_clear_by_idx) {
    dXSARGS;
    int i;
    for (i = 0; i < items; i++) {
        IV idx = SvIV(ST(i));
        if (idx >= 0 && idx < g_slots_count) {
            SV *old = g_slots[idx];
            char key[32];
            int klen;
            SV **name_sv;

            /* Reset to undef */
            g_slots[idx] = &PL_sv_undef;
            SvREFCNT_dec(old);

            /* Clear watchers - need to look up name from idx */
            klen = snprintf(key, sizeof(key), "%ld", (long)idx);
            name_sv = hv_fetch(g_slot_names, key, klen, 0);
            if (name_sv && SvOK(*name_sv)) {
                STRLEN name_len;
                const char *name = SvPV(*name_sv, name_len);
                hv_delete(g_watchers, name, name_len, G_DISCARD);
            }
            g_has_watchers[idx] = 0;
        }
    }
    XSRETURN_EMPTY;
}

/* ============================================
   Boot
   ============================================ */

XS_EXTERNAL(boot_slot) {
    dXSBOOTARGSXSAPIVERCHK;
    PERL_UNUSED_VAR(items);

    /* Register custom ops */
    XopENTRY_set(&slot_get_xop, xop_name, "slot_get");
    XopENTRY_set(&slot_get_xop, xop_desc, "slot getter");
    Perl_custom_op_register(aTHX_ pp_slot_get, &slot_get_xop);

    XopENTRY_set(&slot_set_xop, xop_name, "slot_set");
    XopENTRY_set(&slot_set_xop, xop_desc, "slot setter");
    Perl_custom_op_register(aTHX_ pp_slot_set, &slot_set_xop);

    XopENTRY_set(&slot_watch_xop, xop_name, "slot_watch");
    XopENTRY_set(&slot_watch_xop, xop_desc, "slot watcher registration");
    Perl_custom_op_register(aTHX_ pp_slot_watch, &slot_watch_xop);

    XopENTRY_set(&slot_unwatch_xop, xop_name, "slot_unwatch");
    XopENTRY_set(&slot_unwatch_xop, xop_desc, "slot unwatch all");
    Perl_custom_op_register(aTHX_ pp_slot_unwatch, &slot_unwatch_xop);

    XopENTRY_set(&slot_unwatch_one_xop, xop_name, "slot_unwatch_one");
    XopENTRY_set(&slot_unwatch_one_xop, xop_desc, "slot unwatch specific");
    Perl_custom_op_register(aTHX_ pp_slot_unwatch_one, &slot_unwatch_one_xop);

    XopENTRY_set(&slot_clear_xop, xop_name, "slot_clear");
    XopENTRY_set(&slot_clear_xop, xop_desc, "slot clear");
    Perl_custom_op_register(aTHX_ pp_slot_clear, &slot_clear_xop);

    g_slot_index = newHV();
    g_slot_names = newHV();
    g_watchers = newHV();

    g_slots_size = 16;
    Newx(g_slots, g_slots_size, SV*);
    Newxz(g_has_watchers, g_slots_size, char);
    {
        IV i;
        for (i = 0; i < g_slots_size; i++) {
            g_slots[i] = &PL_sv_undef;
        }
    }

    newXS("slot::import", xs_import, __FILE__);
    newXS("slot::add", xs_add, __FILE__);
    {
        CV *cv = newXS("slot::index", xs_index, __FILE__);
        cv_set_call_checker(cv, slot_index_call_checker, (SV*)cv);
    }
    {
        CV *cv = newXS("slot::get", xs_get, __FILE__);
        cv_set_call_checker(cv, slot_get_call_checker, (SV*)cv);
    }
    {
        CV *cv = newXS("slot::set", xs_set, __FILE__);
        cv_set_call_checker(cv, slot_set_call_checker, (SV*)cv);
    }
    newXS("slot::get_by_idx", xs_get_by_idx, __FILE__);
    newXS("slot::set_by_idx", xs_set_by_idx, __FILE__);
    {
        CV *cv = newXS("slot::watch", xs_watch, __FILE__);
        cv_set_call_checker(cv, slot_watch_call_checker, (SV*)cv);
    }
    {
        CV *cv = newXS("slot::unwatch", xs_unwatch, __FILE__);
        cv_set_call_checker(cv, slot_unwatch_call_checker, (SV*)cv);
    }
    newXS("slot::slots", xs_slots, __FILE__);
    newXS("slot::exists", xs_exists, __FILE__);
    {
        CV *cv = newXS("slot::clear", xs_clear, __FILE__);
        cv_set_call_checker(cv, slot_clear_call_checker, (SV*)cv);
    }
    newXS("slot::clear_by_idx", xs_clear_by_idx, __FILE__);

    Perl_xs_boot_epilog(aTHX_ ax);
}
