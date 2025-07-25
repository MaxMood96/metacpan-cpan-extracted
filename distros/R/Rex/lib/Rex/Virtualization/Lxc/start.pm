#
# (c) Oleg Hardt <litwol@litwol.com>
#

package Rex::Virtualization::Lxc::start;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the container name!");
  }

  my $container_name = $arg1;
  Rex::Logger::debug("starting container $container_name");

  unless ($container_name) {
    die("VM $container_name not found.");
  }

  i_run "lxc-start -d -n \"$container_name\"", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error starting container $container_name");
  }

}

1;
