use strict;
use warnings;

use Test::NoWarnings;
use Test::Pod::Coverage 'tests' => 2;

# Test.
pod_coverage_ok('Data::FSM::Transition',
	{ 'also_private' => ['BUILD'] },
	'Data::FSM::Transition is covered.');
