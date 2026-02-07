#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;
use File::Temp qw(tempfile);

# Create a mute file to silence actual TTS and avoid network calls
my ($mute_fh, $mute_file) = tempfile (UNLINK => 1);
close $mute_fh;
$ENV{SPEAK_MUTE} = $mute_file;

# Create a multi-line input file
my ($input_fh, $input_file) = tempfile (UNLINK => 1);
print $input_fh "Line 1\nLine 2\nLine 3";
close $input_fh;

# Run bin/speak with the input file
# We use backticks to capture STDOUT.
# Speak.pm prints the spoken message to STDOUT via Speak::Logger::msg
my $cmd    = "$^X -Ilib bin/speak -f $input_file";
my $output = `$cmd`;

# Check exit code
is ($?, 0, "bin/speak exited successfully");

# Check output contains all lines
# Note: Speak.pm's speak() function sanitizes newlines to spaces now!
# So "Line 1\nLine 2\nLine 3" becomes "Line 1 Line 2 Line 3"
# AND Speak::Logger appends " [silent shh]" if muted.
like (
  $output,
  qr/Line 1 Line 2 Line 3.*\[silent shh\]/,
  "Output contains all lines from file"
);
