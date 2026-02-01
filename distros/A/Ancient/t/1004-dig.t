#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(dig));

# Simple nested hash
my $hash = {
    a => {
        b => {
            c => 'deep value'
        }
    }
};

# Test successful navigation
is(dig($hash, 'a', 'b', 'c'), 'deep value', 'dig finds deep value');
is_deeply(dig($hash, 'a', 'b'), { c => 'deep value' }, 'dig returns intermediate hash');
is_deeply(dig($hash, 'a'), { b => { c => 'deep value' } }, 'dig with single key');

# Test missing keys return undef
is(dig($hash, 'x'), undef, 'missing key returns undef');
is(dig($hash, 'a', 'x'), undef, 'missing nested key returns undef');
is(dig($hash, 'a', 'b', 'x'), undef, 'missing deep key returns undef');

# Test navigation through missing intermediate returns undef
is(dig($hash, 'a', 'x', 'y'), undef, 'missing intermediate returns undef');

# Test with undef values
my $hash_with_undef = {
    foo => undef,
    bar => {
        baz => undef
    }
};

is(dig($hash_with_undef, 'foo'), undef, 'undef value returns undef');
is(dig($hash_with_undef, 'bar', 'baz'), undef, 'nested undef value returns undef');

# Test with non-hash at intermediate level
my $hash_mixed = {
    arr => [1, 2, 3],
    str => 'not a hash',
    num => 42
};

is(dig($hash_mixed, 'arr', 'anything'), undef, 'array at intermediate returns undef');
is(dig($hash_mixed, 'str', 'anything'), undef, 'string at intermediate returns undef');
is(dig($hash_mixed, 'num', 'anything'), undef, 'number at intermediate returns undef');

# Test with complex nested structure
my $complex = {
    users => {
        '123' => {
            profile => {
                name => 'John',
                settings => {
                    theme => 'dark'
                }
            }
        }
    }
};

is(dig($complex, 'users', '123', 'profile', 'name'), 'John', 'deep path works');
is(dig($complex, 'users', '123', 'profile', 'settings', 'theme'), 'dark', 'very deep path works');
is(dig($complex, 'users', '456'), undef, 'missing user returns undef');
is(dig($complex, 'users', '123', 'profile', 'email'), undef, 'missing field returns undef');

# Test dig on non-hash returns undef
is(dig([], 'anything'), undef, 'dig on array returns undef');
is(dig('string', 'anything'), undef, 'dig on string returns undef');
is(dig(42, 'anything'), undef, 'dig on number returns undef');

# Test with numeric keys
my $numeric = {
    0 => { 1 => { 2 => 'found' } }
};
is(dig($numeric, 0, 1, 2), 'found', 'numeric keys work');

# Test with empty string keys
my $empty_keys = {
    '' => { '' => 'empty' }
};
is(dig($empty_keys, '', ''), 'empty', 'empty string keys work');

done_testing;
