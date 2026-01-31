#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

eval {require Clearcase; require Clearcase::Views;};
if ($@) {
  plan skip_all => "Clearcase modules not found: $@";
}

# Config Check
my $conf_file = $ENV{TEST_CONF} || "$FindBin::Bin/test.conf";
my %config;

sub read_config {
  my $file = shift;
  return unless -f $file;
  open my $fh, '<', $file or die "Cannot open $file: $!";
  while (<$fh>) {
    next if /^\s*#/;
    next unless /\S/;
    if (/^\s*(\w+):\s*(.+?)\s*$/) {
      $config{$1} = $2;
    }
  } ## end while (<$fh>)
  close $fh;
} ## end sub read_config

sub is_config_valid {
  return 0 unless -f $conf_file;
  read_config ($conf_file);
  return 1;
}

if (!is_config_valid ()) {
  plan skip_all => "Live Clearcase tests require configuration in t/test.conf.";
}

plan tests => 2;

use_ok ('Clearcase::Views');
my $views = Clearcase::Views->new;
isa_ok ($views, 'Clearcase::Views');

# Logic duplicates t/03-view.t essentially but focuses on collection
