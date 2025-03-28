#!/usr/bin/perl

use v5.14;
use warnings;

package PodParser;
use base qw( Parser::MGC );

use Feature::Compat::Try;

sub parse
{
   my $self = shift;

   $self->sequence_of(
      sub { $self->any_of(

         sub { my ( undef, $tag, $delim ) = $self->expect( qr/([A-Z])(<+)/ );
               $self->commit;
               +{ $tag => $self->scope_of( undef, \&parse, ">" x length $delim ) }; },

         sub { $self->substring_before( qr/[A-Z]</ ) },
      ) },
   );
}

use Data::Dumper;

if( !caller ) {
   my $parser = __PACKAGE__->new;

   while( defined( my $line = <STDIN> ) ) {
      try {
         my $ret = $parser->from_string( $line );
         print Dumper( $ret );
      }
      catch ( $e ) {
         print $e;
      }
   }
}

1;
