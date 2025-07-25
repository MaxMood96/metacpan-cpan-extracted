#
# (c) Oleg Hardt <litwol@litwol.com>
#

=head1 NAME

Rex::Virtualization::Lxc - Linux Containers Virtualization Module

=head1 DESCRIPTION

With this module you can manage Linux Containers.

=head1 SYNOPSIS

 use Rex::Commands::Virtualization;

 set virtualization => "Lxc";

 use Data::Dumper;

 print Dumper vm list => "all";
 print Dumper vm list => "active",
   fancy => 1,
   format => 'name,ram';

 print Dumper vm list => "all",
 fancy => 1;

=cut

package Rex::Virtualization::Lxc;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Virtualization::Base;
use base qw(Rex::Virtualization::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

1;
