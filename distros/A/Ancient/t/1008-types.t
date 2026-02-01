#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(is_ref is_array is_hash is_code is_defined is_string));

# ============================================
# is_ref tests
# ============================================

ok(is_ref([]), 'arrayref is a ref');
ok(is_ref({}), 'hashref is a ref');
ok(is_ref(sub {}), 'coderef is a ref');
ok(is_ref(\1), 'scalar ref is a ref');
ok(!is_ref(1), 'number is not a ref');
ok(!is_ref('hello'), 'string is not a ref');
ok(!is_ref(undef), 'undef is not a ref');

# ============================================
# is_array tests
# ============================================

ok(is_array([]), 'empty arrayref is array');
ok(is_array([1, 2, 3]), 'arrayref with elements is array');
ok(!is_array({}), 'hashref is not array');
ok(!is_array(sub {}), 'coderef is not array');
ok(!is_array(\1), 'scalar ref is not array');
ok(!is_array(1), 'number is not array');
ok(!is_array('hello'), 'string is not array');
ok(!is_array(undef), 'undef is not array');

# ============================================
# is_hash tests
# ============================================

ok(is_hash({}), 'empty hashref is hash');
ok(is_hash({ a => 1 }), 'hashref with elements is hash');
ok(!is_hash([]), 'arrayref is not hash');
ok(!is_hash(sub {}), 'coderef is not hash');
ok(!is_hash(\1), 'scalar ref is not hash');
ok(!is_hash(1), 'number is not hash');
ok(!is_hash('hello'), 'string is not hash');
ok(!is_hash(undef), 'undef is not hash');

# ============================================
# is_code tests
# ============================================

ok(is_code(sub {}), 'anonymous sub is code');
ok(is_code(\&is_code), 'coderef to named sub is code');
ok(!is_code({}), 'hashref is not code');
ok(!is_code([]), 'arrayref is not code');
ok(!is_code(\1), 'scalar ref is not code');
ok(!is_code(1), 'number is not code');
ok(!is_code('hello'), 'string is not code');
ok(!is_code(undef), 'undef is not code');

# ============================================
# is_defined tests
# ============================================

ok(is_defined(1), 'number is defined');
ok(is_defined(0), 'zero is defined');
ok(is_defined(''), 'empty string is defined');
ok(is_defined('hello'), 'string is defined');
ok(is_defined([]), 'arrayref is defined');
ok(is_defined({}), 'hashref is defined');
ok(is_defined(sub {}), 'coderef is defined');
ok(!is_defined(undef), 'undef is not defined');

# ============================================
# Test with variables (ensures custom ops work)
# ============================================

my $arr = [1, 2, 3];
my $hash = { a => 1 };
my $code = sub { 1 };
my $num = 42;
my $str = 'hello';
my $undef = undef;

ok(is_array($arr), 'variable arrayref is array');
ok(is_hash($hash), 'variable hashref is hash');
ok(is_code($code), 'variable coderef is code');
ok(is_ref($arr), 'variable arrayref is ref');
ok(!is_ref($num), 'variable number is not ref');
ok(is_defined($str), 'variable string is defined');
ok(!is_defined($undef), 'variable undef is not defined');

# ============================================
# Test in boolean context
# ============================================

if (is_array($arr)) {
    pass('is_array works in boolean context');
} else {
    fail('is_array works in boolean context');
}

if (!is_array($hash)) {
    pass('!is_array works in boolean context');
} else {
    fail('!is_array works in boolean context');
}

# ============================================
# Test return values are proper booleans
# ============================================

is(is_array([]), 1, 'is_array returns 1 for true');
is(is_array({}), '', 'is_array returns empty string for false');

is(is_hash({}), 1, 'is_hash returns 1 for true');
is(is_hash([]), '', 'is_hash returns empty string for false');

is(is_code(sub {}), 1, 'is_code returns 1 for true');
is(is_code([]), '', 'is_code returns empty string for false');

is(is_ref([]), 1, 'is_ref returns 1 for true');
is(is_ref(1), '', 'is_ref returns empty string for false');

is(is_defined(1), 1, 'is_defined returns 1 for true');
is(is_defined(undef), '', 'is_defined returns empty string for false');

# ============================================
# Test with blessed objects
# ============================================

{
    package MyObj;
    sub new { bless {}, shift }
}

{
    package MyArray;
    sub new { bless [], shift }
}

my $obj = MyObj->new;
my $blessed_arr = MyArray->new;

ok(is_ref($obj), 'blessed hashref is ref');
ok(is_hash($obj), 'blessed hashref is still a hash');
ok(!is_array($obj), 'blessed hashref is not array');

ok(is_ref($blessed_arr), 'blessed arrayref is ref');
ok(is_array($blessed_arr), 'blessed arrayref is still an array');
ok(!is_hash($blessed_arr), 'blessed arrayref is not hash');

# ============================================
# is_string tests (plain scalar: defined && not a ref)
# ============================================

# These should be true - plain scalars
ok(is_string('hello'), 'string is a string');
ok(is_string(''), 'empty string is a string');
ok(is_string(42), 'number is a string');
ok(is_string(3.14), 'float is a string');
ok(is_string(0), 'zero is a string');
ok(is_string('0'), 'string zero is a string');

# These should be false - not plain scalars
ok(!is_string(undef), 'undef is not a string');
ok(!is_string([]), 'arrayref is not a string');
ok(!is_string({}), 'hashref is not a string');
ok(!is_string(sub {}), 'coderef is not a string');
ok(!is_string(\1), 'scalar ref is not a string');
ok(!is_string(\$obj), 'ref to object is not a string');
ok(!is_string($obj), 'blessed ref is not a string');

# Edge cases
# Note: globs are technically "defined and not a ref" so is_string returns true
# Use is_glob to specifically detect globs if needed
ok(is_string(*STDIN), 'glob is technically a string (defined, not ref)');
ok(!is_string(qr/test/), 'regex is not a string');

# ============================================
# Ternary context tests - ensure return values work in conditionals
# ============================================

# is_ref ternary
is((is_ref([]) ? 'yes' : 'no'), 'yes', 'is_ref([]) works in ternary');
is((is_ref({}) ? 'yes' : 'no'), 'yes', 'is_ref({}) works in ternary');
is((is_ref('hello') ? 'yes' : 'no'), 'no', 'is_ref(string) works in ternary');

# is_array ternary
is((is_array([]) ? 'yes' : 'no'), 'yes', 'is_array([]) works in ternary');
is((is_array({}) ? 'yes' : 'no'), 'no', 'is_array({}) works in ternary');

# is_hash ternary
is((is_hash({}) ? 'yes' : 'no'), 'yes', 'is_hash({}) works in ternary');
is((is_hash([]) ? 'yes' : 'no'), 'no', 'is_hash([]) works in ternary');

# is_code ternary
is((is_code(sub {}) ? 'yes' : 'no'), 'yes', 'is_code(sub) works in ternary');
is((is_code({}) ? 'yes' : 'no'), 'no', 'is_code({}) works in ternary');

# is_defined ternary
is((is_defined(1) ? 'yes' : 'no'), 'yes', 'is_defined(1) works in ternary');
is((is_defined(undef) ? 'yes' : 'no'), 'no', 'is_defined(undef) works in ternary');

# is_string ternary
is((is_string('hello') ? 'yes' : 'no'), 'yes', 'is_string(hello) works in ternary');
is((is_string([]) ? 'yes' : 'no'), 'no', 'is_string([]) works in ternary');
is((is_string(undef) ? 'yes' : 'no'), 'no', 'is_string(undef) works in ternary');

# Variable context (not just literals)
my $str2 = 'test';
my $arr2 = [1, 2, 3];
my $hash2 = { a => 1 };
is((is_string($str2) ? 'yes' : 'no'), 'yes', 'is_string($var) works in ternary');
is((is_ref($arr2) ? 'yes' : 'no'), 'yes', 'is_ref($arr_var) works in ternary');
is((is_hash($hash2) ? 'yes' : 'no'), 'yes', 'is_hash($hash_var) works in ternary');
is((is_string($arr2) ? 'yes' : 'no'), 'no', 'is_string($arr_var) works in ternary');

done_testing;
