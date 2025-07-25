#!/usr/bin/env perl

# [[[ PREPROCESSOR ]]]
# <<< EXECUTE_ERROR: 'ERROR EAVRVIV03, TYPE-CHECKING MISMATCH' >>>
# <<< EXECUTE_ERROR: 'integer value expected but non-integer value found at index 3' >>>

# [[[ HEADER ]]]
use strict;
use warnings;
use types;
our $VERSION = 0.000_001;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator

# [[[ INCLUDES ]]]
use Perl::Types::Test::TypeCheckingOn::AllTypes;

# [[[ OPERATIONS ]]]
check_arrayref_integer( [ -999_999, 3, 4, [ 0, 1, 2 ] ] );
