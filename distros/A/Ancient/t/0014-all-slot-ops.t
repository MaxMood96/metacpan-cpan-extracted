#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Test that all slot:: functions with constant names are optimized
# These should be compiled to custom ops when slot exists at compile time

use slot qw(opt_test);

# Initialize
opt_test(100);

# Test slot::get optimization
is(slot::get('opt_test'), 100, 'slot::get(const) works');

# Test slot::set optimization
is(slot::set('opt_test', 200), 200, 'slot::set(const,$v) works');
is(opt_test(), 200, 'slot::set updated value');

# Test slot::index optimization (constant folded)
my $idx = slot::index('opt_test');
is($idx, 0, 'slot::index(const) returns correct index');

# Test slot::watch optimization
my @events;
slot::watch('opt_test', sub {
    my ($name, $val) = @_;
    push @events, [$name, $val];
});
opt_test(300);
is(scalar @events, 1, 'slot::watch(const,$cb) fires');
is($events[0][0], 'opt_test', 'watcher gets name');
is($events[0][1], 300, 'watcher gets value');

# Test slot::unwatch optimization
slot::unwatch('opt_test');
opt_test(400);
is(scalar @events, 1, 'slot::unwatch(const) removes watchers');

# Test slot::clear optimization
slot::clear('opt_test');
is(opt_test(), undef, 'slot::clear(const) resets to undef');

# Test variable name falls back to XS correctly
my $name = 'opt_test';
opt_test(500);
is(slot::get($name), 500, 'slot::get($var) still works');
slot::set($name, 600);
is(opt_test(), 600, 'slot::set($var,$v) still works');

done_testing;
