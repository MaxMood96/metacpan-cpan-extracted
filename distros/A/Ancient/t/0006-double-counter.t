#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch', 't/lib';

use_ok('Counter');
use_ok('DoubleCounter');

# Test DoubleCounter inherits from Counter
my $dc = DoubleCounter->new(3);  # multiply by 3
isa_ok($dc, 'DoubleCounter');
isa_ok($dc, 'Counter');

is(Counter::count(), 0, 'count starts at 0');
is(DoubleCounter::multiplier(), 3, 'multiplier set correctly');

# Test that increment uses multiplier
$dc->increment();
is(Counter::count(), 3, 'increment multiplies by 3');

$dc->increment();
is(Counter::count(), 6, 'second increment adds 3 more');

# Test that parent decrement still works normally
$dc->decrement();
is(Counter::count(), 5, 'decrement still decrements by 1');

# Test reset
$dc->reset();
is(Counter::count(), 0, 'reset from parent works');

# Test with default multiplier
my $dc2 = DoubleCounter->new();
is(DoubleCounter::multiplier(), 2, 'default multiplier is 2');

done_testing();
