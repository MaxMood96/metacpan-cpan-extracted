#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(trim maybe));

# ============================================
# trim tests - remove leading/trailing whitespace
# ============================================

is(trim("hello"), "hello", 'no whitespace unchanged');
is(trim("  hello"), "hello", 'leading spaces trimmed');
is(trim("hello  "), "hello", 'trailing spaces trimmed');
is(trim("  hello  "), "hello", 'both sides trimmed');
is(trim("\thello\t"), "hello", 'tabs trimmed');
is(trim("\nhello\n"), "hello", 'newlines trimmed');
is(trim("  \t\n  hello  \t\n  "), "hello", 'mixed whitespace trimmed');

# Whitespace in the middle is preserved
is(trim("  hello world  "), "hello world", 'internal whitespace preserved');
is(trim("  hello  world  "), "hello  world", 'multiple internal spaces preserved');

# Only whitespace
is(trim("   "), "", 'all whitespace becomes empty');
is(trim("\t\n"), "", 'tabs and newlines become empty');

# Empty string
is(trim(""), "", 'empty string unchanged');

# Undefined
is(trim(undef), undef, 'undef returns undef');

# Numbers (stringified)
is(trim("  42  "), "42", 'number string trimmed');
is(trim("  3.14  "), "3.14", 'float string trimmed');

# Unicode-safe (basic ASCII whitespace)
is(trim("  test  "), "test", 'basic trim works');

# ============================================
# Test with variables (ensures custom ops work)
# ============================================

my $with_spaces = "  trimmed  ";
my $no_spaces = "clean";
my $all_spaces = "     ";
my $empty = "";

is(trim($with_spaces), "trimmed", 'variable with spaces');
is(trim($no_spaces), "clean", 'variable without spaces');
is(trim($all_spaces), "", 'variable with only spaces');
is(trim($empty), "", 'variable empty string');

# ============================================
# maybe tests - conditional value
# ============================================

# Basic defined cases
is(maybe(1, "result"), "result", 'defined number returns result');
is(maybe("hello", "result"), "result", 'defined string returns result');
is(maybe(0, "result"), "result", 'zero is defined, returns result');
is(maybe("", "result"), "result", 'empty string is defined, returns result');
is(maybe([], "result"), "result", 'arrayref is defined, returns result');
is(maybe({}, "result"), "result", 'hashref is defined, returns result');

# Undefined cases
is(maybe(undef, "result"), undef, 'undef returns undef');

# Various then values
is(maybe(1, 42), 42, 'then can be a number');

my $aref = [1,2,3];
is(maybe(1, $aref), $aref, 'then can be an arrayref');

my $href = { foo => 'bar' };
is(maybe(1, $href), $href, 'then can be a hashref');

# ============================================
# maybe with variables (ensures custom ops work)
# ============================================

my $defined_val = "test";
my $undef_val;
my $zero_val = 0;
my $empty_str = "";
my $then_val = "success";

is(maybe($defined_val, $then_val), "success", 'variable defined value');
is(maybe($undef_val, $then_val), undef, 'variable undefined value');
is(maybe($zero_val, $then_val), "success", 'variable zero value');
is(maybe($empty_str, $then_val), "success", 'variable empty string value');

# ============================================
# Common use cases
# ============================================

# maybe as safe accessor pattern
my $config = { timeout => 30 };
is(maybe($config->{timeout}, $config->{timeout} * 2), 60, 'maybe for safe math');
is(maybe($config->{missing}, 100), undef, 'maybe with missing key');

# trim + maybe combo use case
my $input = "  user input  ";
my $cleaned = trim($input);
is($cleaned, "user input", 'trim user input');
is(maybe($cleaned, uc($cleaned)), "USER INPUT", 'maybe transform cleaned input');

done_testing;
