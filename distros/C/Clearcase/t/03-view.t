#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

eval {require Clearcase; require Clearcase::View; require Clearcase::Views;};
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
  return 1;    # Less strict for listing views
}

if (!is_config_valid ()) {
  plan skip_all => "Live Clearcase tests require configuration in t/test.conf.";
}

plan tests => 5;

use_ok ('Clearcase::Views');
my $views = Clearcase::Views->new;
isa_ok ($views, 'Clearcase::Views');

my @view_list = $views->views;
if (!@view_list) {
  diag ("No Views found in current region.");
} else {
  my $tag = $view_list[0];
  ok ($tag, "Found a View: $tag");

  use_ok ('Clearcase::View');
  my $view = Clearcase::View->new ($tag);
  isa_ok ($view, 'Clearcase::View');

  diag ("Inspected View: " . $view->tag);
} ## end else [ if (!@view_list) ]
