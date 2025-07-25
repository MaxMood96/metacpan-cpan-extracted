#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::LibVirt::dumpxml;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

use XML::Simple;

use Data::Dumper;

sub execute {
  my ( $class, $vmname ) = @_;
  my $virt_settings = Rex::Config->get("virtualization");
  chomp( my $uri =
      ref($virt_settings) ? $virt_settings->{connect} : i_run "virsh uri" );

  unless ($vmname) {
    die("You have to define the vm name!");
  }

  Rex::Logger::debug("Getting dumpxml of domain: $vmname");

  my $xml;

  my $dumpxml = i_run "virsh -c $uri dumpxml '$vmname'", fail_ok => 1;

  if ( $? != 0 ) {
    die("Error running virsh dumpxml '$vmname'");
  }
  return XMLin($dumpxml);
}

1;
