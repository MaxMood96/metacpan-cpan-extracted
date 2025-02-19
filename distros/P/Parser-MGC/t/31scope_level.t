#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

package TestParser {
   use base qw( Parser::MGC );

   sub parse
   {
      my $self = shift;

      $self->sequence_of( 
         sub {
            $self->any_of(
               sub { $self->expect( qr/[a-z]+/ ) . "/" . $self->scope_level },
               sub { $self->scope_of( "(", \&parse, ")" ) },
            );
         },
      );
   }
}

my $parser = TestParser->new;

is( $parser->from_string( "a" ), [ "a/0" ], 'a' );
is( $parser->from_string( "(b)" ), [ [ "b/1" ] ], '(b)' );
is( $parser->from_string( "c (d) e" ), [ "c/0", [ "d/1" ], "e/0" ], 'c (d) e' );

done_testing;
