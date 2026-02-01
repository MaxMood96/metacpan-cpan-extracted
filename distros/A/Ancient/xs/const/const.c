/*
 * const.c - Fast constants with compile-time optimization
 *
 * Provides:
 *   c($val)              - create readonly scalar (optimized via custom op)
 *   const($var, $val)    - set variable readonly (like Const::XS)
 *   make_readonly($var)  - deeply make readonly
 *   unmake_readonly($var) - deeply make writable
 *   is_readonly($var)    - check if readonly
 *
 * The c() function is special: it sets PADNAMEf_CONST (0x40) on the target
 * variable's pad entry at compile time. This flag allows other modules'
 * call checkers (e.g., slot::get) to detect compile-time constants and
 * optimize calls like slot::get($name) to direct array access.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "const_compat.h"

/* Custom op support */
static XOP const_c_xop;
static XOP confold_marker_xop;

/* Original ck_sassign - we'll wrap it */
static Perl_check_t orig_ck_sassign;

/* Our const flag - 0x40 is unused in standard perl */
#define PADNAMEf_CONST 0x40

/* Forward declarations */
static OP* pp_confold_marker(pTHX);
static OP* my_ck_sassign(pTHX_ OP *o);

/* ============================================
   Deep readonly/readwrite helpers
   ============================================ */

static void _make_readonly(pTHX_ SV *val) {
    /* Handle the value directly first if it's an AV or HV */
    if (SvTYPE(val) == SVt_PVAV) {
        AV *arr = (AV*)val;
        if (!SvREADONLY((SV*)arr)) {
            SSize_t i, len = av_len(arr);
            SvREADONLY_on((SV*)arr);
            for (i = 0; i <= len; i++) {
                SV **svp = av_fetch(arr, i, 0);
                if (svp) _make_readonly(aTHX_ *svp);
            }
        }
        return;
    } else if (SvTYPE(val) == SVt_PVHV) {
        HV *hash = (HV*)val;
        if (!SvREADONLY((SV*)hash)) {
            HE *entry;
            SvREADONLY_on((SV*)hash);
            hv_iterinit(hash);
            while ((entry = hv_iternext(hash))) {
                SV *value = hv_iterval(hash, entry);
                _make_readonly(aTHX_ value);
            }
        }
        return;
    }
    
    /* Handle references - recurse into what they point to */
    if (SvROK(val)) {
        _make_readonly(aTHX_ SvRV(val));
    }
    
    SvREADONLY_on(val);
}

static void _make_readwrite(pTHX_ SV *val) {
    /* Handle the value directly first if it's an AV or HV */
    if (SvTYPE(val) == SVt_PVAV) {
        AV *arr = (AV*)val;
        if (SvREADONLY((SV*)arr)) {
            SSize_t i, len = av_len(arr);
            SvREADONLY_off((SV*)arr);
            for (i = 0; i <= len; i++) {
                SV **svp = av_fetch(arr, i, 0);
                if (svp) _make_readwrite(aTHX_ *svp);
            }
        }
        return;
    } else if (SvTYPE(val) == SVt_PVHV) {
        HV *hash = (HV*)val;
        if (SvREADONLY((SV*)hash)) {
            HE *entry;
            SvREADONLY_off((SV*)hash);
            hv_iterinit(hash);
            while ((entry = hv_iternext(hash))) {
                SV *value = hv_iterval(hash, entry);
                _make_readwrite(aTHX_ value);
            }
        }
        return;
    }
    
    /* Handle references - recurse into what they point to */
    if (SvROK(val)) {
        _make_readwrite(aTHX_ SvRV(val));
    }
    
    SvREADONLY_off(val);
}

PERL_STATIC_INLINE int _is_readonly(SV *val) {
    if (SvROK(val)) {
        SV *rv = SvRV(val);
        svtype t = SvTYPE(rv);
        if (t == SVt_PVAV || t == SVt_PVHV) {
            if (!SvREADONLY(rv)) return 0;
        }
    }
    return SvREADONLY(val) ? 1 : 0;
}

/* ============================================
   Custom OP for c() - constant value access
   ============================================ */

/*
 * pp_const_c - custom op that pushes a pre-computed readonly SV
 * The SV is stored in op_targ area via cSVOP_sv
 */
static OP* pp_const_c(pTHX) {
    dSP;
    /* Use op_sv for the constant value */
    XPUSHs(cSVOPx_sv(PL_op));
    RETURN;
}

/*
 * pp_confold_marker - Custom op that acts like OP_CONST but can be
 * detected by our wrapped ck_sassign to set PADNAMEf_CONST.
 * At runtime, it just pushes the stored SV onto the stack.
 */
static OP* pp_confold_marker(pTHX) {
    dSP;
    XPUSHs(cSVOPx_sv(PL_op));
    RETURN;
}

/*
 * my_ck_sassign - Wrapped check function for OP_SASSIGN.
 * Detects when RHS is our confold_marker custom op and sets
 * PADNAMEf_CONST (0x40) on the target pad entry.
 */
static OP* my_ck_sassign(pTHX_ OP *o) {
    OP *rhs, *lhs;

    /* Get the operands - sassign is: lhs = rhs becomes sassign(rhs, lhs) */
    /* In the op tree: first child is RHS, last/sibling is LHS */
    if (!(o->op_flags & OPf_KIDS))
        goto call_orig;

    rhs = cBINOPo->op_first;
    if (!rhs)
        goto call_orig;

    lhs = OpSIBLING(rhs);
    if (!lhs)
        goto call_orig;

    /* Check if RHS is our confold_marker custom op */
    if (rhs->op_type == OP_CUSTOM && rhs->op_ppaddr == pp_confold_marker) {
        /* Check if LHS is a simple pad variable (padsv) */
        /* Handle the case where LHS might be wrapped in other ops */
        OP *target = lhs;

        /* Skip through any wrapper ops to find padsv */
        while (target && target->op_type != OP_PADSV) {
            if (target->op_flags & OPf_KIDS) {
                target = cUNOPx(target)->op_first;
            } else {
                target = NULL;
            }
        }

        if (target && target->op_type == OP_PADSV) {
            PADOFFSET po = target->op_targ;

            /* Access the pad name and set our const flag */
            if (PL_comppad_name && po < PadnamelistMAX(PL_comppad_name) + 1) {
                PADNAME *pn = PadnamelistARRAY(PL_comppad_name)[po];
                if (pn) {
                    /* Set the const flag */
                    PadnameFLAGS(pn) |= PADNAMEf_CONST;

                    /* Store the constant value in the pad */
                    SV *constval = cSVOPx_sv(rhs);
                    if (constval && PL_comppad) {
                        SV **svp = av_fetch(PL_comppad, po, 1);
                        if (svp) {
                            sv_setsv(*svp, constval);
                        }
                    }
                }
            }
        }

        /* Convert our custom op to a regular OP_CONST for runtime */
        rhs->op_type = OP_CONST;
        rhs->op_ppaddr = PL_ppaddr[OP_CONST];
    }

call_orig:
    return orig_ck_sassign(aTHX_ o);
}

/* ============================================
   Call checker for c() - constant folding
   ============================================ */

static OP* const_c_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    OP *pushop, *cvop, *argop;
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    /* Navigate the op tree to find arguments */
    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    /* First arg after pushmark */
    argop = OpSIBLING(pushop);

    /* Find cv op (last sibling) */
    cvop = argop;
    while (OpHAS_SIBLING(cvop)) {
        cvop = OpSIBLING(cvop);
    }

    /* Check if single constant argument */
    if (argop != cvop && OpSIBLING(argop) == cvop) {
        /* We have exactly one argument */
        if (argop->op_type == OP_CONST) {
            /* Constant argument - replace entire call with our custom
             * confold_marker op. This allows my_ck_sassign to detect it
             * and set PADNAMEf_CONST on the target pad entry. */
            SV *val = cSVOPx_sv(argop);
            SV *newval = newSVsv(val);
            OP *markerop;

            /* Make it deeply readonly if it's a reference */
            if (SvROK(newval)) {
                _make_readonly(aTHX_ SvRV(newval));
            }
            SvREADONLY_on(newval);

            /* Create a custom op that looks like SVOP but uses our pp func */
            markerop = newSVOP(OP_CUSTOM, 0, newval);
            markerop->op_ppaddr = pp_confold_marker;

            op_free(entersubop);
            return markerop;
        }
        /* Non-constant arg - fall through to XS for runtime evaluation */
    }

    /* Fall through to XS implementation */
    return entersubop;
}

/* ============================================
   XS Functions
   ============================================ */

XS_EXTERNAL(XS_const_c);
XS_EXTERNAL(XS_const_c) {
    dXSARGS;
    SV *val, *result;

    if (items != 1) {
        croak("Usage: const::c(VALUE)");
    }

    val = ST(0);

    /* Create a copy and make it readonly */
    if (SvROK(val)) {
        /* For refs, make deep copy and make deeply readonly */
        result = newSVsv(val);
        _make_readonly(aTHX_ SvRV(result));
        SvREADONLY_on(result);
    } else {
        result = newSVsv(val);
        SvREADONLY_on(result);
    }

    /* Return mortal - caller's assignment will increase refcount */
    ST(0) = sv_2mortal(result);
    XSRETURN(1);
}

/* const() uses prototype \[$@%]@ to get reference to target variable */
XS_EXTERNAL(XS_const_const);
XS_EXTERNAL(XS_const_const) {
    dXSARGS;
    SV *ref;
    int type;
    int i;

    if (items < 2) {
        croak("No value for readonly variable");
    }

    ref = ST(0);
    if (!SvROK(ref)) {
        croak("First argument must be a reference (use: const my $x => value)");
    }

    type = SvTYPE(SvRV(ref));

    if (type == SVt_PVAV) {
        AV *arr = (AV*)SvRV(ref);
        for (i = 1; i < items; i++) {
            SV *val = newSVsv(ST(i));
            av_push(arr, val);
        }
        /* Make readonly directly on the array, then the ref */
        _make_readonly(aTHX_ (SV*)arr);
        SvREADONLY_on(ref);
    } else if (type == SVt_PVHV) {
        HV *hash = (HV*)SvRV(ref);
        if ((items - 1) % 2 != 0) {
            croak("Odd number of elements in hash assignment");
        }
        for (i = 1; i < items; i += 2) {
            STRLEN klen;
            const char *key = SvPV(ST(i), klen);
            hv_store(hash, key, klen, newSVsv(ST(i+1)), 0);
        }
        /* Make readonly directly on the hash, then the ref */
        _make_readonly(aTHX_ (SV*)hash);
        SvREADONLY_on(ref);
    } else {
        /* Scalar */
        SV *target = SvRV(ref);
        sv_setsv(target, ST(1));
        _make_readonly(aTHX_ target);
    }

    ST(0) = ref;
    XSRETURN(1);
}

XS_EXTERNAL(XS_const_make_readonly);
XS_EXTERNAL(XS_const_make_readonly) {
    dXSARGS;
    SV *ref;
    int type;

    if (items != 1) {
        croak("Usage: const::make_readonly(\\$var)");
    }

    ref = ST(0);
    if (!SvROK(ref)) {
        croak("Argument must be a reference");
    }

    type = SvTYPE(SvRV(ref));
    if (type == SVt_PVAV || type == SVt_PVHV) {
        _make_readonly(aTHX_ ref);
    } else {
        _make_readonly(aTHX_ SvRV(ref));
    }

    XSRETURN(1);
}

XS_EXTERNAL(XS_const_make_readonly_ref);
XS_EXTERNAL(XS_const_make_readonly_ref) {
    dXSARGS;

    if (items != 1) {
        croak("Usage: const::make_readonly_ref($ref)");
    }

    _make_readonly(aTHX_ ST(0));
    XSRETURN(1);
}

XS_EXTERNAL(XS_const_unmake_readonly);
XS_EXTERNAL(XS_const_unmake_readonly) {
    dXSARGS;
    SV *ref;
    int type;

    if (items != 1) {
        croak("Usage: const::unmake_readonly(\\$var)");
    }

    ref = ST(0);
    if (!SvROK(ref)) {
        croak("Argument must be a reference");
    }

    type = SvTYPE(SvRV(ref));
    if (type == SVt_PVAV || type == SVt_PVHV) {
        _make_readwrite(aTHX_ ref);
    } else {
        _make_readwrite(aTHX_ SvRV(ref));
    }

    XSRETURN(1);
}

XS_EXTERNAL(XS_const_is_readonly);
XS_EXTERNAL(XS_const_is_readonly) {
    dXSARGS;
    SV *ref;

    if (items != 1) {
        croak("Usage: const::is_readonly(\\$var)");
    }

    ref = ST(0);
    if (!SvROK(ref)) {
        croak("Argument must be a reference");
    }

    ST(0) = sv_2mortal(newSViv(_is_readonly(SvRV(ref))));
    XSRETURN(1);
}

/* Helper to export with prototype */
static void export_proto(pTHX_ XSUBADDR_t cb, const char *pkg, const char *method, const char *proto) {
    char name[256];
    snprintf(name, sizeof(name), "%s::%s", pkg, method);
    newXSproto(name, cb, __FILE__, proto);
}

/* Helper to export without prototype */
static void export_noproto(pTHX_ XSUBADDR_t cb, const char *pkg, const char *method) {
    char name[256];
    snprintf(name, sizeof(name), "%s::%s", pkg, method);
    newXS(name, cb, __FILE__);
}

/* Import handler - export functions to caller's package */
XS_EXTERNAL(XS_const_import);
XS_EXTERNAL(XS_const_import) {
    dXSARGS;
    const char *pkg;
    STRLEN retlen;
    int i;

    /* Get caller's package name like Const::XS does */
    pkg = HvNAME((HV*)CopSTASH(PL_curcop));

    /* Check for 'all' or specific function names */
    for (i = 1; i < items; i++) {
        const char *ex = SvPV(ST(i), retlen);
        if (strEQ(ex, "all") || strEQ(ex, ":all")) {
            export_proto(aTHX_ XS_const_const, pkg, "const", "\\[$@%]@");
            export_proto(aTHX_ XS_const_make_readonly, pkg, "make_readonly", "\\[$@%]");
            export_noproto(aTHX_ XS_const_make_readonly_ref, pkg, "make_readonly_ref");
            export_proto(aTHX_ XS_const_unmake_readonly, pkg, "unmake_readonly", "\\[$@%]");
            export_proto(aTHX_ XS_const_is_readonly, pkg, "is_readonly", "\\[$@%]");
            export_noproto(aTHX_ XS_const_c, pkg, "c");
        } else if (strEQ(ex, "const")) {
            export_proto(aTHX_ XS_const_const, pkg, "const", "\\[$@%]@");
        } else if (strEQ(ex, "make_readonly")) {
            export_proto(aTHX_ XS_const_make_readonly, pkg, "make_readonly", "\\[$@%]");
        } else if (strEQ(ex, "make_readonly_ref")) {
            export_noproto(aTHX_ XS_const_make_readonly_ref, pkg, "make_readonly_ref");
        } else if (strEQ(ex, "unmake_readonly")) {
            export_proto(aTHX_ XS_const_unmake_readonly, pkg, "unmake_readonly", "\\[$@%]");
        } else if (strEQ(ex, "is_readonly")) {
            export_proto(aTHX_ XS_const_is_readonly, pkg, "is_readonly", "\\[$@%]");
        } else if (strEQ(ex, "c")) {
            export_noproto(aTHX_ XS_const_c, pkg, "c");
        } else {
            croak("const: unknown export '%s'", ex);
        }
    }

    XSRETURN_EMPTY;
}

/* ============================================
   BOOT section
   ============================================ */

XS_EXTERNAL(boot_const);
XS_EXTERNAL(boot_const) {
    dXSBOOTARGSXSAPIVERCHK;
    PERL_UNUSED_VAR(items);

    /* Register custom ops */
    XopENTRY_set(&const_c_xop, xop_name, "const_c");
    XopENTRY_set(&const_c_xop, xop_desc, "constant value");
    Perl_custom_op_register(aTHX_ pp_const_c, &const_c_xop);

    XopENTRY_set(&confold_marker_xop, xop_name, "confold");
    XopENTRY_set(&confold_marker_xop, xop_desc, "const fold marker");
    Perl_custom_op_register(aTHX_ pp_confold_marker, &confold_marker_xop);

    /* Wrap ck_sassign to detect our confold marker and set PADNAMEf_CONST */
    wrap_op_checker(OP_SASSIGN, my_ck_sassign, &orig_ck_sassign);

    /* Install XS functions with proper prototypes */
    newXS("const::c", XS_const_c, __FILE__);
    newXSproto("const::const", XS_const_const, __FILE__, "\\[$@%]@");
    newXSproto("const::make_readonly", XS_const_make_readonly, __FILE__, "\\[$@%]");
    newXSproto("const::unmake_readonly", XS_const_unmake_readonly, __FILE__, "\\[$@%]");
    newXSproto("const::is_readonly", XS_const_is_readonly, __FILE__, "\\[$@%]");
    newXS("const::make_readonly_ref", XS_const_make_readonly_ref, __FILE__);
    newXS("const::import", XS_const_import, __FILE__);

    /* Register call checker for c() to enable constant folding */
    {
        CV *cv = get_cv("const::c", 0);
        if (cv) {
            cv_set_call_checker(cv, const_c_call_checker, (SV*)cv);
        }
    }

#if PERL_VERSION_GE(5,22,0)
    Perl_xs_boot_epilog(aTHX_ ax);
#else
    XSRETURN_YES;
#endif
}
