use strict;
use warnings;

use Data::FSM::State;
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = Data::FSM::State->new;
is($obj->initial, 0, 'Get initial flag (0 - default).');

# Test.
$obj = Data::FSM::State->new(
	'initial' => 1,
);
is($obj->initial, 1, 'Get initial flag (1).');
