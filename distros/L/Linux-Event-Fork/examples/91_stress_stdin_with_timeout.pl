#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event;
use Linux::Event::Fork;

# STRESS TEST: stdin streaming + timeout interaction
# This stresses:
#   - backpressure-aware stdin streaming queue
#   - timeout firing while stdin is still being written
#   - teardown stability (timer cancel, watchers, fds) after EPIPE/SIGPIPE conditions
#
# Expected:
#   - timeout fires
#   - child exits (TERM handler)
#   - parent does not hang on write watcher
#   - loop stops cleanly and prints DONE summary

$| = 1; # autoflush

my $loop = Linux::Event->new;

my $TIMEOUT = $ENV{TIMEOUT} // 0.05;
my $PAYLOAD_MB = $ENV{MB} // 5;

print "START\n";
print "  timeout = $TIMEOUT\n";
print "  payload   = ${PAYLOAD_MB}MiB\n";

my $timed = 0;
my $exit;

my $child = $loop->fork(
  tag => "stdin-timeout",

  stdin_pipe => 1,
  timeout => $TIMEOUT,

  on_timeout => sub ($child) {
    $timed++;
    print "[timeout] pid=" . $child->pid . " tag=" . ($child->tag // '') . "\n";
  },

  child => sub {
    $SIG{TERM} = sub { exit 0 };

    # Intentionally read slowly to create backpressure.
    my $buf = '';
    while (1) {
      my $r = sysread(STDIN, $buf, 4096);
      last if !defined $r || $r == 0;
      select(undef, undef, undef, 0.01);
    }
    exit 0;
  },

  on_exit => sub ($c, $ex) {
    $exit = $ex;
    $loop->stop;
  },
);

# Parent safety stop: never let an example hang forever.
$loop->after($TIMEOUT * 20, sub ($loop) {
  print "[safety] stopping loop after timeout window\n";
  $loop->stop;
});

# Push a lot of data quickly.
my $payload = "X" x ($PAYLOAD_MB * 1024 * 1024);
my $off = 0;
my $len = length($payload);

while ($off < $len) {
  my $piece = substr($payload, $off, 131072);
  $child->stdin_write($piece);
  $off += length($piece);
}
$child->close_stdin;

$loop->run;

print "DONE\n";
print "  timedout = $timed\n";
print "  exited   = " . (($exit && $exit->exited) ? 1 : 0) . "\n";
print "  code     = " . (($exit && $exit->exited) ? $exit->code : -1) . "\n";
