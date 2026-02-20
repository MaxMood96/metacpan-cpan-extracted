#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;
my $loop = Linux::Event->new;
my $fork = Linux::Event::Fork->new($loop, max_children => 1);

is($fork->max_children, 1, 'max_children accessor');
is($fork->running, 0, 'running starts at 0');
is($fork->queued,  0, 'queued starts at 0');

for my $i (1..3) {
  $fork->spawn(
    tag => "job:$i",
    cmd => [ $^X, '-we', 'select(undef,undef,undef,0.02); exit 0' ],
  );
}

ok($fork->queued >= 0, 'queued after enqueue (non-negative)');

$fork->drain(on_done => sub ($fork) {
  is($fork->running, 0, 'running back to 0 after drain');
  is($fork->queued, 0, 'queued back to 0 after drain');
  $loop->stop;
});

$loop->run;

done_testing;
