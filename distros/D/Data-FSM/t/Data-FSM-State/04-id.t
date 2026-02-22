use strict;
use warnings;

use Data::FSM::State;
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = Data::FSM::State->new;
is($obj->id, undef, 'Get id (undef - default).');

# Test.
$obj = Data::FSM::State->new(
	'id' => 7,
);
is($obj->id, 7, 'Get id (7).');
