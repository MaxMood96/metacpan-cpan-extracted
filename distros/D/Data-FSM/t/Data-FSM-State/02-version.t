use strict;
use warnings;

use Data::FSM::State;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Data::FSM::State::VERSION, 0.01, 'Version.');
