#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

# WHAT THIS EXAMPLE SHOWS
# -----------------------
# * max_children => 1 so work queues up (configured at runtime)
# * cancel_queued() to remove pending work (without touching a running child)
# * drain() to stop when the pool becomes fully idle
#
# NOTES
# -----
# * cancel_queued() only affects queued requests. If a child is already running,
#   you need your own policy (signals/kill/etc) to stop it.

use Linux::Event;
use Linux::Event::Fork;   # installs $loop->fork and $loop->fork_helper

my $loop = Linux::Event->new;
my $fork = $loop->fork_helper(max_children => 1);

my $jobs = $ENV{JOBS} // 10;

for my $i (1 .. $jobs) {
  $loop->fork(
    tag => "job:$i",
    cmd => [ $^X, '-we', 'select(undef,undef,undef,0.05); print "done\n"; exit 0' ],

    on_stdout => sub ($child, $chunk) {
      print "[stdout] " . $child->tag . " $chunk";
    },

    on_exit => sub ($child, $exit) {
      my $code = $exit->exited ? $exit->code : 'n/a';
      print "[exit]   " . $child->tag . " pid=" . $child->pid . " code=$code\n";
    },
  );
}

# Cancel jobs 6..N before they ever start.
my $canceled = $fork->cancel_queued(sub ($req) {
  my $tag = $req->tag // '';
  return $tag =~ /^job:(\d+)$/ && $1 >= 6;
});

print "Canceled queued requests: $canceled\n";

$fork->drain(on_done => sub ($fork) {
  print "DONE (pool drained)\n";
  $loop->stop;
});

$loop->run;
