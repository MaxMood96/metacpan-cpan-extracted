use strict;
use warnings;

use Data::FSM;
use Data::FSM::State;
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = Data::FSM->new;
is_deeply(
	$obj->states,
	[],
	'Get states ([]).',
);

# Test.
$obj = Data::FSM->new(
	'states' => [
		Data::FSM::State->new,
	],
);
isa_ok($obj->states->[0], 'Data::FSM::State');
