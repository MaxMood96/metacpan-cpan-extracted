use strict;
use warnings;

use Test::More 'tests' => 3;
use Test::NoWarnings;

BEGIN {

	# Test.
	use_ok('Data::FSM::State');
}

# Test.
require_ok('Data::FSM::State');
