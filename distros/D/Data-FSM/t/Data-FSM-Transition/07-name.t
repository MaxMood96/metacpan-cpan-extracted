use strict;
use warnings;

use Data::FSM::State;
use Data::FSM::Transition;
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = Data::FSM::Transition->new(
	'from' => Data::FSM::State->new(
		'initial' => 1,
		'name' => 'initial',
	),
	'to' => Data::FSM::State->new(
		'name' => 'run',
	),
);
is($obj->name, undef, 'Get name (undef - default).');

# Test.
$obj = Data::FSM::Transition->new(
	'from' => Data::FSM::State->new(
		'initial' => 1,
		'name' => 'initial',
	),
	'name' => 'Transition',
	'to' => Data::FSM::State->new(
		'name' => 'run',
	),
);
is($obj->name, 'Transition', 'Get name (Transition).');
