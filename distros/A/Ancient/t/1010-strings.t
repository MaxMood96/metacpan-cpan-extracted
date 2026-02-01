#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(is_empty starts_with ends_with));

# ============================================
# is_empty tests
# ============================================

ok(is_empty(undef), 'undef is empty');
ok(is_empty(''), 'empty string is empty');
ok(!is_empty('hello'), 'non-empty string is not empty');
ok(!is_empty(' '), 'string with space is not empty');
ok(!is_empty('0'), 'string "0" is not empty');
ok(!is_empty(0), 'number 0 is not empty (stringifies to "0")');

# Test with variables
my $empty = '';
my $undef = undef;
my $str = 'hello';

ok(is_empty($empty), 'variable empty string is empty');
ok(is_empty($undef), 'variable undef is empty');
ok(!is_empty($str), 'variable non-empty string is not empty');

# ============================================
# starts_with tests
# ============================================

ok(starts_with('hello world', 'hello'), 'string starts with prefix');
ok(starts_with('hello', 'hello'), 'string equals prefix');
ok(starts_with('hello', ''), 'any string starts with empty');
ok(!starts_with('hello', 'world'), 'string does not start with different');
ok(!starts_with('hello', 'HELLO'), 'starts_with is case sensitive');
ok(!starts_with('hi', 'hello'), 'short string cannot start with longer prefix');

# Edge cases
ok(!starts_with(undef, 'foo'), 'undef does not start with anything');
ok(!starts_with('foo', undef), 'string does not start with undef');
ok(!starts_with(undef, undef), 'undef does not start with undef');

# Test with variables
my $str1 = 'foobar';
my $prefix = 'foo';
my $not_prefix = 'bar';

ok(starts_with($str1, $prefix), 'variable string starts with variable prefix');
ok(!starts_with($str1, $not_prefix), 'variable string does not start with wrong prefix');

# Numeric strings
ok(starts_with('12345', '123'), 'numeric string starts with numeric prefix');
ok(starts_with('12345', 12), 'numeric string starts with number prefix');

# ============================================
# ends_with tests
# ============================================

ok(ends_with('hello world', 'world'), 'string ends with suffix');
ok(ends_with('hello', 'hello'), 'string equals suffix');
ok(ends_with('hello', ''), 'any string ends with empty');
ok(!ends_with('hello', 'world'), 'string does not end with different');
ok(!ends_with('hello', 'HELLO'), 'ends_with is case sensitive');
ok(!ends_with('hi', 'hello'), 'short string cannot end with longer suffix');

# Edge cases
ok(!ends_with(undef, 'foo'), 'undef does not end with anything');
ok(!ends_with('foo', undef), 'string does not end with undef');
ok(!ends_with(undef, undef), 'undef does not end with undef');

# Test with variables
my $str2 = 'foobar';
my $suffix = 'bar';
my $not_suffix = 'foo';

ok(ends_with($str2, $suffix), 'variable string ends with variable suffix');
ok(!ends_with($str2, $not_suffix), 'variable string does not end with wrong suffix');

# Numeric strings
ok(ends_with('12345', '345'), 'numeric string ends with numeric suffix');
ok(ends_with('12345', 45), 'numeric string ends with number suffix');

# ============================================
# Combined tests
# ============================================

# Test in boolean context
my $test_str = 'hello world';
if (starts_with($test_str, 'hello') && ends_with($test_str, 'world')) {
    pass('starts_with and ends_with work in boolean context');
} else {
    fail('starts_with and ends_with work in boolean context');
}

# Test return values
is(starts_with('abc', 'a'), 1, 'starts_with returns 1 for true');
is(starts_with('abc', 'x'), '', 'starts_with returns empty for false');

is(ends_with('abc', 'c'), 1, 'ends_with returns 1 for true');
is(ends_with('abc', 'x'), '', 'ends_with returns empty for false');

is(is_empty(''), 1, 'is_empty returns 1 for true');
is(is_empty('x'), '', 'is_empty returns empty for false');

# Test with special characters
ok(starts_with("foo\nbar", "foo\n"), 'starts_with works with newlines');
ok(ends_with("foo\nbar", "\nbar"), 'ends_with works with newlines');
ok(starts_with("foo\0bar", "foo\0"), 'starts_with works with null bytes');
ok(ends_with("foo\0bar", "\0bar"), 'ends_with works with null bytes');

# Test with unicode (as bytes)
ok(starts_with("cafe\x{cc}\x{81}", "cafe"), 'starts_with works with UTF-8 bytes');
ok(ends_with("cafe\x{cc}\x{81}", "\x{cc}\x{81}"), 'ends_with works with UTF-8 bytes');

done_testing;
