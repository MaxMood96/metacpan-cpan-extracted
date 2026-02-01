#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(is_num is_int is_blessed is_scalar_ref is_regex is_glob));

# ============================================
# is_num tests - check if value is numeric
# ============================================

ok(is_num(42), '42 is numeric');
ok(is_num(-42), '-42 is numeric');
ok(is_num(3.14), '3.14 is numeric');
ok(is_num(0), '0 is numeric');
ok(is_num("42"), '"42" string is numeric');
ok(is_num("-42"), '"-42" string is numeric');
ok(is_num("3.14"), '"3.14" string is numeric');
ok(is_num("0"), '"0" string is numeric');
ok(is_num("1e10"), '"1e10" scientific notation is numeric');
ok(is_num("   42   "), 'string with whitespace is numeric');

ok(!is_num("hello"), '"hello" is not numeric');
ok(!is_num(""), 'empty string is not numeric');
ok(!is_num(undef), 'undef is not numeric');
ok(!is_num([]), 'arrayref is not numeric');
ok(!is_num({}), 'hashref is not numeric');
ok(!is_num(sub {}), 'coderef is not numeric');
ok(!is_num("12abc"), '"12abc" is not numeric');
ok(!is_num("abc12"), '"abc12" is not numeric');

# ============================================
# is_int tests - check if value is integer
# ============================================

ok(is_int(42), '42 is integer');
ok(is_int(-42), '-42 is integer');
ok(is_int(0), '0 is integer');
ok(is_int("42"), '"42" string is integer');
ok(is_int("-42"), '"-42" string is integer');
ok(is_int(5.0), '5.0 (whole number float) is integer');
ok(is_int(-5.0), '-5.0 (whole number float) is integer');

ok(!is_int(3.14), '3.14 is not integer');
ok(!is_int("3.14"), '"3.14" string is not integer');
ok(!is_int("hello"), '"hello" is not integer');
ok(!is_int(""), 'empty string is not integer');
ok(!is_int(undef), 'undef is not integer');
ok(!is_int([]), 'arrayref is not integer');
ok(!is_int({}), 'hashref is not integer');
ok(!is_int(0.5), '0.5 is not integer');

# ============================================
# is_blessed tests - check if value is blessed
# ============================================

{
    package TestObj;
    sub new { bless {}, shift }
}

{
    package TestArray;
    sub new { bless [], shift }
}

my $obj = TestObj->new;
my $blessed_arr = TestArray->new;

ok(is_blessed($obj), 'blessed hashref is blessed');
ok(is_blessed($blessed_arr), 'blessed arrayref is blessed');

ok(!is_blessed({}), 'plain hashref is not blessed');
ok(!is_blessed([]), 'plain arrayref is not blessed');
ok(!is_blessed(sub {}), 'coderef is not blessed');
ok(!is_blessed(\1), 'scalarref is not blessed');
ok(!is_blessed(42), 'number is not blessed');
ok(!is_blessed("hello"), 'string is not blessed');
ok(!is_blessed(undef), 'undef is not blessed');

# ============================================
# is_scalar_ref tests
# ============================================

my $scalar = 42;
my $str = "hello";

ok(is_scalar_ref(\$scalar), 'reference to scalar is scalar_ref');
ok(is_scalar_ref(\$str), 'reference to string is scalar_ref');
ok(is_scalar_ref(\42), 'reference to literal is scalar_ref');

ok(!is_scalar_ref([]), 'arrayref is not scalar_ref');
ok(!is_scalar_ref({}), 'hashref is not scalar_ref');
ok(!is_scalar_ref(sub {}), 'coderef is not scalar_ref');
ok(!is_scalar_ref(42), 'plain number is not scalar_ref');
ok(!is_scalar_ref("hello"), 'plain string is not scalar_ref');
ok(!is_scalar_ref(undef), 'undef is not scalar_ref');

# ============================================
# is_regex tests
# ============================================

my $regex = qr/hello/;
my $regex_i = qr/test/i;

ok(is_regex($regex), 'qr// is regex');
ok(is_regex($regex_i), 'qr//i is regex');
ok(is_regex(qr/^$/), 'inline qr// is regex');

ok(!is_regex("hello"), 'string is not regex');
ok(!is_regex({}), 'hashref is not regex');
ok(!is_regex([]), 'arrayref is not regex');
ok(!is_regex(sub {}), 'coderef is not regex');
ok(!is_regex(42), 'number is not regex');
ok(!is_regex(undef), 'undef is not regex');

# ============================================
# is_glob tests
# ============================================

ok(is_glob(*STDIN), '*STDIN is glob');
ok(is_glob(*STDOUT), '*STDOUT is glob');
ok(is_glob(*STDERR), '*STDERR is glob');
{
    no strict 'refs';
    ok(is_glob(*{"main::is_glob"}), 'function glob is glob');
}

ok(!is_glob(\*STDIN), '\\*STDIN (globref) is not glob');
ok(!is_glob("hello"), 'string is not glob');
ok(!is_glob({}), 'hashref is not glob');
ok(!is_glob([]), 'arrayref is not glob');
ok(!is_glob(sub {}), 'coderef is not glob');
ok(!is_glob(42), 'number is not glob');
ok(!is_glob(undef), 'undef is not glob');

# ============================================
# Test with variables (ensures custom ops work)
# ============================================

my $num = 42;
my $float = 3.14;
my $int = 100;
my $notnum = "hello";

ok(is_num($num), 'variable number is numeric');
ok(is_num($float), 'variable float is numeric');
ok(!is_num($notnum), 'variable non-number is not numeric');

ok(is_int($int), 'variable integer is integer');
ok(!is_int($float), 'variable float is not integer');

# ============================================
# Test return values are proper booleans
# ============================================

is(is_num(42), 1, 'is_num returns 1 for true');
is(is_num("hello"), '', 'is_num returns empty string for false');

is(is_int(42), 1, 'is_int returns 1 for true');
is(is_int(3.14), '', 'is_int returns empty string for false');

is(is_blessed($obj), 1, 'is_blessed returns 1 for true');
is(is_blessed({}), '', 'is_blessed returns empty string for false');

is(is_scalar_ref(\$scalar), 1, 'is_scalar_ref returns 1 for true');
is(is_scalar_ref([]), '', 'is_scalar_ref returns empty string for false');

is(is_regex($regex), 1, 'is_regex returns 1 for true');
is(is_regex("hello"), '', 'is_regex returns empty string for false');

done_testing;
