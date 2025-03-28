#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

package TestParser {
   use base qw( Parser::MGC );

   sub parse
   {
      my $self = shift;

      $self->any_of(
         sub { [ int => $self->token_int ] },
         sub { [ str => $self->token_string ] },
         sub { [ ident => $self->token_ident ] },
         sub { $self->expect( "@" ); die "Here I fail\n" },
      );
   }
}

package TestParser2 {
   use base qw( Parser::MGC );

   sub parse
   {
      my $self = shift;

      $self->any_of( 'parse_int', 'fail' );
   }

   sub parse_int { [ int => shift->token_int ] }
}

my $parser = TestParser->new;

is( $parser->from_string( "123" ), [ int => 123 ], '"123"' );
is( $parser->from_string( q["hi"] ), [ str => "hi" ], '"hi"' );
is( $parser->from_string( "foobar" ), [ ident => "foobar" ], '"foobar"' );

is( dies { $parser->from_string( "@" ) }, "Here I fail\n",
   'Exception from "@" failure' );

ok( dies { $parser->from_string( "+" ) }, '"+" fails' );

is( TestParser2->new->from_string( "456" ), [ int => 456 ], '"456" as method name' );

done_testing;
