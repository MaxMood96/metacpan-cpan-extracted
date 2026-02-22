use strict;
use warnings;

use Data::FSM::State;
use Data::FSM::Transition;
use Data::FSM::Utils qw(check_transition_objects);
use English;
use Error::Pure::Utils qw(clean);
use Test::More 'tests' => 8;
use Test::NoWarnings;

# Common states.
my @states = (
	Data::FSM::State->new(
		'name' => 'From',
	),
	Data::FSM::State->new(
		'name' => 'To',
	),
);

# Test.
my $self = {};
my $ret = check_transition_objects($self, 'key');
is($ret, undef, 'Right not exist key.');

# Test.
$self = {
	'key' => [
		Data::FSM::Transition->new(
			'from' => $states[0],
			'to' => $states[1],
		),
	],
};
$ret = check_transition_objects($self, 'key', \@states);
is($ret, undef, 'Right transition objects.');

# Test.
$self = {
	'key' => 'foo',
};
eval {
	check_transition_objects($self, 'key');
};
is($EVAL_ERROR, "Parameter 'key' must be a array.\n",
	"Parameter 'key' must be a array.");
clean();

# Test.
$self = {
	'key' => [],
};
eval {
	check_transition_objects($self, 'key');
};
is($EVAL_ERROR, "Parameter 'key' check hasn't defined state objects.\n",
	"Parameter 'key' check hasn't defined state objects (undef).");
clean();

# Test.
$self = {
	'key' => [],
};
eval {
	check_transition_objects($self, 'key', 'bad');
};
is($EVAL_ERROR, "Parameter 'key' check hasn't defined state objects.\n",
	"Parameter 'key' check hasn't defined state objects (bad).");
clean();

# Test.
$self = {
	'key' => [
		Data::FSM::Transition->new(
			'from' => $states[0],
			'to' => $states[1],
		),
	],
};
eval {
	check_transition_objects($self, 'key', []);
};
is($EVAL_ERROR, "Parameter 'key' contains object which has 'from' object which isn't in defined objects.\n",
	"Parameter 'key' contains object which has 'from' object which isn't in defined objects (none of defined objects).");
clean();

# Test.
$self = {
	'key' => [
		Data::FSM::Transition->new(
			'from' => $states[0],
			'to' => $states[1],
		),
	],
};
eval {
	check_transition_objects($self, 'key', [$states[0]]);
};
is($EVAL_ERROR, "Parameter 'key' contains object which has 'to' object which isn't in defined objects.\n",
	"Parameter 'key' contains object which has 'to' object which isn't in defined objects (defined states is for from only).");
clean();
