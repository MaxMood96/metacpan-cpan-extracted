#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use util;

# Test first - finds first matching element
is(util::first(sub { $_ > 3 }, 1, 2, 3, 4, 5), 4, 'first: first > 3 is 4');
is(util::first(sub { $_ > 10 }, 1, 2, 3), undef, 'first: none > 10');
is(util::first(sub { $_ eq 'b' }, 'a', 'b', 'c'), 'b', 'first: first eq b');

# Test firstr (from right/arrayref) - same as first but with arrayref
is(util::firstr(sub { $_ > 3 }, [1, 2, 3, 4, 5]), 4, 'firstr: first > 3 is 4');
is(util::firstr(sub { $_ < 3 }, [1, 2, 3, 4, 5]), 1, 'firstr: first < 3 is 1');

# Test final - finds LAST matching element
my @arr = (1, 2, 3, 4, 5);
is(util::final(sub { $_ > 0 }, \@arr), 5, 'final: last > 0 is 5');
is(util::final(sub { $_ < 0 }, \@arr), undef, 'final: none < 0');
is(util::final(sub { $_ > 3 }, \@arr), 5, 'final: last > 3 is 5');
is(util::final(sub { $_ < 3 }, \@arr), 2, 'final: last < 3 is 2');

# Test first_inline uses $_ (not $_[0])
# first_inline requires MULTICALL API (Perl 5.11+)
SKIP: {
    skip "first_inline requires Perl 5.11+", 1 if $] < 5.011;
    skip "first_inline not available (MULTICALL disabled)", 1 unless util->can('first_inline');
    is(util::first_inline(sub { $_ > 3 }, 1, 2, 3, 4, 5), 4, 'first_inline: first > 3 is 4');
}

done_testing();
