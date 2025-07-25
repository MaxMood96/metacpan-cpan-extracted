#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::Docker::import;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Data::Dumper;
use Rex::Logger;
use Rex::Helper::Run;
use Rex::Virtualization::Docker::images;

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the vm name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug( "importing: $dom -> " . $opt{file} );

  my $add_cmd = "";

  if ( -f $opt{file} ) {
    i_run "docker import '$opt{file}' '$dom'", fail_ok => 1;
  }
  else {
    my ( $i_name, $i_tag ) = split( /:/, $opt{file} );
    $i_tag = "latest" unless $i_tag;

    my @images = grep { $_->{name} eq $i_name && $_->{tag} eq $i_tag }
      @{ Rex::Virtualization::Docker::images->execute() };
    unless (@images) {
      i_run "docker pull $opt{file}", fail_ok => 1;
    }
  }

  if ( $? != 0 ) {
    print("Error importing VM $opt{file}\n");
  }
}

1;
