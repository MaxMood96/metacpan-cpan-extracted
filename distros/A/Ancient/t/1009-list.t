#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use blib;

use util qw(first any all none);

my @numbers = (1, 5, 10, 15, 20, 25);
my @empty = ();

# ============================================
# first tests
# ============================================

is(first(sub { $_ > 10 }, @numbers), 15, 'first: finds first > 10');
is(first(sub { $_ > 5 }, @numbers), 10, 'first: finds first > 5');
is(first(sub { $_ == 1 }, @numbers), 1, 'first: finds first element');
is(first(sub { $_ == 25 }, @numbers), 25, 'first: finds last element');
is(first(sub { $_ > 100 }, @numbers), undef, 'first: returns undef when no match');
is(first(sub { $_ > 0 }, @empty), undef, 'first: returns undef for empty list');

# first with $_
is(first(sub { $_ % 2 == 0 }, @numbers), 10, 'first: uses $_ correctly');

# Note: Unlike the call_sv implementation, MULTICALL only sets $_ (like List::Util)
# The element is NOT passed as $_[0], only as $_

# ============================================
# any tests
# ============================================

ok(any(sub { $_ > 10 }, @numbers), 'any: true when some match');
ok(any(sub { $_ == 25 }, @numbers), 'any: true for last element');
ok(any(sub { $_ == 1 }, @numbers), 'any: true for first element');
ok(!any(sub { $_ > 100 }, @numbers), 'any: false when none match');
ok(!any(sub { $_ > 0 }, @empty), 'any: false for empty list');

# any short-circuits
my $count = 0;
any(sub { $count++; $_ > 5 }, @numbers);
is($count, 3, 'any: short-circuits on first match');

# ============================================
# all tests
# ============================================

ok(all(sub { $_ > 0 }, @numbers), 'all: true when all match');
ok(all(sub { $_ <= 25 }, @numbers), 'all: true when all <= max');
ok(!all(sub { $_ > 10 }, @numbers), 'all: false when some dont match');
ok(!all(sub { $_ == 1 }, @numbers), 'all: false when only first matches');
ok(all(sub { $_ > 0 }, @empty), 'all: true for empty list (vacuous truth)');

# all short-circuits
$count = 0;
all(sub { $count++; $_ < 10 }, @numbers);
is($count, 3, 'all: short-circuits on first non-match');

# ============================================
# none tests
# ============================================

ok(none(sub { $_ > 100 }, @numbers), 'none: true when no match');
ok(none(sub { $_ < 0 }, @numbers), 'none: true for negative check');
ok(!none(sub { $_ > 10 }, @numbers), 'none: false when some match');
ok(!none(sub { $_ == 1 }, @numbers), 'none: false when first matches');
ok(none(sub { $_ > 0 }, @empty), 'none: true for empty list');

# none short-circuits
$count = 0;
none(sub { $count++; $_ > 5 }, @numbers);
is($count, 3, 'none: short-circuits on first match');

# ============================================
# Complex conditions
# ============================================

my @words = qw(apple banana cherry date elderberry);

is(first(sub { length($_) > 6 }, @words), 'elderberry', 'first: with string length');
ok(any(sub { /^b/ }, @words), 'any: with regex');
ok(all(sub { length($_) >= 4 }, @words), 'all: all words >= 4 chars');
ok(none(sub { /\d/ }, @words), 'none: no words contain digits');

# ============================================
# With hashrefs
# ============================================

my @users = (
    { name => 'Alice', age => 25 },
    { name => 'Bob', age => 17 },
    { name => 'Carol', age => 30 },
);

my $first_adult = first(sub { $_->{age} >= 18 }, @users);
is($first_adult->{name}, 'Alice', 'first: with hashref condition');

ok(any(sub { $_->{age} < 18 }, @users), 'any: finds minor');
ok(!all(sub { $_->{age} >= 18 }, @users), 'all: not all adults');
ok(none(sub { $_->{age} > 100 }, @users), 'none: no centenarians');

# ============================================
# Edge cases
# ============================================

# Single element
ok(any(sub { $_ == 42 }, 42), 'any: single matching element');
ok(!any(sub { $_ == 42 }, 99), 'any: single non-matching element');
ok(all(sub { $_ == 42 }, 42), 'all: single matching element');
ok(none(sub { $_ == 99 }, 42), 'none: single non-matching element');

done_testing;
