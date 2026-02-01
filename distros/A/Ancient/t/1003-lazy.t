#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(lazy force));

# Track if computation happened
my $computed = 0;

# Test basic lazy evaluation
my $lazy_val = lazy(sub {
    $computed++;
    return 42;
});

is($computed, 0, 'computation not run yet');

# Force the value
my $result = force($lazy_val);
is($result, 42, 'force returns correct value');
is($computed, 1, 'computation ran once');

# Force again - should return cached value
my $result2 = force($lazy_val);
is($result2, 42, 'force returns same value');
is($computed, 1, 'computation did not run again');

# Test lazy with expensive computation
my $calls = 0;
my $expensive = lazy(sub {
    $calls++;
    my $sum = 0;
    $sum += $_ for 1..1000;
    return $sum;
});

is($calls, 0, 'expensive not computed yet');
my $r1 = force($expensive);
is($r1, 500500, 'correct sum');
is($calls, 1, 'computed once');
my $r2 = force($expensive);
is($r2, 500500, 'cached value returned');
is($calls, 1, 'still only one computation');

# Test force on non-lazy value returns it as-is
is(force(123), 123, 'force on scalar returns scalar');
is(force('hello'), 'hello', 'force on string returns string');
is(force(undef), undef, 'force on undef returns undef');

my $ref = [1, 2, 3];
is(force($ref), $ref, 'force on arrayref returns same ref');

my $hash = {a => 1};
is(force($hash), $hash, 'force on hashref returns same ref');

# Test multiple independent lazy values
my ($a_computed, $b_computed) = (0, 0);
my $lazy_a = lazy(sub { $a_computed++; return 'A' });
my $lazy_b = lazy(sub { $b_computed++; return 'B' });

is($a_computed, 0, 'lazy_a not computed');
is($b_computed, 0, 'lazy_b not computed');

is(force($lazy_a), 'A', 'lazy_a value');
is($a_computed, 1, 'lazy_a computed once');
is($b_computed, 0, 'lazy_b still not computed');

is(force($lazy_b), 'B', 'lazy_b value');
is($b_computed, 1, 'lazy_b computed once');

# Test lazy returning complex data
my $lazy_hash = lazy(sub {
    return { name => 'test', values => [1, 2, 3] };
});

my $data = force($lazy_hash);
is_deeply($data, { name => 'test', values => [1, 2, 3] }, 'lazy returns complex data');

done_testing;
