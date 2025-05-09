#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

package TestParser {
   use base qw( Parser::MGC );

   # A badly-written parser that gets stuck easily
   sub parse
   {
      my $self = shift;

      $self->sequence_of( sub {
         $self->expect( qr/\d*/ );
      });
   }
}

my $parser = TestParser->new;

is( $parser->from_string( "12 34 56" ), [ 12, 34, 56 ],
   'Correct output from non-stall' );

is( dies { $parser->from_string( "abc def" ) },
   qq[TestParser failed to make progress on line 1 at:\n] .
   qq[abc def\n] .
   qq[^\n],
   'Exception from stall' );

done_testing;
