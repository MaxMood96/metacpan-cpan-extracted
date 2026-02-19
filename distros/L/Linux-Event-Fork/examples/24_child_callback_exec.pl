#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

# WHAT THIS EXAMPLE SHOWS
# -----------------------
# * child => sub { ... } form: runs in the child after stdio plumbing is ready
# * explicit exec (recommended) vs returning (returns are treated as failure)
#
# NOTES
# -----
# * Fork is not a supervisor/framework; it wires FDs + observes exit.
# * If you use child=>sub, you are responsible for exiting (or exec'ing) cleanly.

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

$loop->fork(
  tag => 'child-callback',

  child => sub {
    exec 'sh', '-c', 'echo "hello from child"; echo "warn" 1>&2; exit 0';
    exit 127; # only reached if exec fails
  },

  on_stdout => sub ($child, $chunk) {
    print "[stdout] $chunk";
  },

  on_stderr => sub ($child, $chunk) {
    print "[stderr] $chunk";
  },

  on_exit => sub ($child, $exit) {
    my $code = $exit->exited ? $exit->code : 'n/a';
    print "[exit] pid=" . $child->pid . " code=$code\n";
    $loop->stop;
  },
);

$loop->run;
