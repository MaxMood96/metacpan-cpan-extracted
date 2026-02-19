#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

# WHAT THIS EXAMPLE SHOWS
# -----------------------
# * Controlled parallelism via: $loop->fork_helper(max_children => N)
# * A simple "worker pool" pattern where each child handles one unit of work (one URL)
# * Using cmd=>[...] so the child execs immediately (clean + fast)
# * Using drain() so the loop stops when all work is finished
#
# NOTES
# -----
# * Output arrives in arbitrary order (whichever child finishes first).
# * Some sites block automated requests; use URLs you control for consistent results.
# * This uses HTTP::Tiny (core Perl) inside the child process.

use Linux::Event;
use Linux::Event::Fork;   # installs $loop->fork and $loop->fork_helper

my $loop = Linux::Event->new;

# Create (or fetch) the per-loop helper and configure bounded parallelism.
my $fork = $loop->fork_helper(max_children => ($ENV{MAX} // 4));

my @urls = @ARGV ? @ARGV : (
  'https://example.com',
  'https://github.com',
  'https://yahoo.com',
  'https://hotmail.com',
);

# IMPORTANT: The child code must be passed as a *literal* string (no interpolation),
# otherwise variables like $u / $res will be expanded in the parent before exec.
my $child_code = <<'PERL';
require HTTP::Tiny;

my $u = shift;
my $res = HTTP::Tiny->new->get($u);

if ($res->{success}) {
  print "OK $u status=$res->{status}\n";
  exit 0;
}

my $reason = $res->{reason} // '';
print "FAIL $u status=$res->{status} reason=$reason\n";
exit 1;
PERL

for my $url (@urls) {
  $loop->fork(
    tag => $url,

    # One child per URL:
    cmd => [ $^X, '-we', $child_code, $url ],

    on_stdout => sub ($child, $chunk) {
      # Runs in the parent when stdout data is read from the child.
      print "[stdout] $chunk";
    },

    on_stderr => sub ($child, $chunk) {
      # Runs in the parent when stderr data is read from the child.
      print "[stderr] " . $child->tag . " $chunk";
    },

    on_exit => sub ($child, $exit) {
      # Runs in the parent when the child reaps.
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
