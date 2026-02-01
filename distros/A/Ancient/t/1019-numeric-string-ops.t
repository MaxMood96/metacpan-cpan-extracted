#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(sign min2 max2 ltrim rtrim));

# ============================================
# sign tests - returns -1, 0, or 1
# ============================================

is(sign(42), 1, 'positive integer returns 1');
is(sign(3.14), 1, 'positive float returns 1');
is(sign(0.001), 1, 'small positive returns 1');
is(sign("42"), 1, 'positive string returns 1');

is(sign(-42), -1, 'negative integer returns -1');
is(sign(-3.14), -1, 'negative float returns -1');
is(sign(-0.001), -1, 'small negative returns -1');
is(sign("-42"), -1, 'negative string returns -1');

is(sign(0), 0, 'zero returns 0');
is(sign(0.0), 0, 'zero float returns 0');
is(sign("0"), 0, 'zero string returns 0');

is(sign(undef), undef, 'undef returns undef');
is(sign("hello"), undef, 'non-numeric string returns undef');
is(sign([]), undef, 'arrayref returns undef');
is(sign({}), undef, 'hashref returns undef');

# Test with variables
my $pos = 100;
my $neg = -100;
my $zero = 0;

is(sign($pos), 1, 'variable positive');
is(sign($neg), -1, 'variable negative');
is(sign($zero), 0, 'variable zero');

# ============================================
# min2 tests - return smaller of two values
# ============================================

is(min2(1, 2), 1, 'min2(1, 2) = 1');
is(min2(2, 1), 1, 'min2(2, 1) = 1');
is(min2(5, 5), 5, 'min2(5, 5) = 5 (equal values)');

is(min2(-5, 5), -5, 'min2(-5, 5) = -5');
is(min2(5, -5), -5, 'min2(5, -5) = -5');

is(min2(3.14, 2.71), 2.71, 'min2 with floats');
is(min2(0, -0), 0, 'min2(0, -0) = 0');

is(min2("10", "9"), "9", 'min2 with numeric strings (numeric comparison)');
is(min2("100", "20"), "20", 'min2 numeric comparison not string');

# Test with variables
my $a = 10;
my $b = 20;
is(min2($a, $b), 10, 'variable min2');
is(min2($b, $a), 10, 'variable min2 reversed');

# ============================================
# max2 tests - return larger of two values
# ============================================

is(max2(1, 2), 2, 'max2(1, 2) = 2');
is(max2(2, 1), 2, 'max2(2, 1) = 2');
is(max2(5, 5), 5, 'max2(5, 5) = 5 (equal values)');

is(max2(-5, 5), 5, 'max2(-5, 5) = 5');
is(max2(5, -5), 5, 'max2(5, -5) = 5');

is(max2(3.14, 2.71), 3.14, 'max2 with floats');

is(max2("10", "9"), "10", 'max2 with numeric strings');
is(max2("100", "20"), "100", 'max2 numeric comparison not string');

# Test with variables
is(max2($a, $b), 20, 'variable max2');
is(max2($b, $a), 20, 'variable max2 reversed');

# ============================================
# ltrim tests - remove leading whitespace only
# ============================================

is(ltrim("hello"), "hello", 'ltrim no whitespace');
is(ltrim("  hello"), "hello", 'ltrim leading spaces');
is(ltrim("\t\nhello"), "hello", 'ltrim leading tabs/newlines');
is(ltrim("  hello  "), "hello  ", 'ltrim preserves trailing');
is(ltrim("   "), "", 'ltrim all whitespace');
is(ltrim(""), "", 'ltrim empty string');
is(ltrim(undef), undef, 'ltrim undef returns undef');

# Internal whitespace preserved
is(ltrim("  hello world  "), "hello world  ", 'ltrim preserves internal and trailing');

# Test with variables
my $str_with_leading = "   trimmed";
is(ltrim($str_with_leading), "trimmed", 'variable ltrim');

# ============================================
# rtrim tests - remove trailing whitespace only
# ============================================

is(rtrim("hello"), "hello", 'rtrim no whitespace');
is(rtrim("hello  "), "hello", 'rtrim trailing spaces');
is(rtrim("hello\t\n"), "hello", 'rtrim trailing tabs/newlines');
is(rtrim("  hello  "), "  hello", 'rtrim preserves leading');
is(rtrim("   "), "", 'rtrim all whitespace');
is(rtrim(""), "", 'rtrim empty string');
is(rtrim(undef), undef, 'rtrim undef returns undef');

# Internal whitespace preserved
is(rtrim("  hello world  "), "  hello world", 'rtrim preserves leading and internal');

# Test with variables
my $str_with_trailing = "trimmed   ";
is(rtrim($str_with_trailing), "trimmed", 'variable rtrim');

# ============================================
# Combined use cases
# ============================================

# Clamping with min2/max2
my $value = 15;
my $clamped = min2(max2($value, 0), 10);  # clamp to 0-10
is($clamped, 10, 'min2/max2 as clamp (upper bound)');

$value = -5;
$clamped = min2(max2($value, 0), 10);
is($clamped, 0, 'min2/max2 as clamp (lower bound)');

$value = 5;
$clamped = min2(max2($value, 0), 10);
is($clamped, 5, 'min2/max2 as clamp (in range)');

# Sign for direction
my @nums = (-5, 0, 3, -2, 7);
my @signs = map { sign($_) } @nums;
is_deeply(\@signs, [-1, 0, 1, -1, 1], 'sign on list');

# ltrim + rtrim = trim behavior
my $messy = "  content  ";
is(rtrim(ltrim($messy)), "content", 'ltrim + rtrim = trim');

done_testing;
