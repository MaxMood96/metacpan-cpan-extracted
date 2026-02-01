#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Test that slot::get and slot::set work correctly
# When the name is a compile-time constant, these get optimized to custom ops

# Create slots first
use slot qw(alpha beta gamma);

# Set initial values
alpha(10);
beta(20);
gamma(30);

# Test slot::get with constant names
is(slot::get('alpha'), 10, 'slot::get alpha = 10');
is(slot::get('beta'), 20, 'slot::get beta = 20');
is(slot::get('gamma'), 30, 'slot::get gamma = 30');

# Test slot::set with constant names
is(slot::set('alpha', 100), 100, 'slot::set alpha to 100');
is(slot::set('beta', 200), 200, 'slot::set beta to 200');
is(slot::set('gamma', 300), 300, 'slot::set gamma to 300');

# Verify values changed
is(alpha(), 100, 'alpha now 100');
is(beta(), 200, 'beta now 200');
is(gamma(), 300, 'gamma now 300');

# Test with runtime variable name (falls back to XS)
my $name = 'alpha';
is(slot::get($name), 100, 'slot::get with variable name');
slot::set($name, 999);
is(slot::get($name), 999, 'slot::set with variable name');

# Test multiple operations in a loop with constants
for (1..5) {
    slot::set('alpha', $_ * 10);
    is(slot::get('alpha'), $_ * 10, "loop iteration $_");
}

# Test nonexistent slot
is(slot::get('nonexistent'), undef, 'get nonexistent returns undef');

# Test slot::add + get/set combo
slot::add('ephemeral');
is(slot::get('ephemeral'), undef, 'new slot starts undef');
slot::set('ephemeral', 'hi');
is(slot::get('ephemeral'), 'hi', 'set+get on added slot');

done_testing;
