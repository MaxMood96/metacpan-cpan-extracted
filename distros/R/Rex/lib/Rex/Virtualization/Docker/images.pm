#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::Docker::images;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1 ) = @_;
  my @domains;

  Rex::Logger::debug("Getting docker images");

  my @images =
    i_run "docker images --format \"{{.Repository}}:{{.Tag}}:{{.ID}}\"",
    fail_ok => 1;

  my @ret = ();
  for my $line (@images) {
    my ( $image, $tag, $id ) = split( /:/, $line );
    push(
      @ret,
      {
        tag  => $tag,
        name => $image,
        id   => $id,
      }
    );
  }

  return \@ret;
}

1;
