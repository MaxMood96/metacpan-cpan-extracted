#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::VBox::bridge;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

use Data::Dumper;

sub execute {
  my $class = shift;

  my $result = i_run "VBoxManage list bridgedifs", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running VBoxManage list bridgedifs");
  }

  my @ifs;
  my @blocks = split /\n\n/m, $result;
  for my $block (@blocks) {

    my $if    = {};
    my @lines = split /\n/, $block;
    for my $line (@lines) {
      if ( $line =~ /^Name:\s+(.+?)$/ ) {
        $if->{name} = $1;
      }
      elsif ( $line =~ /^IPAddress:\s+(.+?)$/ ) {
        $if->{ip} = $1;
      }
      elsif ( $line =~ /^NetworkMask:\s+(.+?)$/ ) {
        $if->{netmask} = $1;
      }
      elsif ( $line =~ /^Status:\s+(.+?)$/ ) {
        $if->{status} = $1;
      }
    }

    push @ifs, $if;
  }

  return \@ifs;
}

1;
