#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

# WHAT THIS EXAMPLE SHOWS
# -----------------------
# * Controlled parallelism via: $loop->fork_helper(max_children => N)
# * Running many independent tasks (URLs) without writing a framework
# * Using cmd=>[...] so the child execs immediately (clean + fast)
# * Using drain() so the loop stops when all work is finished
#
# NOTES
# -----
# * This example intentionally uses a child-per-URL model to demonstrate how the pool behaves.
# * Output arrives in arbitrary order (whichever child finishes first).
# * Some sites may block bots; use URLs you control if you want consistent results.

use Linux::Event;
use Linux::Event::Fork;   # installs $loop->fork and $loop->fork_helper

my $loop = Linux::Event->new;
my $fork = $loop->fork_helper(max_children => ($ENV{MAX} // 4));

my @urls = @ARGV ? @ARGV : (
  'https://example.com',
  'https://github.com',
  'https://yahoo.com',
  'https://hotmail.com',
);

for my $url (@urls) {
  $loop->fork(
    tag => $url,

    # Print exactly one line to keep the demo simple.
    cmd => [
      $^X, '-we', qq{
        require HTTP::Tiny;
        my $u = shift;
        my $res = HTTP::Tiny->new->get($u);
        if ($res->{success}) {
          print "OK $u status=$res->{status}\n";
          exit 0;
        } else {
          print "FAIL $u status=$res->{status} reason=$res->{reason}\n";
          exit 1;
        }
      }, $url
    ],

    on_stdout => sub ($child, $chunk) {
      print "[stdout] $chunk";
    },

    on_stderr => sub ($child, $chunk) {
      print "[stderr] " . $child->tag . " $chunk";
    },

    on_exit => sub ($child, $exit) {
      my $code = $exit->exited ? $exit->code : 'n/a';
      print "[exit]   " . $child->tag . " pid=" . $child->pid . " code=$code\n";
    },
  );
}

$fork->drain(on_done => sub ($fork) {
  print "DONE (all URL jobs finished)\n";
  $loop->stop;
});

$loop->run;
