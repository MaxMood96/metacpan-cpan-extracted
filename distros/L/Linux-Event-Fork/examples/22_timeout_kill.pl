#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

# WHAT THIS EXAMPLE SHOWS
# -----------------------
# * timeout => SECONDS on a fork request
# * on_timeout callback (tagged) and how it relates to the eventual on_exit
#
# NOTES
# -----
# * timeout is "best effort" timing at event-loop granularity.
# * A timeout does not necessarily mean "no exit callback"; you typically still get on_exit.

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

my $timeout = $ENV{TIMEOUT} // 0.25;

$loop->fork(
  tag     => 'timeout-demo',
  timeout => $timeout,

  cmd => [ 'sh', '-c', 'echo "starting"; sleep 5; echo "finished"' ],

  on_stdout => sub ($child, $chunk) {
    print "[stdout] $chunk";
  },

  on_timeout => sub ($child) {
    print "[timeout] pid=" . $child->pid . " tag=" . ($child->tag // '') . "\n";
  },

  on_exit => sub ($child, $exit) {
    my $code = $exit->exited ? $exit->code : 'n/a';
    print "[exit] pid=" . $child->pid . " code=$code\n";
    $loop->stop;
  },
);

$loop->run;
