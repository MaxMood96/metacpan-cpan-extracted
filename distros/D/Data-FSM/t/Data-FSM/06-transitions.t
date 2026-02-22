use strict;
use warnings;

use Data::FSM;
use Data::FSM::State;
use Data::FSM::Transition;
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = Data::FSM->new;
is_deeply(
	$obj->transitions,
	[],
	'Get transitions ([]).',
);

# Test.
my $state1 = Data::FSM::State->new(
	'name' => 'From',
);
my $state2 = Data::FSM::State->new(
	'name' => 'To',
);
$obj = Data::FSM->new(
	'states' => [
		$state1,
		$state2,
	],
	'transitions' => [
		Data::FSM::Transition->new(
			'from' => $state1,
			'to' => $state2,
		),
	],
);
isa_ok($obj->transitions->[0], 'Data::FSM::Transition');
