#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(is_positive is_negative is_zero is_num is_int));

# ============================================
# is_positive tests - check if value is > 0
# ============================================

ok(is_positive(1), '1 is positive');
ok(is_positive(42), '42 is positive');
ok(is_positive(0.1), '0.1 is positive');
ok(is_positive(0.001), '0.001 is positive');
ok(is_positive("42"), '"42" string is positive');
ok(is_positive("3.14"), '"3.14" string is positive');
ok(is_positive(1e10), '1e10 is positive');
ok(is_positive("1e10"), '"1e10" string is positive');

ok(!is_positive(0), '0 is not positive');
ok(!is_positive(-1), '-1 is not positive');
ok(!is_positive(-42), '-42 is not positive');
ok(!is_positive(-0.1), '-0.1 is not positive');
ok(!is_positive("-42"), '"-42" string is not positive');
ok(!is_positive("hello"), '"hello" is not positive');
ok(!is_positive(""), 'empty string is not positive');
ok(!is_positive(undef), 'undef is not positive');
ok(!is_positive([]), 'arrayref is not positive');
ok(!is_positive({}), 'hashref is not positive');

# ============================================
# is_negative tests - check if value is < 0
# ============================================

ok(is_negative(-1), '-1 is negative');
ok(is_negative(-42), '-42 is negative');
ok(is_negative(-0.1), '-0.1 is negative');
ok(is_negative(-0.001), '-0.001 is negative');
ok(is_negative("-42"), '"-42" string is negative');
ok(is_negative("-3.14"), '"-3.14" string is negative');
ok(is_negative(-1e10), '-1e10 is negative');

ok(!is_negative(0), '0 is not negative');
ok(!is_negative(1), '1 is not negative');
ok(!is_negative(42), '42 is not negative');
ok(!is_negative(0.1), '0.1 is not negative');
ok(!is_negative("42"), '"42" string is not negative');
ok(!is_negative("hello"), '"hello" is not negative');
ok(!is_negative(""), 'empty string is not negative');
ok(!is_negative(undef), 'undef is not negative');
ok(!is_negative([]), 'arrayref is not negative');
ok(!is_negative({}), 'hashref is not negative');

# ============================================
# is_zero tests - check if value is == 0
# ============================================

ok(is_zero(0), '0 is zero');
ok(is_zero(0.0), '0.0 is zero');
ok(is_zero("0"), '"0" string is zero');
ok(is_zero("0.0"), '"0.0" string is zero');
ok(is_zero(-0), '-0 is zero');
ok(is_zero(0e0), '0e0 is zero');

ok(!is_zero(1), '1 is not zero');
ok(!is_zero(-1), '-1 is not zero');
ok(!is_zero(0.1), '0.1 is not zero');
ok(!is_zero(-0.1), '-0.1 is not zero');
ok(!is_zero("hello"), '"hello" is not zero');
ok(!is_zero(""), 'empty string is not zero');
ok(!is_zero(undef), 'undef is not zero');
ok(!is_zero([]), 'arrayref is not zero');
ok(!is_zero({}), 'hashref is not zero');

# ============================================
# Test with variables (ensures custom ops work)
# ============================================

my $pos = 42;
my $neg = -42;
my $zero_val = 0;
my $str = "hello";

ok(is_positive($pos), 'variable positive value');
ok(!is_positive($neg), 'variable negative is not positive');
ok(!is_positive($zero_val), 'variable zero is not positive');

ok(is_negative($neg), 'variable negative value');
ok(!is_negative($pos), 'variable positive is not negative');
ok(!is_negative($zero_val), 'variable zero is not negative');

ok(is_zero($zero_val), 'variable zero value');
ok(!is_zero($pos), 'variable positive is not zero');
ok(!is_zero($neg), 'variable negative is not zero');

# Non-numeric
ok(!is_positive($str), 'variable non-numeric is not positive');
ok(!is_negative($str), 'variable non-numeric is not negative');
ok(!is_zero($str), 'variable non-numeric is not zero');

# ============================================
# Test return values are proper booleans
# ============================================

is(is_positive(42), 1, 'is_positive returns 1 for true');
is(is_positive(-1), '', 'is_positive returns empty string for false');

is(is_negative(-42), 1, 'is_negative returns 1 for true');
is(is_negative(1), '', 'is_negative returns empty string for false');

is(is_zero(0), 1, 'is_zero returns 1 for true');
is(is_zero(1), '', 'is_zero returns empty string for false');

# ============================================
# Edge cases
# ============================================

# Very small positive/negative numbers
ok(is_positive(1e-100), 'very small positive is positive');
ok(is_negative(-1e-100), 'very small negative is negative');

# Infinity
my $inf = 9**9**9;  # Effectively infinity on most systems
ok(is_positive($inf), 'infinity is positive');

my $neg_inf = -9**9**9;
ok(is_negative($neg_inf), 'negative infinity is negative');

# Whitespace numeric strings
ok(is_positive("   42   "), 'numeric string with whitespace is positive');
ok(is_negative("  -42  "), 'negative numeric string with whitespace is negative');

done_testing;
