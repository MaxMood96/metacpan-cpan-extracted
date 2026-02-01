#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use util;

# Test bool (returns truthy value, not necessarily 0/1)
ok(util::bool(1), 'bool: 1 is true');
ok(!util::bool(0), 'bool: 0 is false');
ok(!util::bool(''), 'bool: empty string is false');
ok(util::bool('hello'), 'bool: non-empty string is true');
ok(!util::bool(undef), 'bool: undef is false');
ok(util::bool([]), 'bool: empty array ref is true');
ok(util::bool({}), 'bool: empty hash ref is true');

# Test negate
my $is_even = sub { $_[0] % 2 == 0 };
my $is_odd = util::negate($is_even);
ok($is_odd->(3), 'negate: 3 is odd');
ok(!$is_odd->(4), 'negate: 4 is not odd');

# Test force - check if it exists and works
# Note: force may not evaluate coderefs, just returns them
my $result = util::force(42);
is($result, 42, 'force: returns number directly');
is(util::force('hello'), 'hello', 'force: returns string directly');

done_testing();
