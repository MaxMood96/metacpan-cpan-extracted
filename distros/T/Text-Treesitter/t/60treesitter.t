#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

use Text::Treesitter;

my $ts = Text::Treesitter->new(
   lang_name => "fourfunc",
   lang_dir  => "languages/tree-sitter-fourfunc",
);

# parse_string
{
   my $tree = $ts->parse_string( "1 + 2" );
   my $root = $tree->root_node;

   is( $root->tree, $tree, '$root->tree is $tree' );

   ## The following is quite fragile based on the grammar for the program above.
   #  We'll try to do our best

   is( $root->type,       "fourfunc", '$root->type' );
   is( $root->start_byte, 0,          '$root->start_byte' );
   is( $root->end_byte,   5,          '$root->end_byte' );
   ok( $root->is_named,               '$root->is_named' );
}

# parse_string_range
{
   my $tree = $ts->parse_string_range( "The string is '3 + 4'",
      start_byte => 15,
      end_byte   => 15+5,

      start_row    => 100,
      start_column => 20,
   );
   my $root = $tree->root_node;

   is( $root->text, "3 + 4", '$root of ->parse_string_range captured only included range' );

   is( [ $root->start_point ], [ 100, 20 ], '$root->start_point for included range' );
   is( [ $root->end_point ],   [ 100, 25 ], '$root->end_point for included range' );
}

done_testing;
