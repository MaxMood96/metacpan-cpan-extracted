use strict;
use warnings;

use Mo::utils::Number::Alias;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Mo::utils::Number::Alias::VERSION, 0.09, 'Version.');
