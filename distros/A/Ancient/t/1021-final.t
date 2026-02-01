#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(
    final
    final_gt final_lt final_ge final_le final_eq final_ne
));

# ============================================
# Test data
# ============================================

my @numbers = (1, 5, 10, 15, 20, 25);
my @empty = ();
my @duplicates = (5, 10, 15, 10, 20, 10, 25);

my @users = (
    { name => 'Alice', age => 25 },
    { name => 'Bob', age => 17 },
    { name => 'Carol', age => 30 },
    { name => 'Dave', age => 17 },
    { name => 'Eve', age => 22 },
);

# ============================================
# final (callback version) tests
# ============================================

is(final(sub { $_ > 10 }, \@numbers), 25, 'final: finds last > 10');
is(final(sub { $_ < 20 }, \@numbers), 15, 'final: finds last < 20');
is(final(sub { $_ == 10 }, \@numbers), 10, 'final: finds exact match');
is(final(sub { $_ > 100 }, \@numbers), undef, 'final: undef when no match');
is(final(sub { $_ > 0 }, \@empty), undef, 'final: undef for empty array');

# final with hashrefs
my $last_minor = final(sub { $_->{age} < 18 }, \@users);
is($last_minor->{name}, 'Dave', 'final: finds last minor (Dave, not Bob)');

my $last_adult = final(sub { $_->{age} >= 18 }, \@users);
is($last_adult->{name}, 'Eve', 'final: finds last adult');

# ============================================
# final_* tests with scalars (2-arg form)
# ============================================

# final_gt
is(final_gt(\@numbers, 10), 25, 'final_gt: finds last > 10');
is(final_gt(\@numbers, 20), 25, 'final_gt: finds last > 20');
is(final_gt(\@numbers, 0), 25, 'final_gt: finds last > 0 (all match)');
is(final_gt(\@numbers, 100), undef, 'final_gt: undef when no match');
is(final_gt(\@empty, 0), undef, 'final_gt: undef for empty array');

# final_lt
is(final_lt(\@numbers, 20), 15, 'final_lt: finds last < 20');
is(final_lt(\@numbers, 10), 5, 'final_lt: finds last < 10');
is(final_lt(\@numbers, 0), undef, 'final_lt: undef when no match');

# final_ge
is(final_ge(\@numbers, 20), 25, 'final_ge: finds last >= 20');
is(final_ge(\@numbers, 25), 25, 'final_ge: finds last >= 25 (exact match)');
is(final_ge(\@numbers, 1), 25, 'final_ge: finds last >= 1 (all match)');

# final_le
is(final_le(\@numbers, 15), 15, 'final_le: finds last <= 15');
is(final_le(\@numbers, 10), 10, 'final_le: finds last <= 10');
is(final_le(\@numbers, 0), undef, 'final_le: undef when no match');

# final_eq with duplicates
is(final_eq(\@duplicates, 10), 10, 'final_eq: finds LAST occurrence of 10');
# Verify it's the last one by checking position
my @positions;
for my $i (0..$#duplicates) {
    push @positions, $i if $duplicates[$i] == 10;
}
is($positions[-1], 5, 'final_eq: confirms last 10 is at index 5');

is(final_eq(\@numbers, 99), undef, 'final_eq: undef when no match');

# final_ne
is(final_ne(\@numbers, 25), 20, 'final_ne: finds last != 25');
is(final_ne(\@numbers, 1), 25, 'final_ne: finds last != 1');

# ============================================
# final_* tests with hashes (3-arg form)
# ============================================

my $last_minor_hash = final_lt(\@users, 'age', 18);
is($last_minor_hash->{name}, 'Dave', 'final_lt (hash): finds last minor');

my $last_adult_hash = final_ge(\@users, 'age', 18);
is($last_adult_hash->{name}, 'Eve', 'final_ge (hash): finds last adult');

my $last_30plus = final_ge(\@users, 'age', 30);
is($last_30plus->{name}, 'Carol', 'final_ge (hash): finds last 30+');

my $last_not_17 = final_ne(\@users, 'age', 17);
is($last_not_17->{name}, 'Eve', 'final_ne (hash): finds last not 17');

# ============================================
# Edge cases
# ============================================

# Single element
my @single = (42);
is(final_gt(\@single, 41), 42, 'single element: final_gt match');
is(final_gt(\@single, 42), undef, 'single element: final_gt no match');
is(final(sub { $_ == 42 }, \@single), 42, 'single element: final callback match');

# All same value
my @same = (5, 5, 5, 5);
is(final_eq(\@same, 5), 5, 'all same: final_eq finds last');
is(final_gt(\@same, 4), 5, 'all same: final_gt finds last');
is(final_ne(\@same, 5), undef, 'all same: final_ne finds nothing');

# Negative numbers
my @negatives = (-5, -3, -1, 0, 1);
is(final_lt(\@negatives, 0), -1, 'final_lt: works with negatives');
is(final_gt(\@negatives, -2), 1, 'final_gt: last > -2 is 1');

# Floating point
my @floats = (1.5, 2.5, 3.5, 2.5, 4.5);
is(final_eq(\@floats, 2.5), 2.5, 'final_eq: finds last 2.5');
is(final_gt(\@floats, 3.0), 4.5, 'final_gt: works with floats');

# ============================================
# first vs final comparison
# ============================================

use util qw(first_gt first_eq);

# With duplicates, first and final should return different elements
is(first_eq(\@duplicates, 10), 10, 'first_eq: finds first 10');
is(final_eq(\@duplicates, 10), 10, 'final_eq: finds last 10');

# For @duplicates = (5, 10, 15, 10, 20, 10, 25)
# first_gt > 5 should return 10 (index 1)
# final_gt > 5 should return 25 (index 6)
is(first_gt(\@duplicates, 5), 10, 'first_gt: finds first > 5');
is(final_gt(\@duplicates, 5), 25, 'final_gt: finds last > 5');

# ============================================
# Practical examples
# ============================================

# Find most recent minor in a user list (assuming list is chronological)
my $recent_minor = final_lt(\@users, 'age', 18);
ok($recent_minor && $recent_minor->{age} < 18, 'practical: find most recent minor');

# Find last passing score
my @scores = (85, 70, 45, 90, 55, 80);
my $last_passing = final_ge(\@scores, 60);
is($last_passing, 80, 'practical: last passing score');

# Find last failing score
my $last_failing = final_lt(\@scores, 60);
is($last_failing, 55, 'practical: last failing score');

done_testing;
