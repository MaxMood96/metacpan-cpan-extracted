#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;
my $forker = Linux::Event::Fork->new($loop);

my $child = $forker->spawn(
  stdin_pipe => 1,

  child => sub {
    my $buf = '';
    my $n = 0;
    while (1) {
      my $r = sysread(STDIN, $buf, 65536);
      last if !defined $r || $r == 0;
      $n += $r;
    }
    print "child read $n bytes\n";
    exit 0;
  },

  on_stdout => sub ($child, $chunk) {
    print "[stdout] $chunk";
  },

  on_exit => sub ($child, $exit) {
    print "[exit] code=" . ($exit->exited ? $exit->code : 'n/a') . "\n";
    $loop->stop;
  },
);

my $payload = "hello\n" x 200000;  # ~1.2MB
my $off = 0;
my $len = length($payload);

while ($off < $len) {
  my $piece = substr($payload, $off, 131072);
  $child->stdin_write($piece);
  $off += length($piece);
}

$child->close_stdin;

$loop->run;
