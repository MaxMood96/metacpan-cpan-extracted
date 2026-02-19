#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;
my $loop = Linux::Event->new;

$loop->fork_helper(max_children => 1);
# Ensure helper exists
my $fork = $loop->fork_helper;

my @tags = map { "job:$_" } 1..5;

my %started;
my %exited;

for my $tag (@tags) {
  $loop->fork(
    tag => $tag,
    cmd => [ $^X, '-we', 'select(undef,undef,undef,0.05); print "x\n"; exit 0' ],

    on_start => sub ($child) {
      $started{$child->tag}++;
    },

    on_exit => sub ($child, $exit) {
      $exited{$child->tag}++;
    },
  );
}

# With max_children => 1, one job should start immediately and 4 should be queued.
# Cancel queued jobs 3..5 (keep 1 and 2).
my $canceled = $fork->cancel_queued(sub ($req) {
  my $t = $req->tag // '';
  return $t eq 'job:3' || $t eq 'job:4' || $t eq 'job:5';
});

is($canceled, 3, 'canceled 3 queued jobs');

# Drain should complete after job:1 and job:2 have run.
$fork->drain(on_done => sub ($fork) {
  $loop->stop;
});

$loop->run;

ok($started{'job:1'} >= 1, 'job:1 started');
ok($started{'job:2'} >= 1, 'job:2 started');

ok(!$started{'job:3'}, 'job:3 never started');
ok(!$started{'job:4'}, 'job:4 never started');
ok(!$started{'job:5'}, 'job:5 never started');

ok($exited{'job:1'} >= 1, 'job:1 exited');
ok($exited{'job:2'} >= 1, 'job:2 exited');

ok(!$exited{'job:3'}, 'job:3 never exited (never started)');
ok(!$exited{'job:4'}, 'job:4 never exited (never started)');
ok(!$exited{'job:5'}, 'job:5 never exited (never started)');

done_testing;
