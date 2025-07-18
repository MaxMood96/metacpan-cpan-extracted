#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::Docker::info;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;
use JSON::MaybeXS;

sub execute {
  my ( $class, $arg1 ) = @_;
  my @dominfo;

  if ( !$arg1 ) {
    die('Must define container ID');
  }

  Rex::Logger::debug("Getting docker info by inspect");

  my $ret = i_run "docker inspect $arg1", fail_ok => 1;
  if ( $? != 0 ) {
    return { running => 'off' };
  }

  my $coder = JSON::MaybeXS->new->allow_nonref;
  my $ref   = $coder->decode($ret);
  $ref = $ref->[0];
  $ref->{running} = "on";
  return $ref;
}

1;
