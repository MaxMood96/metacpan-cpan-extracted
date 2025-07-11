#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::VBox::import;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the vm name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug( "importing: $dom -> " . $opt{file} );

  $opt{cpus}   ||= 1;
  $opt{memory} ||= 512;

  my $add_cmd = "";

  if ( exists $opt{cpus} ) {
    $add_cmd .= " --cpus $opt{cpus} ";
  }

  if ( exists $opt{memory} ) {
    $add_cmd .= " --memory $opt{memory} ";
  }

  i_run "VBoxManage import \""
    . $opt{file}
    . "\" --vsys 0 --vmname \""
    . $dom
    . "\" $add_cmd 2>&1", fail_ok => 1;

  if ( $? != 0 ) {
    die("Error importing VM $opt{file}");
  }
}

1;
