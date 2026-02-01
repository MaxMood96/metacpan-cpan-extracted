#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use util qw(replace_all);

# Basic replacements
is(replace_all("hello world", "o", "0"), "hell0 w0rld", "replace o with 0");
is(replace_all("abcabc", "abc", "X"), "XX", "replace abc with X");
is(replace_all("hello", "l", "LL"), "heLLLLo", "replace with longer string");
is(replace_all("hello", "ll", "L"), "heLo", "replace with shorter string");
is(replace_all("hello", "x", "y"), "hello", "no matches - unchanged");

# Edge cases
is(replace_all("hello", "", "x"), "hello", "empty search - unchanged");
is(replace_all("hello", "hello world", "x"), "hello", "search longer than string");
is(replace_all("hello", "hello", "goodbye"), "goodbye", "replace entire string");
is(replace_all("hello", "hello", ""), "", "replace with empty string");

# Undef handling
is(replace_all(undef, "a", "b"), undef, "undef string returns undef");

# Multiple occurrences
is(replace_all("aaa", "a", "bb"), "bbbbbb", "multiple single char");
is(replace_all("the the the", "the", "a"), "a a a", "multiple words");

# Non-overlapping
is(replace_all("aaaa", "aa", "X"), "XX", "non-overlapping aa in aaaa");

# Real-world examples
is(replace_all("Hello, World!", ", ", " - "), "Hello - World!", "comma to dash");
is(replace_all("/path/to/file", "/", "\\"), "\\path\\to\\file", "unix to windows path");

# Longer strings
my $str = "the quick brown fox jumps over the lazy dog";
is(replace_all($str, "the", "THE"), "THE quick brown fox jumps over THE lazy dog", "case replacement");
is(replace_all($str, " ", "_"), "the_quick_brown_fox_jumps_over_the_lazy_dog", "spaces to underscores");

done_testing;
