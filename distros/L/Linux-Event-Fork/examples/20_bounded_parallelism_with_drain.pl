#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

# WHAT THIS EXAMPLE SHOWS
# -----------------------
# * Controlled parallelism (max_children) configured at *runtime*
# * Queueing when the pool is full
# * drain() callback that fires once:
#     - no children are running, AND
#     - the internal queue is empty
#
# WHY THIS MATTERS
# ----------------
# A common pattern is “run a lot of small jobs, but only N at a time”.
# Linux::Event::Fork provides that policy-layer on top of Linux::Event.
#
# CANONICAL API NOTE
# ------------------
# This module previously supported a compile-time idiom:
#   use Linux::Event::Fork max_children => 4;
# That style is intentionally removed. Configure at runtime instead:
#   my $fork = $loop->fork_helper(max_children => 4);

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

# Choose concurrency. You can override with MAX_CHILDREN=... in the environment.
my $max_children = 0 + ($ENV{MAX_CHILDREN} // 4);

# Install / fetch the helper attached to this loop, configured with a limit.
my $fork = $loop->fork_helper(max_children => $max_children);

my $jobs = 50;
my $done = 0;

for my $i (1..$jobs) {
  my $h = $loop->fork(
    tag => "job:$i",
    cmd => [ $^X, '-we', 'select(undef,undef,undef,0.03); print "ok\n"; exit 0' ],

    on_exit => sub ($child, $exit) {
      $done++;
      # Keep output small; you can remove this if you want a quieter run.
      print "done $done/$jobs (pid=" . $child->pid . " tag=" . ($child->tag // '') . ")\n";
    },
  );

  # When the pool is full, fork() returns a Request object instead of a Child.
  # It will start automatically when capacity becomes available.
  if ($h->isa('Linux::Event::Fork::Request')) {
    # Tip: you can cancel queued work later via cancel_queued().
    # (Running children are unaffected by cancel_queued.)
  }
}

# Stop the loop once everything is fully drained.
$fork->drain(on_done => sub ($fork) {
  print "ALL DONE (running=" . $fork->running . " queued=" . $fork->queued . ")\n";
  $loop->stop;
});

$loop->run;
