#!/usr/bin/env perl

# [[[ PREPROCESSOR ]]]
# <<< EXECUTE_ERROR: 'ERROR ECOOOCO01' >>>
# <<< EXECUTE_ERROR: 'Initialization values for new() method must be key-value pairs inside a hash reference' >>>

# [[[ HEADER ]]]
use strict;
use warnings;
use types;
our $VERSION = 0.000_010;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator

# [[[ INCLUDES ]]]
use Perl::Types::Test::Properties::Class_01_Good;

# [[[ OPERATIONS ]]]
my Perl::Types::Test::Properties::Class_01_Good $test_object = Perl::Types::Test::Properties::Class_01_Good->new( foo => 100 );
print $test_object->{foo} . "\n";
print $test_object->{bar} . "\n";
