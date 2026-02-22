use strict;
use warnings;

use Data::FSM;
use Data::FSM::State;
use Data::FSM::Transition;
use English;
use Error::Pure::Utils qw(clean);
use Test::More 'tests' => 12;
use Test::NoWarnings;

# Test.
my $obj = Data::FSM->new;
isa_ok($obj, 'Data::FSM');

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
isa_ok($obj, 'Data::FSM');

# Test.
eval {
	Data::FSM->new(
		'id' => 'bad',
	);
};
is($EVAL_ERROR, "Parameter 'id' must be a positive natural number.\n",
	"Parameter 'id' must be a positive natural number (bad).");
clean();

# Test.
eval {
	Data::FSM->new(
		'id' => 0,
	);
};
is($EVAL_ERROR, "Parameter 'id' must be a positive natural number.\n",
	"Parameter 'id' must be a positive natural number (0).");
clean();

# Test.
eval {
	Data::FSM->new(
		'id' => -1,
	);
};
is($EVAL_ERROR, "Parameter 'id' must be a positive natural number.\n",
	"Parameter 'id' must be a positive natural number (-1).");
clean();

# Test.
eval {
	Data::FSM->new(
		'states' => 'bad',
	);
};
is($EVAL_ERROR, "Parameter 'states' must be a array.\n",
	"Parameter 'states' must be a array (bad).");
clean();

# Test.
eval {
	Data::FSM->new(
		'states' => ['bad'],
	);
};
is($EVAL_ERROR, "Parameter 'states' with array must contain 'Data::FSM::State' objects.\n",
	"Parameter 'states' with array must contain 'Data::FSM::State' objects (bad string).");
clean();

# Test.
eval {
	Data::FSM->new(
		'transitions' => 'bad',
	);
};
is($EVAL_ERROR, "Parameter 'transitions' must be a array.\n",
	"Parameter 'transitions' must be a array (bad).");
clean();

# Test.
eval {
	Data::FSM->new(
		'transitions' => ['bad'],
	);
};
is($EVAL_ERROR, "Parameter 'transitions' with array must contain 'Data::FSM::Transition' objects.\n",
	"Parameter 'transitions' with array must contain 'Data::FSM::Transition' objects (bad string).");
clean();

# Test.
eval {
	my $state = Data::FSM::State->new;
	Data::FSM->new(
		'transitions' => [
			Data::FSM::Transition->new(
				'from' => $state,
				'to' => $state,
			),
		],
	);
};
is($EVAL_ERROR, "Parameter 'transitions' contains object which has 'from' object which isn't in defined objects.\n",
	"Parameter 'transitions' contains object which has 'from' object which isn't in defined objects.");
clean();

# Test.
eval {
	my $state1 = Data::FSM::State->new;
	my $state2 = Data::FSM::State->new;
	Data::FSM->new(
		'states' => [
			$state1,
		],
		'transitions' => [
			Data::FSM::Transition->new(
				'from' => $state1,
				'to' => $state2,
			),
		],
	);
};
is($EVAL_ERROR, "Parameter 'transitions' contains object which has 'to' object which isn't in defined objects.\n",
	"Parameter 'transitions' contains object which has 'to' object which isn't in defined objects.");
clean();
