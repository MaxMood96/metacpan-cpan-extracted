#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use util qw(count);

# Basic counting
is(count("hello world", "o"), 2, "count 'o' in 'hello world'");
is(count("abcabc", "abc"), 2, "count 'abc' in 'abcabc'");
is(count("aaaa", "aa"), 2, "non-overlapping: 'aa' in 'aaaa' = 2");
is(count("hello", "x"), 0, "no matches");
is(count("hello", "hello"), 1, "exact match");
is(count("hello", "hello world"), 0, "needle longer than haystack");

# Edge cases
is(count("", "a"), 0, "empty string");
is(count("hello", ""), 0, "empty needle");
is(count("a", "a"), 1, "single char match");

# Undef handling
is(count(undef, "a"), 0, "undef string");
is(count("hello", undef), 0, "undef needle");

# Longer strings
my $str = "the quick brown fox jumps over the lazy dog";
is(count($str, "the"), 2, "count 'the' in sentence");
is(count($str, " "), 8, "count spaces");
is(count($str, "fox"), 1, "count 'fox'");

# Repeated pattern
is(count("abababab", "ab"), 4, "repeated pattern");
is(count("xxxxxxxx", "xx"), 4, "non-overlapping repeated");

done_testing;
