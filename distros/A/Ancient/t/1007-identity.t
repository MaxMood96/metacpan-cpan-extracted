#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use util 'identity';

# Basic identity
is(identity(42), 42, 'identity returns number unchanged');
is(identity('hello'), 'hello', 'identity returns string unchanged');
is(identity(undef), undef, 'identity returns undef unchanged');

# References
my $array = [1, 2, 3];
is(identity($array), $array, 'identity returns arrayref unchanged (same ref)');

my $hash = { a => 1 };
is(identity($hash), $hash, 'identity returns hashref unchanged (same ref)');

my $code = sub { 1 };
is(identity($code), $code, 'identity returns coderef unchanged (same ref)');

# Useful as default transform
my $transform = \&identity;
is($transform->(99), 99, 'identity works as default transform');

# In pipeline-like usage
my @nums = map { identity($_) } (1, 2, 3);
is_deeply(\@nums, [1, 2, 3], 'identity in map');

done_testing();
