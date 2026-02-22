use strict;
use warnings;

use Test::NoWarnings;
use Test::Pod::Coverage 'tests' => 2;

# Test.
pod_coverage_ok('Data::FSM::State',
	{ 'also_private' => ['BUILD'] },
	'Data::FSM::State is covered.');
