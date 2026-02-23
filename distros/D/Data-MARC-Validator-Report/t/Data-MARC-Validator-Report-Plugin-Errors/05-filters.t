use strict;
use warnings;

use Data::MARC::Validator::Report::Plugin::Errors;
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report::Plugin::Errors->new(
	'record_id' => 'id1',
);
my $ret_ar = $obj->filters;
is_deeply(
	$ret_ar,
	[],
	'Get filters ([] - default).',
);

# Test.
$obj = Data::MARC::Validator::Report::Plugin::Errors->new(
	'filters' => ['foo', 'bar'],
	'record_id' => 'id1',
);
$ret_ar = $obj->filters;
is_deeply(
	$ret_ar,
	[
		'foo',
		'bar',
	],
	'Get filters (foo, bar).',
);
