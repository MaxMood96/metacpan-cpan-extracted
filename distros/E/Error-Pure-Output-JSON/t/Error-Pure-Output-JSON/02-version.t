use strict;
use warnings;

use Error::Pure::Output::JSON;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Error::Pure::Output::JSON::VERSION, 0.11, 'Version.');
