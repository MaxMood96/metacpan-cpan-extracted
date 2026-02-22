use strict;
use warnings;

use Data::FSM::Transition;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Data::FSM::Transition::VERSION, 0.01, 'Version.');
