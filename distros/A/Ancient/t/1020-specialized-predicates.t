#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(
    first_gt first_lt first_ge first_le first_eq first_ne
    any_gt any_lt any_ge any_le any_eq any_ne
    all_gt all_lt all_ge all_le all_eq all_ne
    none_gt none_lt none_ge none_le none_eq none_ne
));

# ============================================
# Test data
# ============================================

my @numbers = (1, 5, 10, 15, 20, 25);
my @empty = ();

my @users = (
    { name => 'Alice', age => 25 },
    { name => 'Bob', age => 17 },
    { name => 'Carol', age => 30 },
    { name => 'Dave', age => 22 },
);

# ============================================
# first_* tests with scalars (2-arg form)
# ============================================

# first_gt
is(first_gt(\@numbers, 10), 15, 'first_gt: finds first > 10');
is(first_gt(\@numbers, 0), 1, 'first_gt: finds first > 0');
is(first_gt(\@numbers, 100), undef, 'first_gt: undef when no match');
is(first_gt(\@empty, 0), undef, 'first_gt: undef for empty array');

# first_lt
is(first_lt(\@numbers, 10), 1, 'first_lt: finds first < 10');
is(first_lt(\@numbers, 2), 1, 'first_lt: finds first < 2');
is(first_lt(\@numbers, 0), undef, 'first_lt: undef when no match');

# first_ge
is(first_ge(\@numbers, 10), 10, 'first_ge: finds first >= 10');
is(first_ge(\@numbers, 15), 15, 'first_ge: finds first >= 15');
is(first_ge(\@numbers, 1), 1, 'first_ge: finds first element when >= min');

# first_le
is(first_le(\@numbers, 10), 1, 'first_le: finds first <= 10');
is(first_le(\@numbers, 5), 1, 'first_le: finds first <= 5');
is(first_le(\@numbers, 0), undef, 'first_le: undef when no match');

# first_eq
is(first_eq(\@numbers, 10), 10, 'first_eq: finds exact match');
is(first_eq(\@numbers, 1), 1, 'first_eq: finds first element');
is(first_eq(\@numbers, 99), undef, 'first_eq: undef when no match');

# first_ne
is(first_ne(\@numbers, 1), 5, 'first_ne: finds first != 1');
is(first_ne(\@numbers, 99), 1, 'first_ne: finds first != non-existent');

# ============================================
# first_* tests with hashes (3-arg form)
# ============================================

my $adult = first_ge(\@users, 'age', 18);
is($adult->{name}, 'Alice', 'first_ge (hash): finds first adult');

my $minor = first_lt(\@users, 'age', 18);
is($minor->{name}, 'Bob', 'first_lt (hash): finds first minor');

my $exact = first_eq(\@users, 'age', 22);
is($exact->{name}, 'Dave', 'first_eq (hash): finds exact age');

my $not_25 = first_ne(\@users, 'age', 25);
is($not_25->{name}, 'Bob', 'first_ne (hash): finds first not 25');

my $over_30 = first_gt(\@users, 'age', 30);
is($over_30, undef, 'first_gt (hash): undef when no match');

# ============================================
# any_* tests with scalars
# ============================================

ok(any_gt(\@numbers, 10), 'any_gt: true when some > 10');
ok(!any_gt(\@numbers, 100), 'any_gt: false when none > 100');
ok(!any_gt(\@empty, 0), 'any_gt: false for empty array');

ok(any_lt(\@numbers, 10), 'any_lt: true when some < 10');
ok(!any_lt(\@numbers, 0), 'any_lt: false when none < 0');

ok(any_ge(\@numbers, 25), 'any_ge: true when some >= 25');
ok(!any_ge(\@numbers, 100), 'any_ge: false when none >= 100');

ok(any_le(\@numbers, 1), 'any_le: true when some <= 1');
ok(!any_le(\@numbers, 0), 'any_le: false when none <= 0');

ok(any_eq(\@numbers, 10), 'any_eq: true when 10 exists');
ok(!any_eq(\@numbers, 99), 'any_eq: false when 99 not found');

ok(any_ne(\@numbers, 1), 'any_ne: true when some != 1');

# ============================================
# any_* tests with hashes
# ============================================

ok(any_lt(\@users, 'age', 18), 'any_lt (hash): finds minor');
ok(!any_lt(\@users, 'age', 10), 'any_lt (hash): no one under 10');
ok(any_ge(\@users, 'age', 30), 'any_ge (hash): finds 30+');
ok(any_eq(\@users, 'age', 17), 'any_eq (hash): finds exact 17');

# ============================================
# all_* tests with scalars
# ============================================

ok(all_gt(\@numbers, 0), 'all_gt: true when all > 0');
ok(!all_gt(\@numbers, 10), 'all_gt: false when some not > 10');
ok(all_gt(\@empty, 100), 'all_gt: true for empty (vacuous truth)');

ok(all_lt(\@numbers, 100), 'all_lt: true when all < 100');
ok(!all_lt(\@numbers, 10), 'all_lt: false when some not < 10');

ok(all_ge(\@numbers, 1), 'all_ge: true when all >= 1');
ok(!all_ge(\@numbers, 5), 'all_ge: false when some not >= 5');

ok(all_le(\@numbers, 25), 'all_le: true when all <= 25');
ok(!all_le(\@numbers, 10), 'all_le: false when some not <= 10');

my @same = (5, 5, 5, 5);
ok(all_eq(\@same, 5), 'all_eq: true when all equal 5');
ok(!all_eq(\@numbers, 5), 'all_eq: false when not all equal');

ok(all_ne(\@numbers, 99), 'all_ne: true when none equal 99');
ok(!all_ne(\@numbers, 10), 'all_ne: false when some equal 10');

# ============================================
# all_* tests with hashes
# ============================================

ok(!all_ge(\@users, 'age', 18), 'all_ge (hash): not all adults');
ok(all_gt(\@users, 'age', 10), 'all_gt (hash): all over 10');

# ============================================
# none_* tests with scalars
# ============================================

ok(none_gt(\@numbers, 100), 'none_gt: true when none > 100');
ok(!none_gt(\@numbers, 10), 'none_gt: false when some > 10');
ok(none_gt(\@empty, 0), 'none_gt: true for empty array');

ok(none_lt(\@numbers, 0), 'none_lt: true when none < 0');
ok(!none_lt(\@numbers, 10), 'none_lt: false when some < 10');

ok(none_ge(\@numbers, 100), 'none_ge: true when none >= 100');
ok(!none_ge(\@numbers, 25), 'none_ge: false when some >= 25');

ok(none_le(\@numbers, 0), 'none_le: true when none <= 0');
ok(!none_le(\@numbers, 1), 'none_le: false when some <= 1');

ok(none_eq(\@numbers, 99), 'none_eq: true when 99 not found');
ok(!none_eq(\@numbers, 10), 'none_eq: false when 10 exists');

ok(!none_ne(\@numbers, 99), 'none_ne: false when all != 99');

# ============================================
# none_* tests with hashes
# ============================================

ok(none_lt(\@users, 'age', 10), 'none_lt (hash): none under 10');
ok(!none_lt(\@users, 'age', 18), 'none_lt (hash): some under 18');

# ============================================
# Edge cases
# ============================================

# Single element arrays
my @single = (42);
is(first_gt(\@single, 41), 42, 'single element: first_gt match');
is(first_gt(\@single, 42), undef, 'single element: first_gt no match');
ok(any_eq(\@single, 42), 'single element: any_eq match');
ok(all_eq(\@single, 42), 'single element: all_eq match');
ok(none_eq(\@single, 99), 'single element: none_eq true');

# Array with zeros
my @with_zero = (0, 1, 2);
is(first_gt(\@with_zero, -1), 0, 'first_gt: works with zero');
ok(any_eq(\@with_zero, 0), 'any_eq: finds zero');

# Negative numbers
my @negatives = (-5, -3, -1, 0, 1);
is(first_gt(\@negatives, -2), -1, 'first_gt: works with negatives');
is(first_lt(\@negatives, 0), -5, 'first_lt: finds first negative');
ok(all_gt(\@negatives, -10), 'all_gt: all > -10');

# Floating point
my @floats = (1.5, 2.5, 3.5);
is(first_gt(\@floats, 2.0), 2.5, 'first_gt: works with floats');
ok(all_gt(\@floats, 1.0), 'all_gt: all > 1.0');

# ============================================
# Practical examples
# ============================================

# Find first user who can vote (age >= 18)
my $voter = first_ge(\@users, 'age', 18);
ok($voter && $voter->{age} >= 18, 'practical: find first voter');

# Check if any user is a teenager (13-19)
my @teens = grep { $_->{age} >= 13 && $_->{age} <= 19 } @users;
ok(@teens > 0, 'practical: has teenagers');

# Check if all users are adults
ok(!all_ge(\@users, 'age', 18), 'practical: not all adults');

# Check if no one is over 100
ok(none_gt(\@users, 'age', 100), 'practical: no centenarians');

done_testing;
