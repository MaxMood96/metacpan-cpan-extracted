use strict;
use warnings;

use Data::FSM::State;
use English;
use Error::Pure::Utils qw(clean);
use Test::More 'tests' => 7;
use Test::NoWarnings;

# Test.
my $obj = Data::FSM::State->new;
isa_ok($obj, 'Data::FSM::State');

# Test.
eval {
	Data::FSM::State->new(
		'id' => 'bad',
	);
};
is($EVAL_ERROR, "Parameter 'id' must be a positive natural number.\n",
	"Parameter 'id' must be a natural number (bad).");
clean();

# Test.
eval {
	Data::FSM::State->new(
		'id' => 0,
	);
};
is($EVAL_ERROR, "Parameter 'id' must be a positive natural number.\n",
	"Parameter 'id' must be a natural number (0).");
clean();

# Test.
eval {
	Data::FSM::State->new(
		'id' => -1,
	);
};
is($EVAL_ERROR, "Parameter 'id' must be a positive natural number.\n",
	"Parameter 'id' must be a natural number (-1).");
clean();

# Test.
eval {
	Data::FSM::State->new(
		'initial' => 7,
	);
};
is($EVAL_ERROR, "Parameter 'initial' must be a bool (0/1).\n",
	"Parameter 'initial' must be a bool (0/1) (7).");
clean();

# Test.
eval {
	Data::FSM::State->new(
		'name' => ('a' x 101),
	);
};
is($EVAL_ERROR, "Parameter 'name' has length greater than '100'.\n",
	"Parameter 'name' has length greater than '100' (to long name).");
clean();
