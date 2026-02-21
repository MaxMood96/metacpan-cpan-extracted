use strict;
use warnings;

use Mo::utils::Perl;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Mo::utils::Perl::VERSION, 0.01, 'Version.');
