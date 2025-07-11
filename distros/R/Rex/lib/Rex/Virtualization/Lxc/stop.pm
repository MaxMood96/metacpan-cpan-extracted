#
# (c) Oleg Hardt <litwol@litwol.com>
#

package Rex::Virtualization::Lxc::stop;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;
use Scalar::Util qw(looks_like_number);

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the container name!");
  }

  my $container_name = $arg1;
  Rex::Logger::debug("stopping container $container_name");

  unless ($container_name) {
    die("VM $container_name not found.");
  }

  my $opts = \%opt;
  my $timeout =
    ( exists $opts->{timeout} and looks_like_number( $opts->{timeout} ) )
    ? $opts->{timeout}
    : 30;

  i_run "lxc-stop -t $timeout -n \"$container_name\"", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error stopping container $container_name");
  }

}

1;
