#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 121;

use_ok('Stefo');

# --- Type Checks ---
ok(Stefo::is_array([1,2,3]), "is_array on arrayref");
ok(!Stefo::is_array({a=>1}), "is_array on hashref is false");
ok(!Stefo::is_array("hello"), "is_array on string is false");
ok(!Stefo::is_array(undef), "is_array on undef is false");

ok(Stefo::is_hash({a=>1}), "is_hash on hashref");
ok(!Stefo::is_hash([1,2]), "is_hash on arrayref is false");
ok(!Stefo::is_hash("hello"), "is_hash on string is false");

ok(Stefo::is_code(sub { 1 }), "is_code on coderef");
ok(!Stefo::is_code([]), "is_code on arrayref is false");
ok(!Stefo::is_code("hello"), "is_code on string is false");

ok(Stefo::is_ref([]), "is_ref on arrayref");
ok(Stefo::is_ref({}), "is_ref on hashref");
ok(Stefo::is_ref(sub{}), "is_ref on coderef");
ok(!Stefo::is_ref("hello"), "is_ref on string is false");
ok(!Stefo::is_ref(42), "is_ref on number is false");

ok(Stefo::is_scalar(\(my $x = 1)), "is_scalar on scalar ref");
ok(!Stefo::is_scalar([]), "is_scalar on arrayref is false");

ok(Stefo::is_regexp(qr/test/), "is_regexp on qr//");
ok(!Stefo::is_regexp("test"), "is_regexp on string is false");

ok(Stefo::is_glob(\*STDIN), "is_glob on globref");
ok(!Stefo::is_glob("test"), "is_glob on string is false");

{
    package Foo;
    sub new { bless {}, shift }
}
ok(Stefo::is_blessed(Foo->new), "is_blessed on object");
ok(!Stefo::is_blessed({}), "is_blessed on plain hashref is false");
ok(!Stefo::is_blessed("hello"), "is_blessed on string is false");

# --- Value Checks ---
ok(Stefo::is_defined(42), "is_defined on number");
ok(Stefo::is_defined(""), "is_defined on empty string");
ok(!Stefo::is_defined(undef), "is_defined on undef is false");

ok(Stefo::is_undef(undef), "is_undef on undef");
ok(!Stefo::is_undef(0), "is_undef on 0 is false");
ok(!Stefo::is_undef(""), "is_undef on empty string is false");

ok(Stefo::is_true(1), "is_true on 1");
ok(Stefo::is_true("hello"), "is_true on non-empty string");
ok(Stefo::is_true([]), "is_true on arrayref");
ok(!Stefo::is_true(0), "is_true on 0 is false");
ok(!Stefo::is_true(""), "is_true on empty string is false");
ok(!Stefo::is_true(undef), "is_true on undef is false");

ok(Stefo::is_false(0), "is_false on 0");
ok(Stefo::is_false(""), "is_false on empty string");
ok(Stefo::is_false(undef), "is_false on undef");
ok(!Stefo::is_false(1), "is_false on 1 is false");

ok(Stefo::looks_like_number(42), "looks_like_number on int");
ok(Stefo::looks_like_number(3.14), "looks_like_number on float");
ok(Stefo::looks_like_number("42"), "looks_like_number on numeric string");
ok(!Stefo::looks_like_number("hello"), "looks_like_number on word is false");

# --- Numeric Checks ---
ok(Stefo::is_integer(42), "is_integer on 42");
ok(Stefo::is_integer(-5), "is_integer on -5");
ok(Stefo::is_integer(0), "is_integer on 0");
ok(!Stefo::is_integer(3.5), "is_integer on 3.5 is false");

ok(Stefo::is_positive(42), "is_positive on 42");
ok(Stefo::is_positive(0.001), "is_positive on 0.001");
ok(!Stefo::is_positive(0), "is_positive on 0 is false");
ok(!Stefo::is_positive(-5), "is_positive on -5 is false");

ok(Stefo::is_negative(-5), "is_negative on -5");
ok(!Stefo::is_negative(0), "is_negative on 0 is false");
ok(!Stefo::is_negative(42), "is_negative on 42 is false");

ok(Stefo::is_zero(0), "is_zero on 0");
ok(Stefo::is_zero("0"), "is_zero on '0'");
ok(!Stefo::is_zero(1), "is_zero on 1 is false");

ok(Stefo::is_even(0), "is_even on 0");
ok(Stefo::is_even(2), "is_even on 2");
ok(Stefo::is_even(-4), "is_even on -4");
ok(!Stefo::is_even(3), "is_even on 3 is false");

ok(Stefo::is_odd(1), "is_odd on 1");
ok(Stefo::is_odd(-3), "is_odd on -3");
ok(!Stefo::is_odd(2), "is_odd on 2 is false");

# --- String Checks ---
ok(Stefo::is_empty_string(""), "is_empty_string on empty");
ok(!Stefo::is_empty_string("a"), "is_empty_string on 'a' is false");
ok(!Stefo::is_empty_string(undef), "is_empty_string on undef is false");

ok(Stefo::is_nonempty_string("hello"), "is_nonempty_string on 'hello'");
ok(!Stefo::is_nonempty_string(""), "is_nonempty_string on empty is false");

SKIP: {
    skip "Character class helpers require Perl 5.14+", 22 unless Stefo->can('is_alpha');

    ok(Stefo::is_alpha("abc"), "is_alpha on 'abc'");
    ok(Stefo::is_alpha("ABC"), "is_alpha on 'ABC'");
    ok(!Stefo::is_alpha("abc123"), "is_alpha on 'abc123' is false");
    ok(!Stefo::is_alpha(""), "is_alpha on empty is false");

    ok(Stefo::is_alnum("abc123"), "is_alnum on 'abc123'");
    ok(!Stefo::is_alnum("abc-123"), "is_alnum on 'abc-123' is false");

    ok(Stefo::is_digit("12345"), "is_digit on '12345'");
    ok(!Stefo::is_digit("123.45"), "is_digit on '123.45' is false");

    ok(Stefo::is_space("   "), "is_space on spaces");
    ok(Stefo::is_space("\t\n"), "is_space on tab+newline");
    ok(!Stefo::is_space("a b"), "is_space on 'a b' is false");

    ok(Stefo::is_word_char("abc_123"), "is_word_char on 'abc_123'");
    ok(!Stefo::is_word_char("abc-123"), "is_word_char on 'abc-123' is false");

    ok(Stefo::is_upper("ABC"), "is_upper on 'ABC'");
    ok(!Stefo::is_upper("Abc"), "is_upper on 'Abc' is false");

    ok(Stefo::is_lower("abc"), "is_lower on 'abc'");
    ok(!Stefo::is_lower("Abc"), "is_lower on 'Abc' is false");

    ok(Stefo::is_ascii("hello"), "is_ascii on 'hello'");
    ok(Stefo::is_ascii(""), "is_ascii on empty string");
    ok(!Stefo::is_ascii("héllo"), "is_ascii on 'héllo' is false");

    ok(Stefo::is_printable("hello 123!"), "is_printable on 'hello 123!'");
    ok(!Stefo::is_printable("hello\x00world"), "is_printable with null is false");
}

# --- String Operations ---
ok(Stefo::string_contains("hello world", "wor"), "string_contains finds substring");
ok(!Stefo::string_contains("hello world", "xyz"), "string_contains misses");
ok(Stefo::string_contains("hello", ""), "string_contains empty needle");

ok(Stefo::string_starts_with("hello world", "hello"), "string_starts_with");
ok(!Stefo::string_starts_with("hello world", "world"), "string_starts_with fails");

ok(Stefo::string_ends_with("hello world", "world"), "string_ends_with");
ok(!Stefo::string_ends_with("hello world", "hello"), "string_ends_with fails");

# --- Collection Checks ---
is(Stefo::array_length([1,2,3]), 3, "array_length returns 3");
is(Stefo::array_length([]), 0, "array_length on empty returns 0");
is(Stefo::array_length("not array"), -1, "array_length on non-array returns -1");

is(Stefo::hash_size({a=>1, b=>2}), 2, "hash_size returns 2");
is(Stefo::hash_size({}), 0, "hash_size on empty returns 0");
is(Stefo::hash_size("not hash"), -1, "hash_size on non-hash returns -1");

ok(Stefo::is_array_empty([]), "is_array_empty on empty array");
ok(!Stefo::is_array_empty([1]), "is_array_empty on non-empty is false");

ok(Stefo::is_hash_empty({}), "is_hash_empty on empty hash");
ok(!Stefo::is_hash_empty({a=>1}), "is_hash_empty on non-empty is false");

# --- Type Inspection ---
is(Stefo::typeof(undef), "UNDEF", "typeof undef");
is(Stefo::typeof([]), "ARRAY", "typeof arrayref");
is(Stefo::typeof({}), "HASH", "typeof hashref");
is(Stefo::typeof(sub{}), "CODE", "typeof coderef");
is(Stefo::typeof(Foo->new), "OBJECT", "typeof object");
is(Stefo::typeof(42), "INTEGER", "typeof integer");
is(Stefo::typeof("hello"), "STRING", "typeof string");

is(Stefo::reftype([]), "ARRAY", "reftype arrayref");
is(Stefo::reftype({}), "HASH", "reftype hashref");
is(Stefo::reftype(sub{}), "CODE", "reftype coderef");
ok(!defined Stefo::reftype("hello"), "reftype non-ref is undef");
