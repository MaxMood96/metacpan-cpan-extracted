#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

my $loop   = Linux::Event->new;
my $forker = Linux::Event::Fork->new($loop, max_children => 1);

# Hard safety timeout for the test itself
local $SIG{ALRM} = sub {
    fail("test timed out (drain did not fire)");
    $loop->stop;
};
alarm 5;

my $cmd = [ $^X, '-we', 'select undef,undef,undef,0.02; exit 0' ];

my $a = $forker->spawn(cmd => $cmd);
my $b = $forker->spawn(cmd => $cmd);
my $c = $forker->spawn(cmd => $cmd);

is(ref($a), 'Linux::Event::Fork::Child',   'first spawn starts immediately');
is(ref($b), 'Linux::Event::Fork::Request', 'second spawn queues');
is(ref($c), 'Linux::Event::Fork::Request', 'third spawn queues');

is($forker->running, 1, 'running=1 at max_children=1');
is($forker->queued,  2, 'queued=2 at max_children=1');

$forker->max_children(3);

is($forker->max_children, 3, 'max_children updated at runtime');
is($forker->queued,  0, 'queue drained after increasing max_children');
is($forker->running, 3, 'running increased after increasing max_children');

$forker->drain(on_done => sub ($f) {
    pass('drain fired');
    $loop->stop;
});

$loop->run;
alarm 0;

done_testing;
