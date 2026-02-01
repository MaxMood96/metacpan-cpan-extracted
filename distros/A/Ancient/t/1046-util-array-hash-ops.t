#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use util;

# Test array_first
is(util::array_first([1, 2, 3, 4, 5]), 1, 'array_first: returns first element');
is(util::array_first(['a', 'b', 'c']), 'a', 'array_first: returns first string');
is(util::array_first([]), undef, 'array_first: empty array returns undef');

# Test array_last
is(util::array_last([1, 2, 3, 4, 5]), 5, 'array_last: returns last element');
is(util::array_last(['a', 'b', 'c']), 'c', 'array_last: returns last string');
is(util::array_last([]), undef, 'array_last: empty array returns undef');

# Test array_len
is(util::array_len([1, 2, 3, 4, 5]), 5, 'array_len: 5 elements');
is(util::array_len([]), 0, 'array_len: empty array');
is(util::array_len(['a']), 1, 'array_len: single element');

# Test hash_size
is(util::hash_size({a => 1, b => 2, c => 3}), 3, 'hash_size: 3 keys');
is(util::hash_size({}), 0, 'hash_size: empty hash');
is(util::hash_size({x => 1}), 1, 'hash_size: single key');

done_testing();
