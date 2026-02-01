#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(pipeline compose));

# Test pipeline
my $result = pipeline(5,
    sub { $_[0] * 2 },      # 10
    sub { $_[0] + 3 },      # 13
    sub { $_[0] ** 2 }      # 169
);
is($result, 169, 'pipeline chains functions correctly');

# Test pipe with single function
is(pipeline(10, sub { $_[0] / 2 }), 5, 'pipeline with single function');

# Test compose
my $transform = compose(
    sub { $_[0] ** 2 },     # Last: square
    sub { $_[0] + 3 },      # Second: add 3
    sub { $_[0] * 2 }       # First: double
);

is($transform->(5), 169, 'compose chains functions right-to-left');

# compose(c, b, a) should equal c(b(a(x)))
# a(5) = 10, b(10) = 13, c(13) = 169

# Test compose with single function
my $double = compose(sub { $_[0] * 2 });
is($double->(7), 14, 'compose with single function');

# Test compose reusability
is($transform->(3), 81, 'composed function is reusable');
# a(3) = 6, b(6) = 9, c(9) = 81

done_testing;
