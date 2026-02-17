#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

# WHAT THIS EXAMPLE SHOWS
# -----------------------
# * child => sub { ... } form: runs in the child after stdio plumbing is ready
# * exec is recommended (fast + clean). If you "return", Fork treats that as failure.
# * on_stdout / on_stderr streaming callbacks
# * on_exit receives a Linux::Event::Fork::Exit object
#
# WHEN TO USE child=>sub
# ----------------------
# Use child=>sub when you need to do a little setup *in the child* before exec,
# or when you want to run a Perl closure directly in the child process.
#
# If you just want "run this command", prefer cmd => [ ... ] (simpler).

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

$loop->fork(
  tag => 'child-callback',

  child => sub {
    # In the child: set up, then exec.
    # If exec fails, you should exit non-zero; otherwise Fork will exit 127 for you
    # after emitting an error message to STDERR.
    exec $^X, '-we', q{
      print STDOUT "hello from child callback\n";
      print STDERR "this is stderr\n";
      exit 0;
    };
    exit 127;
  },

  on_stdout => sub ($child, $chunk) {
    print "[stdout] $chunk";
  },

  on_stderr => sub ($child, $chunk) {
    print "[stderr] $chunk";
  },

  on_exit => sub ($child, $exit) {
    if ($exit->exited) {
      print "[exit] code=" . $exit->code . "\n";
    } else {
      print "[exit] signal=" . $exit->signal . "\n";
    }
    $loop->stop;
  },
);

$loop->run;
