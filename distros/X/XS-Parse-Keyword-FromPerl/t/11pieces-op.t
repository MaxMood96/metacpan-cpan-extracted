#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

use XS::Parse::Keyword::FromPerl qw(
   KEYWORD_PLUGIN_STMT KEYWORD_PLUGIN_EXPR
   XPK_BLOCK XPK_TERMEXPR
   register_xs_parse_keyword
);
use Optree::Generate qw(
   op_contextualize G_VOID
   newOP newLISTOP newFOROP newSVOP newLOGOP

   OP_LIST OP_UNDEF OP_OR OP_DIE OP_CONST
);

# twice
BEGIN {
   register_xs_parse_keyword( twice =>
      permit_hintkey => "main/twice",
      pieces => [XPK_BLOCK],
      build => sub {
         my ( $outref, $args, $hookdata ) = @_;

         my $block = $args->[0]->op;

         $$outref = newFOROP(0, undef,
            newLISTOP(OP_LIST, 0,
               newOP(OP_UNDEF, 0),
               newOP(OP_UNDEF, 0)),
            $block,
            undef
         );

         $$outref = op_contextualize($$outref, G_VOID);

         return KEYWORD_PLUGIN_STMT;
      },
   );
}

{
   BEGIN { $^H{"main/twice"}++ }
   my $x;
   twice { $x .= "hello" }
   is( $x, "hellohello", 'twice block invoked two times' );
}

# assert
BEGIN {
   register_xs_parse_keyword( assert =>
      permit_hintkey => "main/assert",
      pieces => [XPK_TERMEXPR],
      build => sub {
         my ( $outref, $args, $hookdata ) = @_;

         my $expr = $args->[0]->op;

         $$outref = newLOGOP(OP_OR, 0,
            $expr,
            newLISTOP(OP_DIE, 0,
               newSVOP(OP_CONST, 0, "assert failed")
            )
         );

         return KEYWORD_PLUGIN_EXPR;
      },
   );
}

{
   BEGIN { $^H{"main/assert"}++ }

   ok( eval { assert 123 }, 'assert true is fine' );

   my $LINE = __LINE__+1;
   ok( !defined eval { assert 0 }, 'assert false throws' );
   like( $@, qr/^assert failed at (\S+) line $LINE\./, 'assertion failure message' );
}

done_testing;
