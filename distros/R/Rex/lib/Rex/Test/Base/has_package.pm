#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Test::Base::has_package;

use v5.12.5;
use warnings;

our $VERSION = '1.16.0'; # VERSION

use Rex -base;
use base qw(Rex::Test::Base);
use Data::Dumper;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  my ( $pkg, $file ) = caller(0);

  return $self;
}

sub run_test {
  my ( $self, $package, $version ) = @_;

  my $pkg = Rex::Pkg->get;

  if ( $pkg->is_installed( $package, { version => $version } ) ) {
    $self->ok( 1,
      "Found package $package" . ( $version ? " at version $version" : "" ) );
    return 1;
  }
  else {
    $self->ok( 0,
      "Found package $package" . ( $version ? " at version $version" : "" ) );
    return 0;
  }
}

1;
