/*  You may distribute under the terms of either the GNU General Public License
 *  or the Artistic License (the same terms as Perl itself)
 *
 *  (C) Paul Evans, 2021 -- leonerd@leonerd.org.uk
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "XSParseKeyword.h"

static const char hintkey[] = "t::flags/permit";

static int build_ident(pTHX_ OP **out, XSParseKeywordPiece *arg0, void *hookdata)
{
  *out = newSVOP(OP_CONST, 0, arg0->sv);
  return KEYWORD_PLUGIN_STMT;
}

static const struct XSParseKeywordHooks hooks_autosemi = {
  .flags = XPK_FLAG_STMT|XPK_FLAG_AUTOSEMI,
  .permit_hintkey = hintkey,

  .piece1 = XPK_IDENT,
  .build1 = &build_ident,
};

static int build_lex_ident(pTHX_ OP **out, XSParseKeywordPiece *arg0, void *hookdata)
{
  SV *sv = newSVpvs("");
  if(PL_parser->in_my)
    sv_catpvs(sv, "my ");
  sv_catsv(sv, arg0->sv);
  *out = newSVOP(OP_CONST, 0, sv);
  return KEYWORD_PLUGIN_EXPR;
}

static const struct XSParseKeywordHooks hooks_lex = {
  .flags = XPK_FLAG_EXPR|XPK_FLAG_PERMIT_LEXICAL,
  .permit_hintkey = hintkey,

  .piece1 = XPK_IDENT,
  .build1 = &build_lex_ident,
};

MODULE = t::flags  PACKAGE = t::flags

BOOT:
  boot_xs_parse_keyword(0);

  register_xs_parse_keyword("flagautosemi", &hooks_autosemi, NULL);

  register_xs_parse_keyword("flaglex", &hooks_lex, NULL);
