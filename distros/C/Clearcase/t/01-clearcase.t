#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Cwd;

# Attempt to load Clearcase module
eval {require Clearcase; Clearcase->import ();};
if ($@) {
  plan skip_all => "Clearcase module not found: $@";
}

# Config file path
my $conf_file = $ENV{TEST_CONF} || "$FindBin::Bin/test.conf";
my %config;

# Helper to read config
sub read_config {
  my $file = shift;
  return unless -f $file;
  open my $fh, '<', $file or die "Cannot open $file: $!";
  while (<$fh>) {
    next if /^\s*#/;     # Skip comments
    next unless /\S/;    # Skip empty lines
    if (/^\s*(\w+):\s*(.+?)\s*$/) {
      $config{$1} = $2;
    }
  } ## end while (<$fh>)
  close $fh;
} ## end sub read_config

# Check if config is valid for live tests
sub is_config_valid {
  return 0 unless -f $conf_file;
  read_config ($conf_file);

  my @required = qw(vobhost vobstore viewhost viewstore);
  foreach my $key (@required) {
    return 0 unless exists $config{$key};
    return 0 if $config{$key} =~ /^<.*>$/;    # Check for placeholders
  }
  return 1;
} ## end sub is_config_valid

# MOCK INJECTION
use lib 't/lib';
eval {require MockClearcase;};
if (!$@) {
  diag "Using MockClearcase for testing";
  no warnings 'once';
  $Clearcase::CC = MockClearcase->new;

  # Provide dummy config if needed
  $config{vobhost}   ||= 'mock_host';
  $config{vobstore}  ||= '/net/mock_host/vobs';
  $config{viewhost}  ||= 'mock_host';
  $config{viewstore} ||= '/net/mock_host/views';
} elsif (!is_config_valid ()) {
  plan skip_all =>
"Live Clearcase tests require configuration in t/test.conf. Please configure variables (vobhost, etc) to run these tests.";
}

# If we are here, we are running tests (live or mock)!
plan tests => 15;    # Estimate, will adjust

# Load other modules
use_ok ('Clearcase::Vob');
use_ok ('Clearcase::View');
use_ok ('Clearcase::Element');
use_ok ('Clearcase::UCM::Pvob');
use_ok ('Clearcase::UCM::Project');
use_ok ('Clearcase::UCM::Stream');
use_ok ('Clearcase::UCM::Component');
use_ok ('Clearcase::UCM::Activity');
use_ok ('Clearcase::UCM::Baseline');
use_ok ('Clearcase::UCM::Folder');

# Globals for test objects
my ($test_vob, $test_view);
my $vobtag  = "cc_test_vob_$$";    # Unique tag
my $viewtag = "cc_test_view_$$";

# Helper to log/diag
sub logger {
  my $msg = shift;
  diag ("LOG: $msg");
}

# Clean environment from previous runs (best effort)
cleanup ();

# Start Tests - Base Clearcase
logger ("Starting Base Clearcase Tests");

# Create VOB
my $vobstore = "$config{vobstore}/$vobtag.vbs";
logger ("Creating VOB $vobtag at $vobstore");

$test_vob = Clearcase::Vob->new ($vobtag);
isa_ok ($test_vob, 'Clearcase::Vob');

my ($status, @output) = $test_vob->create ($config{vobhost}, $vobstore);
if ($status) {
  diag    ("Failed to create VOB: " . join ("\n", @output));
  fail    ("Create VOB");
  cleanup ();
  exit 1;
} ## end if ($status)
pass ("Create VOB $vobtag");

# Mount VOB
($status, @output) = $test_vob->mount;
is ($status, 0, "Mount VOB") or diag ("Output: @output");

# Create View
my $viewstore = "$config{viewstore}/$viewtag.vws";
logger ("Creating View $viewtag at $viewstore");

$test_view = Clearcase::View->new ($viewtag);
isa_ok ($test_view, 'Clearcase::View');

($status, @output) = $test_view->create ($config{viewhost}, $viewstore);
if ($status) {
  diag    ("Failed to create View: " . join ("\n", @output));
  fail    ("Create View");
  cleanup ();
  exit 1;
} ## end if ($status)
pass ("Create View $viewtag");

# Cleanup function
sub cleanup {
  my $status;
  if ($test_view && $test_view->exists) {
    $test_view->remove;
  }
  if ($test_vob && $test_vob->exists) {

    # Unmount and remove
    $test_vob->umount;
    $test_vob->remove;
  } ## end if ($test_vob && $test_vob...)
} ## end sub cleanup

END {
  cleanup ();
}
