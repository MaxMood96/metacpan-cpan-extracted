#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Pkg::SunOS::OpenCSW;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Commands::File;
use Rex::Pkg::SunOS;

use base qw(Rex::Pkg::SunOS);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    install           => $self->_pkgutil() . ' --yes -i %s',
    install_version   => $self->_pkgutil() . ' --yes -i %s',
    remove            => $self->_pkgutil() . ' --yes -r %s',
    update_package_db => $self->_pkgutil() . " -U",
  };

  return $self;
}

sub _pkgutil {
  return "/opt/csw/bin/pkgutil";
}

1;
