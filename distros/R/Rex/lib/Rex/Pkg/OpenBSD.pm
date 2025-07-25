#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Pkg::OpenBSD;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::Pkg::Base;
use base qw(Rex::Pkg::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    install         => '/usr/sbin/pkg_add %s',
    install_version => '/usr/sbin/pkg_add %s-%s',
    remove          => '/usr/sbin/pkg_delete %s',
  };

  return $self;
}

sub remove {
  my ( $self, $pkg ) = @_;

  my ($pkg_found) = grep { $_->{"name"} eq "$pkg" } $self->get_installed();
  my $pkg_version = $pkg_found->{"version"};

  return $self->SUPER::remove("$pkg-$pkg_version");
}

sub get_installed {
  my ($self) = @_;

  my @lines = i_run "/usr/sbin/pkg_info";

  my @pkg;

  for my $line (@lines) {
    my ( $pkg_name_v, $descr ) = split( /\s/, $line, 2 );

    my ( $pkg_name, $pkg_version ) = ( $pkg_name_v =~ m/^(.*)-(.*?)$/ );

    push(
      @pkg,
      {
        name    => $pkg_name,
        version => $pkg_version,
      }
    );
  }

  return @pkg;
}

1;
