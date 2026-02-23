use strict;
use warnings;

use Test::NoWarnings;
use Test::Pod::Coverage 'tests' => 2;

# Test.
pod_coverage_ok('Data::MARC::Validator::Report::Errors',
	{ 'also_private' => ['BUILD'] },
	'Data::MARC::Validator::Report::Errors is covered.');
