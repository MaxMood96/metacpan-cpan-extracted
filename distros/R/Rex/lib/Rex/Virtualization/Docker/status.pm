#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::Docker::status;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Data::Dumper;
use Rex::Virtualization::Docker::list;

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  my $vms = Rex::Virtualization::Docker::list->execute("all");

  my ($vm) = grep { $_->{name} eq $arg1 } @{$vms};
  return "stopped" unless $vm;

  if ( $vm->{status} =~ m/exited/i ) {
    return "stopped";
  }
  else {
    return "running";
  }
}

1;
