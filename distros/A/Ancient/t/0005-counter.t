#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch', 't/lib';

use_ok('Counter');

# Test Counter class
my $counter = Counter->new();
isa_ok($counter, 'Counter');

is(Counter::count(), 0, 'count starts at 0');

# Test increment
$counter->increment();
is(Counter::count(), 1, 'increment works');

$counter->increment();
$counter->increment();
is(Counter::count(), 3, 'multiple increments work');

# Test decrement
$counter->decrement();
is(Counter::count(), 2, 'decrement works');

# Test reset
$counter->reset();
is(Counter::count(), 0, 'reset works');

# Test setter directly
Counter::count(50);
is(Counter::count(), 50, 'direct assignment works');

Counter::count(Counter::count() + 1);
is(Counter::count(), 51, 'increment via setter works');

done_testing();
