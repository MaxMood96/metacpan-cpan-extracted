#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(is_empty_array is_empty_hash array_len hash_size array_first array_last));

# ============================================
# is_empty_array tests - direct AvFILL check
# ============================================

ok(is_empty_array([]), 'empty arrayref is empty');
ok(!is_empty_array([1]), 'arrayref with 1 element is not empty');
ok(!is_empty_array([1, 2, 3]), 'arrayref with 3 elements is not empty');
ok(!is_empty_array([undef]), 'arrayref with undef is not empty');

# Non-arrayrefs return false
ok(!is_empty_array({}), 'hashref is not an empty array');
ok(!is_empty_array("hello"), 'string is not an empty array');
ok(!is_empty_array(42), 'number is not an empty array');
ok(!is_empty_array(undef), 'undef is not an empty array');
ok(!is_empty_array(sub {}), 'coderef is not an empty array');

# ============================================
# is_empty_hash tests - direct HvKEYS check
# ============================================

ok(is_empty_hash({}), 'empty hashref is empty');
ok(!is_empty_hash({a => 1}), 'hashref with 1 key is not empty');
ok(!is_empty_hash({a => 1, b => 2}), 'hashref with 2 keys is not empty');
ok(!is_empty_hash({a => undef}), 'hashref with undef value is not empty');

# Non-hashrefs return false
ok(!is_empty_hash([]), 'arrayref is not an empty hash');
ok(!is_empty_hash("hello"), 'string is not an empty hash');
ok(!is_empty_hash(42), 'number is not an empty hash');
ok(!is_empty_hash(undef), 'undef is not an empty hash');
ok(!is_empty_hash(sub {}), 'coderef is not an empty hash');

# ============================================
# array_len tests - direct AvFILL + 1
# ============================================

is(array_len([]), 0, 'empty array has length 0');
is(array_len([1]), 1, 'single element array has length 1');
is(array_len([1, 2, 3]), 3, 'three element array has length 3');
is(array_len([undef, undef]), 2, 'array with undefs has correct length');

# Large array
my @large = (1..1000);
is(array_len(\@large), 1000, 'large array has correct length');

# Non-arrayref returns undef
is(array_len({}), undef, 'hashref returns undef for array_len');
is(array_len("hello"), undef, 'string returns undef for array_len');
is(array_len(undef), undef, 'undef returns undef for array_len');

# ============================================
# hash_size tests - direct HvKEYS
# ============================================

is(hash_size({}), 0, 'empty hash has size 0');
is(hash_size({a => 1}), 1, 'single key hash has size 1');
is(hash_size({a => 1, b => 2, c => 3}), 3, 'three key hash has size 3');

# Large hash
my %large = map { $_ => 1 } 1..1000;
is(hash_size(\%large), 1000, 'large hash has correct size');

# Non-hashref returns undef
is(hash_size([]), undef, 'arrayref returns undef for hash_size');
is(hash_size("hello"), undef, 'string returns undef for hash_size');
is(hash_size(undef), undef, 'undef returns undef for hash_size');

# ============================================
# array_first tests - get first element
# ============================================

is(array_first([1, 2, 3]), 1, 'first element of [1,2,3] is 1');
is(array_first(['a', 'b', 'c']), 'a', 'first element of [a,b,c] is a');
is(array_first([42]), 42, 'first element of single-element array');
is(array_first([undef, 1, 2]), undef, 'first element can be undef');

# Empty array
is(array_first([]), undef, 'first of empty array is undef');

# Non-arrayref returns undef
is(array_first({}), undef, 'first of hashref is undef');
is(array_first("hello"), undef, 'first of string is undef');
is(array_first(undef), undef, 'first of undef is undef');

# ============================================
# array_last tests - get last element
# ============================================

is(array_last([1, 2, 3]), 3, 'last element of [1,2,3] is 3');
is(array_last(['a', 'b', 'c']), 'c', 'last element of [a,b,c] is c');
is(array_last([42]), 42, 'last element of single-element array');
is(array_last([1, 2, undef]), undef, 'last element can be undef');

# Empty array
is(array_last([]), undef, 'last of empty array is undef');

# Non-arrayref returns undef
is(array_last({}), undef, 'last of hashref is undef');
is(array_last("hello"), undef, 'last of string is undef');
is(array_last(undef), undef, 'last of undef is undef');

# ============================================
# Test with variables (ensures custom ops work)
# ============================================

my $arr = [10, 20, 30];
my $hash = { x => 1, y => 2 };
my $empty_arr = [];
my $empty_hash = {};

ok(!is_empty_array($arr), 'variable non-empty array');
ok(is_empty_array($empty_arr), 'variable empty array');
ok(!is_empty_hash($hash), 'variable non-empty hash');
ok(is_empty_hash($empty_hash), 'variable empty hash');

is(array_len($arr), 3, 'variable array length');
is(hash_size($hash), 2, 'variable hash size');
is(array_first($arr), 10, 'variable array first');
is(array_last($arr), 30, 'variable array last');

# ============================================
# Test return values
# ============================================

is(is_empty_array([]), 1, 'is_empty_array returns 1 for true');
is(is_empty_array([1]), '', 'is_empty_array returns empty for false');

is(is_empty_hash({}), 1, 'is_empty_hash returns 1 for true');
is(is_empty_hash({a => 1}), '', 'is_empty_hash returns empty for false');

done_testing;
