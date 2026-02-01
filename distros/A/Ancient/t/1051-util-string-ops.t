#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use util;

# Test trim
is(util::trim('  hello  '), 'hello', 'trim: removes both sides');
is(util::trim('  hello'), 'hello', 'trim: removes leading');
is(util::trim('hello  '), 'hello', 'trim: removes trailing');
is(util::trim('hello'), 'hello', 'trim: no change needed');
is(util::trim("\t\nhello\t\n"), 'hello', 'trim: removes tabs and newlines');

# Test ltrim
is(util::ltrim('  hello  '), 'hello  ', 'ltrim: removes leading only');
is(util::ltrim('  hello'), 'hello', 'ltrim: removes leading spaces');
is(util::ltrim('hello  '), 'hello  ', 'ltrim: no leading to remove');

# Test rtrim
is(util::rtrim('  hello  '), '  hello', 'rtrim: removes trailing only');
is(util::rtrim('hello  '), 'hello', 'rtrim: removes trailing spaces');
is(util::rtrim('  hello'), '  hello', 'rtrim: no trailing to remove');

# Test starts_with
ok(util::starts_with('hello world', 'hello'), 'starts_with: hello world starts with hello');
ok(util::starts_with('hello', 'hello'), 'starts_with: exact match');
ok(!util::starts_with('hello world', 'world'), 'starts_with: does not start with world');
ok(util::starts_with('hello', ''), 'starts_with: empty prefix matches');

# Test ends_with
ok(util::ends_with('hello world', 'world'), 'ends_with: hello world ends with world');
ok(util::ends_with('hello', 'hello'), 'ends_with: exact match');
ok(!util::ends_with('hello world', 'hello'), 'ends_with: does not end with hello');
ok(util::ends_with('hello', ''), 'ends_with: empty suffix matches');

# Test replace_all
is(util::replace_all('hello world', 'o', '0'), 'hell0 w0rld', 'replace_all: replaces all occurrences');
is(util::replace_all('aaa', 'a', 'b'), 'bbb', 'replace_all: replaces all a with b');
is(util::replace_all('hello', 'x', 'y'), 'hello', 'replace_all: no match, no change');

done_testing();
