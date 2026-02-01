#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use util;

# Test min2
is(util::min2(3, 5), 3, 'min2: 3 is minimum');
is(util::min2(5, 3), 3, 'min2: 3 is minimum (reversed)');
is(util::min2(-5, 5), -5, 'min2: -5 is minimum');
is(util::min2(5, 5), 5, 'min2: equal values');

# Test max2
is(util::max2(3, 5), 5, 'max2: 5 is maximum');
is(util::max2(5, 3), 5, 'max2: 5 is maximum (reversed)');
is(util::max2(-5, 5), 5, 'max2: 5 is maximum');
is(util::max2(5, 5), 5, 'max2: equal values');

# Test sign
is(util::sign(5), 1, 'sign: positive returns 1');
is(util::sign(-5), -1, 'sign: negative returns -1');
is(util::sign(0), 0, 'sign: zero returns 0');

done_testing();
