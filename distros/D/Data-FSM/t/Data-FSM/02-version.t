use strict;
use warnings;

use Data::FSM;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Data::FSM::VERSION, 0.01, 'Version.');
