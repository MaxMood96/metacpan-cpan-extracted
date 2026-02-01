#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use blib;

use util qw(uniq);

# ============================================
# uniq tests
# ============================================

# Basic deduplication
my @nums = (1, 2, 2, 3, 3, 3, 4);
is_deeply([uniq(@nums)], [1, 2, 3, 4], 'uniq: removes duplicates');

# Preserves order
my @letters = qw(c a b a c b);
is_deeply([uniq(@letters)], [qw(c a b)], 'uniq: preserves first occurrence order');

# Empty list
is_deeply([uniq()], [], 'uniq: empty list');

# Single element
is_deeply([uniq(42)], [42], 'uniq: single element');

# All same
is_deeply([uniq(1, 1, 1, 1)], [1], 'uniq: all same');

# All unique
is_deeply([uniq(1, 2, 3, 4)], [1, 2, 3, 4], 'uniq: all unique');

# Strings
my @words = qw(apple banana apple cherry banana date);
is_deeply([uniq(@words)], [qw(apple banana cherry date)], 'uniq: strings');

# Mixed types (stringified comparison)
my @mixed = (1, "1", 2, "2", 1);
is_deeply([uniq(@mixed)], [1, 2], 'uniq: mixed numeric/string');

# With undef values
my @with_undef = (1, undef, 2, undef, 3);
my @result = uniq(@with_undef);
is(scalar @result, 4, 'uniq: handles undef (count)');
is($result[0], 1, 'uniq: undef - first elem');
ok(!defined $result[1], 'uniq: undef - second is undef');
is($result[2], 2, 'uniq: undef - third elem');
is($result[3], 3, 'uniq: undef - fourth elem');

# Multiple undefs become one
my @all_undef = (undef, undef, undef);
my @undef_result = uniq(@all_undef);
is(scalar @undef_result, 1, 'uniq: multiple undef become one');
ok(!defined $undef_result[0], 'uniq: result is undef');

# Empty strings
my @empties = ('', 'a', '', 'b', '');
is_deeply([uniq(@empties)], ['', 'a', 'b'], 'uniq: handles empty strings');

# Numeric edge cases
my @nums2 = (0, 0.0, "0", 1, 1.0, "1");
is_deeply([uniq(@nums2)], [0, 1], 'uniq: numeric edge cases');

# Large list
my @large = map { $_ % 10 } 1..1000;
my @large_uniq = uniq(@large);
is(scalar @large_uniq, 10, 'uniq: handles large list');

done_testing;
