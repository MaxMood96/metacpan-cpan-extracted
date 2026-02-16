#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event;
use Linux::Event::Fork;   # installs $loop->fork

my $loop = Linux::Event->new;

$loop->fork(
  cmd => [
    $^X, '-we',
    q{
      print STDOUT "working...\n";
      print STDERR "minor warning\n";
      exit 42;
    },
  ],

  on_stdout => sub ($child, $chunk) {
    print "[stdout] $chunk";
  },

  on_stderr => sub ($child, $chunk) {
    print "[stderr] $chunk";
  },

  on_exit => sub ($child, $exit) {
    print "\n[exit] pid=" . $child->pid . "\n";

    if ($exit->exited) {
      print "  exited  = 1\n";
      print "  code    = " . $exit->code . "\n";
    } elsif ($exit->signaled) {
      print "  signaled = 1\n";
      print "  signal   = " . $exit->signal . "\n";
      print "  core     = " . ($exit->core_dump ? 1 : 0) . "\n";
    } else {
      print "  raw      = " . ($exit->raw // 'undef') . "\n";
    }

    $loop->stop;
  },
);

$loop->run;
