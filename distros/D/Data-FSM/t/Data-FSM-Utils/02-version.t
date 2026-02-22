use strict;
use warnings;

use Data::FSM::Utils;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Data::FSM::Utils::VERSION, 0.01, 'Version.');
