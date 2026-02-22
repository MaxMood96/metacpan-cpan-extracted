use strict;
use warnings;

use Data::FSM;
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = Data::FSM->new;
is($obj->id, undef, 'Get id (undef - default).');

# Test.
$obj = Data::FSM->new(
	'id' => 7,
);
is($obj->id, 7, 'Get id (7).');
