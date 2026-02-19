#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

# Stress-tested feature demo:
#   Controlled parallelism (max_children) + drain()
#
# This example spawns many short-lived jobs but ensures only N children
# run concurrently. When the queue is fully drained and no children remain
# running, drain() fires and we stop the loop.

use Linux::Event;
use Linux::Event::Fork;


my $loop = Linux::Event->new;
$loop->fork_helper(max_children => ($ENV{MAX} // 4));

my $jobs = $ENV{JOBS} // 25;

for my $i (1 .. $jobs) {
  $loop->fork(
    tag => "job:$i",

    # A tiny "job" that prints one line and exits.
    cmd => [ $^X, '-we', qq{print "hello from $i\\n"; exit 0} ],

    on_stdout => sub ($child, $chunk) {
      print "[stdout] " . $child->tag . " $chunk";
    },

    on_exit => sub ($child, $exit) {
      my $code = $exit->exited ? $exit->code : 'n/a';
      print "[exit]   " . $child->tag . " pid=" . $child->pid . " code=$code\n";
    },
  );
}

# Wait until the pool is fully idle (running==0 && queued==0) then stop the loop.
$loop->fork_helper->drain(on_done => sub ($fork) {
  print "DONE (all jobs finished)\n";
  $loop->stop;
});

$loop->run;
