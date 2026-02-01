#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use util;

# Test is_num
ok(util::is_num(42), 'is_num: integer is num');
ok(util::is_num(3.14), 'is_num: float is num');
ok(util::is_num(-5), 'is_num: negative is num');
ok(util::is_num('42'), 'is_num: numeric string is num');
ok(!util::is_num('hello'), 'is_num: string is not num');
ok(!util::is_num('42abc'), 'is_num: mixed string is not num');

# Test is_int
ok(util::is_int(42), 'is_int: integer is int');
ok(util::is_int(-5), 'is_int: negative integer is int');
ok(util::is_int(0), 'is_int: zero is int');
ok(!util::is_int(3.14), 'is_int: float is not int');
ok(!util::is_int('hello'), 'is_int: string is not int');

# Test is_positive
ok(util::is_positive(5), 'is_positive: 5 is positive');
ok(util::is_positive(0.1), 'is_positive: 0.1 is positive');
ok(!util::is_positive(0), 'is_positive: 0 is not positive');
ok(!util::is_positive(-5), 'is_positive: -5 is not positive');

# Test is_negative
ok(util::is_negative(-5), 'is_negative: -5 is negative');
ok(util::is_negative(-0.1), 'is_negative: -0.1 is negative');
ok(!util::is_negative(0), 'is_negative: 0 is not negative');
ok(!util::is_negative(5), 'is_negative: 5 is not negative');

# Test is_zero
ok(util::is_zero(0), 'is_zero: 0 is zero');
ok(util::is_zero(0.0), 'is_zero: 0.0 is zero');
ok(!util::is_zero(1), 'is_zero: 1 is not zero');
ok(!util::is_zero(-1), 'is_zero: -1 is not zero');

# Test is_even
ok(util::is_even(0), 'is_even: 0 is even');
ok(util::is_even(2), 'is_even: 2 is even');
ok(util::is_even(-4), 'is_even: -4 is even');
ok(!util::is_even(1), 'is_even: 1 is not even');
ok(!util::is_even(3), 'is_even: 3 is not even');

# Test is_odd
ok(util::is_odd(1), 'is_odd: 1 is odd');
ok(util::is_odd(3), 'is_odd: 3 is odd');
ok(util::is_odd(-5), 'is_odd: -5 is odd');
ok(!util::is_odd(0), 'is_odd: 0 is not odd');
ok(!util::is_odd(2), 'is_odd: 2 is not odd');

# Test is_between
ok(util::is_between(5, 1, 10), 'is_between: 5 is between 1 and 10');
ok(util::is_between(1, 1, 10), 'is_between: 1 is between 1 and 10 (inclusive)');
ok(util::is_between(10, 1, 10), 'is_between: 10 is between 1 and 10 (inclusive)');
ok(!util::is_between(0, 1, 10), 'is_between: 0 is not between 1 and 10');
ok(!util::is_between(11, 1, 10), 'is_between: 11 is not between 1 and 10');

done_testing();
