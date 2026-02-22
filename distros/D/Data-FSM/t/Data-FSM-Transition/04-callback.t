use strict;
use warnings;

use Data::FSM::State;
use Data::FSM::Transition;
use Test::More 'tests' => 4;
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
is($obj->callback, undef, 'Get callback (undef - default).');

# Test.
$obj = Data::FSM::Transition->new(
	'callback' => sub {
		return 1;
	},
	'from' => Data::FSM::State->new(
		'initial' => 1,
		'name' => 'initial',
	),
	'to' => Data::FSM::State->new(
		'name' => 'run',
	),
);
is(ref $obj->callback, 'CODE', 'Get callback reference (CODE).');
is($obj->callback->(), 1, 'Get callback return (1).');
