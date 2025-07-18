#
# (c) Oleg Hardt <litwol@litwol.com>
#

package Rex::Virtualization::Lxc::attach;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $name, %opt ) = @_;

  my $opts = \%opt;
  $opts->{name} = $name;

  unless ($opts) {
    die("You have to define the attach options!");
  }

  my $options = _format_opts($opts);

  my $attach_command = "lxc-attach $options";

  i_run $attach_command, fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running \"$attach_command\"");
  }

  return $opts->{newname};
}

sub _format_opts {
  my ($opts) = @_;

  # -n, --name=""
  # Assign the specified name to the container to be attached to.
  if ( !exists $opts->{"name"} ) {
    die("You have to give a name.");
  }

  my $str = "-n $opts->{'name'}";

  # -B, --backingstorage=backingstorage
  # backingstorage type for the container
  if ( !exists $opts->{command} ) {
    die("You have to specify a COMMAND");
  }
  $str .= " -- $opts->{command}";

  return $str;
}

1;
