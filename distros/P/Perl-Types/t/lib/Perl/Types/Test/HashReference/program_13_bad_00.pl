#!/usr/bin/env perl

# [[[ PREPROCESSOR ]]]
# <<< PARSE_ERROR: 'ERROR ECOPARP00' >>>
# <<< PARSE_ERROR: 'Unexpected Token:  }' >>>

# [[[ HEADER ]]]
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils

# [[[ OPERATIONS ]]]

my hashref $unknown_hash = {
    key0 => my integer $TYPED_key0         = -23,
    key1 => my arrayref::number $TYPED_key1 = [ 42 / 1_701, 21.12, 2_112.23 ],
    key2 => my hashref::string $TYPED_key2  = { alpha => 'strings are scalars, too', beta => 'hello world', gamma => 'last one', }
};
print Dumper($unknown_hash);
