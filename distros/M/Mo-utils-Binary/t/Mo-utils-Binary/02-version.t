use strict;
use warnings;

use Mo::utils::Binary;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Mo::utils::Binary::VERSION, 0.01, 'Version.');
