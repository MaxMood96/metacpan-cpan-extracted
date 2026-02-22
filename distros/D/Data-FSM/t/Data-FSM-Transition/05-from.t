use strict;
use warnings;

use Data::FSM::State;
use Data::FSM::Transition;
use Test::More 'tests' => 2;
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
isa_ok($obj->from, 'Data::FSM::State');
