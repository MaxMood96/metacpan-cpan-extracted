#!/usr/bin/env perl
# [[[ HEADER ]]]
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils

# [[[ OPERATIONS ]]]

my scalartype $mystery_scalar = 21.12;
my arrayref::scalartype $sc_array = [
    my integer $TYPED_sc_array_0 = 17,
    my number $TYPED_sc_array_1 = 42 / 1_701,
    my string $TYPED_sc_array_2 = 'strings are scalars, too',
    my scalartype $TYPED_sc_array_3 = $mystery_scalar
];
foreach my scalartype $sc ( @{$sc_array} ) {
    print '$sc = ', $sc, "\n";
}
