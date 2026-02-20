#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;
my $forker = Linux::Event::Fork->new($loop);

$forker->spawn(
  child => sub {
    # In the child after stdio plumbing is set up.
    # Typically you exec; if you return, Fork exits 127.
    exec $^X, '-we', 'print STDOUT "hello from child cb\n"; exit 0';
  },

  on_stdout => sub ($child, $chunk) {
    print "[stdout] $chunk";
  },

  on_exit => sub ($child, $exit) {
    print "[exit] code=" . ($exit->exited ? $exit->code : 'n/a') . "\n";
    $loop->stop;
  },
);

$loop->run;
