use strict;
use warnings;

use Data::FSM::State;
use Data::FSM::Transition;
use English;
use Error::Pure::Utils qw(clean);
use Test::More 'tests' => 8;
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
isa_ok($obj, 'Data::FSM::Transition');

# Test.
eval {
	Data::FSM::Transition->new(
		'callback' => 'bad',
		'from' => Data::FSM::State->new(
			'initial' => 1,
			'name' => 'initial',
		),
		'to' => Data::FSM::State->new(
			'name' => 'run',
		),
	);
};
is($EVAL_ERROR, "Parameter 'callback' must be a code.\n",
	"Parameter 'callback' must be a code (bad).");
clean();

# Test.
eval {
	Data::FSM::Transition->new(
		'to' => Data::FSM::State->new(
			'name' => 'run',
		),
	);
};
is($EVAL_ERROR, "Parameter 'from' is required.\n", "Parameter 'from' is required.");
clean();

# Test.
eval {
	Data::FSM::Transition->new(
		'from' => Data::FSM::State->new(
			'initial' => 1,
			'name' => 'initial',
		),
		'id' => 'bad',
		'to' => Data::FSM::State->new(
			'name' => 'run',
		),
	);
};
is($EVAL_ERROR, "Parameter 'id' must be a positive natural number.\n",
	"Parameter 'id' must be a natural number (bad).");
clean();

# Test.
eval {
	Data::FSM::Transition->new(
		'from' => Data::FSM::State->new(
			'initial' => 1,
			'name' => 'initial',
		),
		'id' => 0,
		'to' => Data::FSM::State->new(
			'name' => 'run',
		),
	);
};
is($EVAL_ERROR, "Parameter 'id' must be a positive natural number.\n",
	"Parameter 'id' must be a natural number (0).");
clean();

# Test.
eval {
	Data::FSM::Transition->new(
		'from' => Data::FSM::State->new(
			'initial' => 1,
			'name' => 'initial',
		),
		'id' => -1,
		'to' => Data::FSM::State->new(
			'name' => 'run',
		),
	);
};
is($EVAL_ERROR, "Parameter 'id' must be a positive natural number.\n",
	"Parameter 'id' must be a natural number (-1).");
clean();

# Test.
eval {
	Data::FSM::Transition->new(
		'from' => Data::FSM::State->new(
			'initial' => 1,
			'name' => 'initial',
		),
	);
};
is($EVAL_ERROR, "Parameter 'to' is required.\n", "Parameter 'to' is required.");
clean();
