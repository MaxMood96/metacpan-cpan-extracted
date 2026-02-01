#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(is_true is_false bool));

# ============================================
# is_true tests - Perl truth semantics
# ============================================

ok(is_true(1), '1 is true');
ok(is_true("hello"), '"hello" is true');
ok(is_true("0 but true"), '"0 but true" is true');
ok(is_true([]), 'arrayref is true');
ok(is_true({}), 'hashref is true');
ok(is_true(sub {}), 'coderef is true');
ok(is_true(\1), 'scalarref is true');
ok(is_true(-1), '-1 is true');
ok(is_true(0.1), '0.1 is true');
ok(is_true(" "), 'space is true');

ok(!is_true(0), '0 is not true');
ok(!is_true(""), 'empty string is not true');
ok(!is_true("0"), '"0" is not true');
ok(!is_true(undef), 'undef is not true');

# ============================================
# is_false tests - opposite of is_true
# ============================================

ok(is_false(0), '0 is false');
ok(is_false(""), 'empty string is false');
ok(is_false("0"), '"0" is false');
ok(is_false(undef), 'undef is false');

ok(!is_false(1), '1 is not false');
ok(!is_false("hello"), '"hello" is not false');
ok(!is_false([]), 'arrayref is not false');
ok(!is_false({}), 'hashref is not false');
ok(!is_false(sub {}), 'coderef is not false');
ok(!is_false(-1), '-1 is not false');
ok(!is_false(0.1), '0.1 is not false');

# ============================================
# bool tests - normalize to boolean
# ============================================

is(bool(1), 1, 'bool(1) returns 1');
is(bool("hello"), 1, 'bool("hello") returns 1');
is(bool([]), 1, 'bool([]) returns 1');
is(bool({}), 1, 'bool({}) returns 1');

is(bool(0), '', 'bool(0) returns empty');
is(bool(""), '', 'bool("") returns empty');
is(bool("0"), '', 'bool("0") returns empty');
is(bool(undef), '', 'bool(undef) returns empty');

# ============================================
# Test with variables (ensures custom ops work)
# ============================================

my $true_val = 1;
my $false_val = 0;
my $empty = "";
my $str = "hello";
my $undef = undef;

ok(is_true($true_val), 'variable true value is true');
ok(!is_true($false_val), 'variable false value is not true');
ok(!is_true($empty), 'variable empty string is not true');
ok(is_true($str), 'variable string is true');
ok(!is_true($undef), 'variable undef is not true');

ok(!is_false($true_val), 'variable true value is not false');
ok(is_false($false_val), 'variable false value is false');
ok(is_false($empty), 'variable empty string is false');
ok(!is_false($str), 'variable string is not false');
ok(is_false($undef), 'variable undef is false');

is(bool($true_val), 1, 'bool of variable true returns 1');
is(bool($false_val), '', 'bool of variable false returns empty');

# ============================================
# Test in boolean context
# ============================================

if (is_true($str)) {
    pass('is_true works in boolean context');
} else {
    fail('is_true works in boolean context');
}

if (is_false($empty)) {
    pass('is_false works in boolean context');
} else {
    fail('is_false works in boolean context');
}

# ============================================
# Test return values are proper booleans
# ============================================

is(is_true(1), 1, 'is_true returns 1 for true');
is(is_true(0), '', 'is_true returns empty string for false');

is(is_false(0), 1, 'is_false returns 1 for true');
is(is_false(1), '', 'is_false returns empty string for false');

# ============================================
# Edge cases
# ============================================

# "0 but true" is a special Perl value that's true
ok(is_true("0 but true"), '"0 but true" is true');
ok(!is_false("0 but true"), '"0 but true" is not false');

# Numeric context tests
my $zero_float = 0.0;
my $neg_zero = -0;
ok(!is_true($zero_float), '0.0 is not true');
ok(is_false($zero_float), '0.0 is false');
ok(!is_true($neg_zero), '-0 is not true');
ok(is_false($neg_zero), '-0 is false');

done_testing;
