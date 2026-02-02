# Prefer numeric version for backwards compatibility
BEGIN { require 5.006000 }; ## no critic ( RequireUseStrict, RequireUseWarnings )
use strict;
use warnings;

package Log::Log4perl::Config::YamlConfigurator;

$Log::Log4perl::Config::YamlConfigurator::VERSION = 'v1.0.3';

use parent qw( Clone Log::Log4perl::Config::BaseConfigurator );

use Carp                  qw( croak  );
use YAML::PP              qw( Load );
use Log::Log4perl::Config qw();

sub create_appender_instance {
  my ( $self, $name ) = @_;

  my $data = $self->parse;
  Log::Log4perl::Config::create_appender_instance( $data, $name, {}, [],
    exists $data->{ threshold } ? $data->{ threshold }->{ value } : undef )
}

sub new {
  my $class = shift;

  my $self = $class->SUPER::new( @_ );

  unless ( exists $self->{ data } ) {
    if ( exists $self->{ text } ) {
      $self->{ data } = Load( join( "\n", @{ $self->{ text } } ) )
    } else {
      croak "'text' parameter not set, stopped"
    }
  }

  croak "'data' parameter has to be a HASH reference with the keys 'category', and 'appender', stopped"
    unless ref( $self->{ data } ) eq 'HASH'
    and exists $self->{ data }->{ category }
    and exists $self->{ data }->{ appender };

  $self
}

# https://metacpan.org/pod/Log::Log4perl::Config::BaseConfigurator#Parser-requirements
sub parse {
  my ( $self ) = @_;

  # Make sure that a parse() does not change $self!
  my $copy = $self->clone;
  my @todo = ( $copy->{ data } );

  while ( @todo ) {
    my $ref = shift @todo;
    for ( keys %$ref ) {
      if ( ref( $ref->{ $_ } ) eq 'HASH' ) {
        push @todo, $ref->{ $_ }
      } elsif ( $_ eq 'name' ) {
        # Appender 'name' entries and layout 'name entries are converted to ->{ value } entries
        $ref->{ value } = $ref->{ $_ };
        delete $ref->{ $_ }
      } else {
        my $tmp = $ref->{ $_ };
        $ref->{ $_ } = {};
        $ref->{ $_ }->{ value } = $tmp
      }
    }
  }

  $copy->{ data }
}

1
