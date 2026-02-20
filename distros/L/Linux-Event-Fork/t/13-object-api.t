#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

my $forker = Linux::Event::Fork->new($loop, max_children => 4);

ok($forker->can('spawn'), 'fork helper has spawn()');
is($forker->max_children, 4, 'max_children set');
is($forker->running, 0, 'running starts at 0');
is($forker->queued, 0, 'queued starts at 0');

done_testing;
