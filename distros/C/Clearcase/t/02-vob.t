#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Attempt to load Clearcase modules
eval {require Clearcase; require Clearcase::Vob; require Clearcase::Vobs;};
if ($@) {
  plan skip_all => "Clearcase modules not found: $@";
}

# Config file path
my $conf_file = $ENV{TEST_CONF} || "$FindBin::Bin/test.conf";
my %config;

# Helper to read config (duplicated for independence)
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
  my @required = qw(vobhost vobstore);
  foreach my $key (@required) {
    return 0 unless exists $config{$key};
    return 0 if $config{$key} =~ /^<.*>$/;
  }
  return 1;
} ## end sub is_config_valid

if (!is_config_valid ()) {
  plan skip_all => "Live Clearcase tests require configuration in t/test.conf.";
}

# Plan tests
plan tests => 15;    # Estimate

# Determine a VOB to test against
# Ideally we create one, but for Vobs listing we might just take the first one available
use_ok ('Clearcase::Vobs');
my $vobs = Clearcase::Vobs->new;
isa_ok ($vobs, 'Clearcase::Vobs');

my @vob_list = $vobs->vobs;
if (!@vob_list) {
  diag ("No VOBs found in current region to test against.");
  pass ("Skipping object inspection");
} else {
  my $tag = $vob_list[0];
  ok ($tag, "Found a VOB: $tag");

  use_ok ('Clearcase::Vob');
  my $vob = Clearcase::Vob->new ($tag);
  isa_ok ($vob, 'Clearcase::Vob');

  # Check accessors
  ok (defined $vob->tag,    "tag defined");
  ok (defined $vob->gpath,  "gpath defined");
  ok (defined $vob->region, "region defined");

  diag ("Inspected VOB: " . $vob->tag);
} ## end else [ if (!@vob_list) ]
