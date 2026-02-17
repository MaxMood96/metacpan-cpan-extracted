#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

my $fork = $loop->fork_helper(max_children => 2);

my $N = $ENV{N} // 10;

my $started = 0;
my $finished = 0;

my $running = 0;
my $max_seen = 0;

for my $i (1..$N) {
  my $h = $loop->fork(
    tag => "job:$i",
    cmd => [ $^X, '-we', 'select(undef,undef,undef,0.05); print "x\n"; exit 0' ],

    on_start => sub ($child) {
      $started++;
      $running++;
      $max_seen = $running if $running > $max_seen;
    },

    on_exit => sub ($child, $exit) {
      $finished++;
      $running--;
      $loop->stop if $finished == $N;
    },
  );

  ok($h->isa('Linux::Event::Fork::Child') || $h->isa('Linux::Event::Fork::Request'), 'handle type ok');
}

$loop->run;

is($started, $N, 'all jobs started');
is($finished, $N, 'all jobs finished');
ok($max_seen <= 2, "max concurrent <= 2 (saw $max_seen)");

done_testing;
