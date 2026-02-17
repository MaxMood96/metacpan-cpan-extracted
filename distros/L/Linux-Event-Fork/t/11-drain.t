#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Test2::V0;

use Linux::Event;
use Linux::Event::Fork max_children => 2;

my $loop = Linux::Event->new;

my $N = $ENV{N} // 12;

my $started  = 0;
my $finished = 0;

for my $i (1..$N) {
  $loop->fork(
    tag => "job:$i",
    cmd => [ $^X, '-we', 'select(undef,undef,undef,0.02); print "x\n"; exit 0' ],

    on_start => sub ($child) { $started++ },

    on_exit => sub ($child, $exit) {
      $finished++;
    },
  );
}

my $fork = $loop->fork_helper;

my $drain_fired = 0;
$fork->drain(on_done => sub ($fork_obj) {
  $drain_fired++;
  $loop->stop;
});

local $SIG{ALRM} = sub {
  diag("timeout waiting for drain; started=$started finished=$finished");
  diag("fork running=".$fork->running." queued=".$fork->queued);
  bail_out("t/11-drain.t hung");
};
alarm($ENV{ALARM} // 10);
$loop->run;
alarm(0);

is($started,  $N, 'all jobs started');
is($finished, $N, 'all jobs finished');
is($drain_fired, 1, 'drain fired exactly once');

# Immediate drain when already idle.
my $loop2 = Linux::Event->new;
my $f2 = $loop2->fork_helper;
my $immediate = 0;
$f2->drain(on_done => sub { $immediate++ });
is($immediate, 1, 'drain fires immediately when idle');

done_testing;
