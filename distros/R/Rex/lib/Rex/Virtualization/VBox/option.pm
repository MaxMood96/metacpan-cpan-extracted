#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::VBox::option;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

my $FUNC_MAP = {
  max_memory => "memory",
  memory     => "memory",
};

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the vm name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug("setting some options for: $dom");

  for my $opt ( keys %opt ) {
    my $val = $opt{$opt};

    my $func;
    unless ( exists $FUNC_MAP->{$opt} ) {
      Rex::Logger::debug("$opt unknown. using as option for VBoxManage.");
      $func = $opt;
    }
    else {
      $func = $FUNC_MAP->{$opt};
    }

    i_run "VBoxManage modifyvm \"$dom\" --$func \"$val\"", fail_ok => 1;
    if ( $? != 0 ) {
      Rex::Logger::info( "Error setting $opt to $val on $dom ($@)", "warn" );
    }

  }

}

1;
