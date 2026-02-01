#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "noop_compat.h"

static OP* pp_noop(pTHX) {
    return NORMAL;
}

static OP* noop_ck_entersub(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    OP *newop;
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    op_free(entersubop);

    NewOp(1101, newop, 1, OP);
    newop->op_type = OP_CUSTOM;
    newop->op_ppaddr = pp_noop;
    newop->op_flags = 0;
    newop->op_next = newop;

    return newop;
}

static XS(xs_noop) {
    dXSARGS;
    PERL_UNUSED_VAR(items);
    XSRETURN_EMPTY;
}

XS_EXTERNAL(boot_noop) {
    dXSBOOTARGSXSAPIVERCHK;
    CV *noop_cv;
    PERL_UNUSED_VAR(items);

    noop_cv = newXS("noop::noop", xs_noop, __FILE__);
    cv_set_call_checker(noop_cv, noop_ck_entersub, &PL_sv_undef);

    Perl_xs_boot_epilog(aTHX_ ax);
}
