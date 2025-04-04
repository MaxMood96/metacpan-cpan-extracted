/*  You may distribute under the terms of either the GNU General Public License
 *  or the Artistic License (the same terms as Perl itself)
 *
 *  (C) Paul Evans, 2023-2024 -- leonerd@leonerd.org.uk
 */
#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "object_pad.h"

#define HAVE_PERL_VERSION(R, V, S) \
    (PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

#include "compilerun_sv.c.inc"
#include "optree-additions.c.inc"

#include "DataChecks.h"

static int checkmagic_get(pTHX_ SV *sv, MAGIC *mg)
{
  SV *fieldsv = mg->mg_obj;
  sv_setsv_nomg(sv, fieldsv);
  return 1;
}

static int checkmagic_set(pTHX_ SV *sv, MAGIC *mg)
{
  struct DataChecks_Checker *checker = (struct DataChecks_Checker *)mg->mg_ptr;
  assert_value(checker, sv);

  SV *fieldsv = mg->mg_obj;
  sv_setsv_nomg(fieldsv, sv);
  return 1;
}

static const MGVTBL vtbl_checkmagic = {
  .svt_get = &checkmagic_get,
  .svt_set = &checkmagic_set,
};

static OP *pp_wrap_checkmagic(pTHX)
{
  dSP;
  SV *sv = TOPs;
  SV *ret = sv_newmortal();

  struct DataChecks_Checker *checker = (struct DataChecks_Checker *)cUNOP_AUX->op_aux;

  sv_magicext(ret, sv, PERL_MAGIC_ext, &vtbl_checkmagic, (char *)checker, 0);

  SETs(ret);
  RETURN;
}

static SV *checked_parse(pTHX_ FieldMeta *fieldmeta, SV *valuesrc, void *_funcdata)
{
  if(mop_field_get_sigil(fieldmeta) != '$')
    croak("Can only apply the :Checked attribute to scalar fields");

  dSP;

  ENTER;
  SAVETMPS;

  /* eval_sv() et.al. will forgets what package we're actually running in
   * because during compiletime, CopSTASH(PL_curcop == &PL_compiling) isn't
   * accurate. We need to help it along
   */

  SAVECOPSTASH_FREE(PL_curcop);
  CopSTASH_set(PL_curcop, PL_curstash);

  compilerun_sv(valuesrc, G_SCALAR);

  SPAGAIN;

  SV *ret = SvREFCNT_inc(POPs);

  FREETMPS;
  LEAVE;

  return ret;
}

static bool checked_apply(pTHX_ FieldMeta *fieldmeta, SV *value, SV **attrdata_ptr, void *_funcdata)
{
  if(mop_field_get_sigil(fieldmeta) != '$')
    croak("Can only apply the :Checked attribute to scalar fields");

  struct DataChecks_Checker *checker = make_checkdata(value);
  SvREFCNT_dec(value);

  gen_assertmess(checker,
    sv_2mortal(newSVpvf("Field %" SVf, SVfARG(mop_field_get_name(fieldmeta)))),
    NULL);

  *attrdata_ptr = (SV *)checker;

  return TRUE;
}

static void checked_gen_accessor_ops(pTHX_ FieldMeta *fieldmeta, SV *attrdata, void *_funcdata,
    enum AccessorType type, struct AccessorGenerationCtx *ctx)
{
  struct DataChecks_Checker *checker = (struct DataChecks_Checker *)attrdata;

  switch(type) {
    case ACCESSOR_READER:
      return;

    case ACCESSOR_WRITER:
      ctx->bodyop = op_append_elem(OP_LINESEQ,
        make_assertop(checker, newSLUGOP(0)),
        ctx->bodyop);
      return;

    case ACCESSOR_LVALUE_MUTATOR:
    {
      OP *o = ctx->retop;
      if(o->op_type != OP_RETURN)
        croak("Expected ctx->retop to be OP_RETURN");
      OP *kid = o->op_flags & OPf_KIDS ? cLISTOPo->op_first : NULL, *prevkid = NULL;
      if(kid && kid->op_type == OP_PUSHMARK)
        prevkid = kid, kid = OpSIBLING(kid);
      // TODO: maybe kid is always OP_PADSV, or maybe not.. Should we assert on it?
      OP *newkid = newUNOP_AUX(OP_CUSTOM, 0, kid, (UNOP_AUX_item *)attrdata);
      newkid->op_ppaddr = &pp_wrap_checkmagic;
      if(prevkid)
        OpMORESIB_set(prevkid, newkid);
      else
        croak("TODO: Need to set newkid as kid of listop?!");

      if(OpSIBLING(kid))
        OpMORESIB_set(newkid, OpSIBLING(kid));
      else
        OpLASTSIB_set(newkid, o);

      if(cLISTOPo->op_last == kid)
        cLISTOPo->op_last = newkid;

      OpLASTSIB_set(kid, newkid);
      return;
    }

    case ACCESSOR_COMBINED:
      ctx->bodyop = op_append_elem(OP_LINESEQ,
        newLOGOP(OP_AND, 0,
          /* scalar @_ */
          op_contextualize(newUNOP(OP_RV2AV, 0, newGVOP(OP_GV, 0, PL_defgv)), G_SCALAR),
          make_assertop(checker, newSLUGOP(0))),
        ctx->bodyop);
      return;

    default:
      croak("TODO: Unsure what to do with accessor type %d and :Checked", type);
  }
}

static OP *checked_gen_valueassert_op(pTHX_ FieldMeta *fieldmeta, SV *attrdata, void *_funcdata,
    OP *valueop)
{
  struct DataChecks_Checker *checker = (struct DataChecks_Checker *)attrdata;

  return make_assertop(checker, valueop);
}

static const struct FieldHookFuncs checked_hooks = {
  .ver   = OBJECTPAD_ABIVERSION,
  .flags = OBJECTPAD_FLAG_ATTR_MUST_VALUE,
  .permit_hintkey = "Object::Pad::FieldAttr::Checked/Checked",

  .parse              = &checked_parse,
  .apply              = &checked_apply,
  .gen_accessor_ops   = &checked_gen_accessor_ops,
  .gen_valueassert_op = &checked_gen_valueassert_op,
};

MODULE = Object::Pad::FieldAttr::Checked    PACKAGE = Object::Pad::FieldAttr::Checked

BOOT:
  boot_data_checks(0.09);

  register_field_attribute("Checked", &checked_hooks, NULL);
