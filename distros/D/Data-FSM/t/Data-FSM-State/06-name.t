use strict;
use warnings;

use Data::FSM::State;
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = Data::FSM::State->new;
is($obj->name, undef, 'Get name (undef - default).');

# Test.
$obj = Data::FSM::State->new(
	'name' => 'state',
);
is($obj->name, 'state', 'Get name (state).');
