#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "include/cs_slot.h"

/* G_LIST is the 5.36 spelling of G_ARRAY. Unguarded it breaks the build on
 * everything older. */
#ifndef G_LIST
#  define G_LIST G_ARRAY
#endif

/* GvCV_set arrived in 5.13. Before that the slot was assigned directly. */
#ifndef GvCV_set
#  define GvCV_set(gv, cv) (GvCV(gv) = (cv))
#endif

/* Catalyst::ClassData's accessor calls Moose::Util::find_meta on every read,
 * to answer a question that stops changing at setup_finalize. This replaces it
 * with a constant, and falls back to the original for anything the constant
 * cannot answer: a write, or an invocant that is not the class we resolved
 * the value for. */

/* Put a coderef into a glob's CODE slot, leaving every other slot alone.
 *
 * Only the CODE slot, because ClassData keeps the value itself in the same
 * glob's SCALAR slot and the write that triggered this is about to go there.
 *
 * Not sv_setsv on the glob: that is a glob assignment, and a glob assignment
 * over an existing subroutine warns "Subroutine %s redefined" against the
 * warning bits of whoever happened to call the accessor. They did not ask for
 * this and cannot silence it. */
static void
cs_set_cv(pTHX_ SV *fq, CV *code)
{
    GV *gv = gv_fetchsv(fq, GV_ADD, SVt_PVCV);
    CV *old;

    if (!gv)
        return;

    old = GvCV(gv);
    GvCV_set(gv, (CV *) SvREFCNT_inc((SV *) code));
    GvCVGEN(gv) = 0;
    if (old)
        SvREFCNT_dec((SV *) old);
}

static void
cs_unseal(pTHX_ cs_slot *slot)
{
    CV *orig;

    if (slot->unsealed)
        return;
    slot->unsealed = 1;

    orig = (CV *) SvRV(slot->orig);
    cs_set_cv(aTHX_ slot->fq, orig);
    if (slot->fq_alias)
        cs_set_cv(aTHX_ slot->fq_alias, orig);

    /* Our own CV is running right now. The slot holds a reference to it, so
     * dropping it out of the globs above cannot free it under us. */
    mro_method_changed_in(slot->stash);
}

/* Call the shadowed accessor with the arguments we were given and leave its
 * results where the caller expects ours. Returns the number of values.
 *
 * The slow path only: a write, or a subclass created after sealing. Copying
 * both ways costs nothing there and keeps the stack handling obvious. */
static I32
cs_delegate(pTHX_ SV *code, I32 items, I32 ax)
{
    dSP;
    I32 count, i;
    I32 gimme = GIMME_V;
    SV **argv;
    SV **out;

    Newx(argv, items ? items : 1, SV *);
    for (i = 0; i < items; i++)
        argv[i] = ST(i);

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, items);
    for (i = 0; i < items; i++)
        PUSHs(argv[i]);
    PUTBACK;

    count = call_sv(code, gimme);

    SPAGAIN;
    Newx(out, count ? count : 1, SV *);
    for (i = count - 1; i >= 0; i--)
        out[i] = newSVsv(POPs);
    PUTBACK;

    FREETMPS;
    LEAVE;

    /* Back to our own frame. Rewind to just below our arguments and put the
     * results there instead. */
    SPAGAIN;
    SP = PL_stack_base + ax - 1;
    EXTEND(SP, count);
    PUTBACK;

    for (i = 0; i < count; i++)
        ST(i) = sv_2mortal(out[i]);

    Safefree(argv);
    Safefree(out);
    return count;
}

static void
cs_const_accessor(pTHX_ CV *cv)
{
    dXSARGS;
    cs_slot *slot = (cs_slot *) CvXSUBANY(cv).any_ptr;
    SV *inv;
    int mine = 0;

    if (!slot)
        croak("Catalyst::Seal: sealed accessor with no slot");

    if (items < 1)
        croak("Usage: %s($class)", SvPV_nolen(slot->name));

    /* Is this the class the value was resolved for? A subclass created after
     * sealing inherits this XSUB but not the answer, so it goes the long way
     * round rather than being told the parent's value. */
    inv = ST(0);
    if (SvROK(inv)) {
        SV *rv = SvRV(inv);
        if (SvOBJECT(rv) && SvSTASH(rv) == slot->stash)
            mine = 1;
    }
    else if (SvOK(inv)) {
        STRLEN il, pl;
        const char *ip = SvPV_const(inv, il);
        const char *pp = SvPV_const(slot->pkg, pl);
        if (il == pl && memEQ(ip, pp, il))
            mine = 1;
    }

    if (mine && items == 1 && !slot->unsealed) {
        /* The stock accessor ends in a bare "return;" when it finds nothing
         * defined, anywhere in the ISA. That is an empty list in list context,
         * not a one element list holding undef, and a class data value that
         * was explicitly set to undef is indistinguishable from one that was
         * never set: both take that branch. */
        if (!SvOK(slot->value)) {
            if (GIMME_V == G_LIST)
                XSRETURN_EMPTY;
            XSRETURN_UNDEF;
        }
        ST(0) = slot->value;
        XSRETURN(1);
    }

    /* A write puts the original accessor back for good: from here on the value
     * can change and a constant would be a lie.
     *
     * Only a write to the class we resolved for. A subclass writing through
     * the inherited XSUB is storing into its own glob and says nothing about
     * ours, so unsealing there would give up the constant for every class in
     * the tree the first time any one of them is written to. */
    if (mine && items > 1)
        cs_unseal(aTHX_ slot);

    XSRETURN(cs_delegate(aTHX_ slot->orig, items, ax));
}

/* A sealed attribute reader.
 *
 * Moose's inlined reader is already cheap, about 88ns against this XSUB's 44,
 * so the only thing worth doing here is the fetch and nothing else. Everything
 * that is not "an instance of exactly this class, reading" goes to the reader
 * we shadowed: a class method call, a write, an instance of a subclass.
 *
 * A lazy attribute whose slot is not there yet also delegates, which is how
 * this avoids reimplementing Moose's builders entirely. The stock reader
 * builds and stores it, and every call after that takes the fast path. It also
 * means a predicate keeps telling the truth, because nothing here ever stores
 * anything. */
static void
cs_attr_reader(pTHX_ CV *cv)
{
    dXSARGS;
    cs_reader *r = (cs_reader *) CvXSUBANY(cv).any_ptr;
    SV *inv, *rv;
    HE *he;

    if (!r)
        croak("Catalyst::Seal: sealed reader with no slot");

    if (items != 1)
        goto slow;

    inv = ST(0);
    if (!SvROK(inv))
        goto slow;

    rv = SvRV(inv);
    /* A blessed object is a hash reference, so SvTYPE alone would accept an
     * object of any class built on any other type. SvOBJECT is the question
     * actually being asked. */
    if (!SvOBJECT(rv) || SvTYPE(rv) != SVt_PVHV)
        goto slow;
    if (SvSTASH(rv) != r->stash)
        goto slow;

    he = hv_fetch_ent((HV *) rv, r->key, 0, r->hash);
    if (he) {
        ST(0) = HeVAL(he);
        XSRETURN(1);
    }
    if (!r->lazy)
        XSRETURN_UNDEF;

slow:
    XSRETURN(cs_delegate(aTHX_ r->orig, items, ax));
}

MODULE = Catalyst::Seal        PACKAGE = Catalyst::Seal

PROTOTYPES: DISABLE

void
_install_const(pkg, name, value, orig, alias = NULL)
    SV *pkg
    SV *name
    SV *value
    SV *orig
    SV *alias
  PREINIT:
    cs_slot *slot;
    CV *cv;
    HV *stash;
    STRLEN plen, nlen;
    const char *pstr, *nstr;
    SV *fq, *fq_alias;
  PPCODE:
    if (!SvROK(orig) || SvTYPE(SvRV(orig)) != SVt_PVCV)
        croak("Catalyst::Seal::_install_const: orig must be a code reference");

    pstr = SvPV_const(pkg, plen);
    nstr = SvPV_const(name, nlen);

    stash = gv_stashpvn(pstr, plen, GV_ADD);
    if (!stash)
        croak("Catalyst::Seal::_install_const: no stash for %" SVf, SVfARG(pkg));

    fq = newSVpvn(pstr, plen);
    sv_catpvs(fq, "::");
    sv_catpvn(fq, nstr, nlen);

    /* mk_classdata's second name for the same accessor. Optional, because not
     * everything sealed here is a class data pair: sealing "config" under the
     * convention would install a _config_accessor that never existed. */
    if (alias && SvOK(alias)) {
        STRLEN alen;
        const char *astr = SvPV_const(alias, alen);
        fq_alias = newSVpvn(pstr, plen);
        sv_catpvs(fq_alias, "::");
        sv_catpvn(fq_alias, astr, alen);
    }
    else if (!alias) {
        fq_alias = newSVpvn(pstr, plen);
        sv_catpvs(fq_alias, "::_");
        sv_catpvn(fq_alias, nstr, nlen);
        sv_catpvs(fq_alias, "_accessor");
    }
    else {
        fq_alias = NULL;
    }

    Newxz(slot, 1, cs_slot);
    slot->value    = newSVsv(value);
    slot->orig     = newSVsv(orig);
    slot->pkg      = newSVsv(pkg);
    slot->name     = newSVsv(name);
    slot->fq       = fq;
    slot->fq_alias = fq_alias;
    slot->stash    = (HV *) SvREFCNT_inc((SV *) stash);
    slot->unsealed = 0;

    /* newXS installs into the named glob and warns about redefinition against
     * the caller's warning bits, so the Perl side does this inside a
     * "no warnings 'redefine'". */
    cv = newXS(SvPV_nolen(fq), cs_const_accessor, __FILE__);
    CvXSUBANY(cv).any_ptr = slot;
    slot->cv = (CV *) SvREFCNT_inc((SV *) cv);

    if (fq_alias) {
        cv = newXS(SvPV_nolen(fq_alias), cs_const_accessor, __FILE__);
        CvXSUBANY(cv).any_ptr = slot;
        slot->cv_alias = (CV *) SvREFCNT_inc((SV *) cv);
    }

    mro_method_changed_in(stash);
    XSRETURN_YES;

# Whether a given sealed accessor has been unsealed by a write. For the test
# suite, and for CATALYST_SEAL_DEBUG reporting.
void
_is_sealed(code)
    SV *code
  PREINIT:
    CV *cv;
    cs_slot *slot;
  PPCODE:
    if (!SvROK(code) || SvTYPE(SvRV(code)) != SVt_PVCV)
        XSRETURN_UNDEF;
    cv = (CV *) SvRV(code);
    if (CvISXSUB(cv) && CvXSUB(cv) == cs_const_accessor) {
        slot = (cs_slot *) CvXSUBANY(cv).any_ptr;
        if (slot && !slot->unsealed)
            XSRETURN_YES;
        XSRETURN_NO;
    }
    if (CvISXSUB(cv) && CvXSUB(cv) == cs_attr_reader)
        XSRETURN_YES;
    XSRETURN_UNDEF;

void
_install_reader(pkg, name, key, orig, lazy)
    SV *pkg
    SV *name
    SV *key
    SV *orig
    int lazy
  PREINIT:
    cs_reader *r;
    CV *cv;
    HV *stash;
    STRLEN plen, nlen, klen;
    const char *pstr, *nstr, *kstr;
    U32 hash;
    SV *fq;
  PPCODE:
    if (!SvROK(orig) || SvTYPE(SvRV(orig)) != SVt_PVCV)
        croak("Catalyst::Seal::_install_reader: orig must be a code reference");

    pstr = SvPV_const(pkg, plen);
    nstr = SvPV_const(name, nlen);
    kstr = SvPV_const(key, klen);

    stash = gv_stashpvn(pstr, plen, GV_ADD);
    if (!stash)
        croak("Catalyst::Seal::_install_reader: no stash for %" SVf, SVfARG(pkg));

    fq = newSVpvn(pstr, plen);
    sv_catpvs(fq, "::");
    sv_catpvn(fq, nstr, nlen);

    PERL_HASH(hash, kstr, klen);

    Newxz(r, 1, cs_reader);
    r->key   = newSVsv(key);
    r->hash  = hash;
    r->orig  = newSVsv(orig);
    r->fq    = fq;
    r->stash = (HV *) SvREFCNT_inc((SV *) stash);
    r->lazy  = lazy ? 1 : 0;

    cv = newXS(SvPV_nolen(fq), cs_attr_reader, __FILE__);
    CvXSUBANY(cv).any_ptr = r;
    r->cv = (CV *) SvREFCNT_inc((SV *) cv);

    mro_method_changed_in(stash);
    XSRETURN_YES;
