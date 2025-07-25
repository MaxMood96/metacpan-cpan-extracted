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

my arrayref::string $s_array_0 = [ 'a', 'b', 'c' ];
my arrayref::string $s_array_1 = [ 'd', 'e', 'f' ];
my arrayref::string $s_array_2 = [ 'g', 'h', 'i' ];
my arrayref::string $s_array_all = [ @{$s_array_0}, @{$s_array_1}, @{$s_array_2} ];
foreach my arrayref::string $s ( @{$s_array_all} ) {
    print '$s = ', Dumper($s), "\n";
}
