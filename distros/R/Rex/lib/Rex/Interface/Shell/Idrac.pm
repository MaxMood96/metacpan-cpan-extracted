#
# (c) Ferenc Erki <erkiferenc@gmail.com>, adjust GmbH
#

package Rex::Interface::Shell::Idrac;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Interface::Shell::Default;
use base qw(Rex::Interface::Shell::Default);

sub new {
  my $class = shift;
  my $proto = ref($class) || $class;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $class );

  return $self;
}

sub detect {
  my ( $self, $con ) = @_;

  my ($output);
  eval {
    ($output) = $con->direct_exec('version');
    1;
  };
  if ( $output && $output =~ m/SM CLP Version: / ) {
    return 1;
  }

  return 0;
}

sub exec {
  my ( $self, $cmd, $option ) = @_;
  return $cmd;
}

1;
