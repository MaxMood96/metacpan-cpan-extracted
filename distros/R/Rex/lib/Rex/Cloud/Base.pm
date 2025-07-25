#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Cloud::Base;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub set_auth { Rex::Logger::debug("Not implemented"); }

sub set_endpoint {
  my ( $self, $endpoint ) = @_;

  # only set endpoint if defined
  if ( defined $endpoint ) {
    $self->{__endpoint} = $endpoint;
  }
}

sub list_plans             { Rex::Logger::debug("Not implemented"); }
sub list_operating_systems { Rex::Logger::debug("Not implemented"); }

sub run_instance           { Rex::Logger::debug("Not implemented"); }
sub terminate_instance     { Rex::Logger::debug("Not implemented"); }
sub start_instance         { Rex::Logger::debug("Not implemented"); }
sub stop_instance          { Rex::Logger::debug("Not implemented"); }
sub list_instances         { Rex::Logger::debug("Not implemented"); }
sub list_running_instances { Rex::Logger::debug("Not implemented"); }

sub create_volume { Rex::Logger::debug("Not implemented"); }
sub attach_volume { Rex::Logger::debug("Not implemented"); }
sub detach_volume { Rex::Logger::debug("Not implemented"); }
sub delete_volume { Rex::Logger::debug("Not implemented"); }
sub list_volumes  { Rex::Logger::debug("Not implemented"); }
sub list_images   { Rex::Logger::debug("Not implemented"); }

sub add_tag { Rex::Logger::debug("Not implemented"); }

sub get_regions            { Rex::Logger::debug("Not implemented"); }
sub get_availability_zones { Rex::Logger::debug("Not implemented"); }

1;
