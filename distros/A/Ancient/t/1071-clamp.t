#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use util 'clamp';

# Basic clamping
is(clamp(5, 0, 10), 5, 'value in range unchanged');
is(clamp(-5, 0, 10), 0, 'value below min clamped to min');
is(clamp(15, 0, 10), 10, 'value above max clamped to max');

# Edge cases
is(clamp(0, 0, 10), 0, 'value at min unchanged');
is(clamp(10, 0, 10), 10, 'value at max unchanged');

# Negative ranges
is(clamp(-5, -10, -1), -5, 'negative range, value in range');
is(clamp(-15, -10, -1), -10, 'negative range, below min');
is(clamp(0, -10, -1), -1, 'negative range, above max');

# Floats
is(clamp(3.5, 0, 10), 3.5, 'float value in range');
is(clamp(0.5, 1, 10), 1, 'float below min');
is(clamp(10.5, 0, 10), 10, 'float above max');

# Single value range
is(clamp(5, 5, 5), 5, 'single value range');

done_testing();
