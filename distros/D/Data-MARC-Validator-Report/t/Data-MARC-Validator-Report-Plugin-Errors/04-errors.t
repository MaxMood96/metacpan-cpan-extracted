use strict;
use warnings;

use Data::MARC::Validator::Report::Error;
use Data::MARC::Validator::Report::Plugin::Errors;
use Test::More 'tests' => 4;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report::Plugin::Errors->new(
	'record_id' => 'id1',
);
my $ret_ar = $obj->errors;
is_deeply(
	$ret_ar,
	[],
	'Get errors ([] - default).',
);

# Test.
$obj = Data::MARC::Validator::Report::Plugin::Errors->new(
	'errors' => [
		Data::MARC::Validator::Report::Error->new(
			'error' => 'Error #1',
			'params' => {
				'key' => 'value',
			},
		),
		Data::MARC::Validator::Report::Error->new(
			'error' => 'Error #2',
			'params' => {
				'key' => 'value',
			},
		),
	],
	'record_id' => 'id1',
);
$ret_ar = $obj->errors;
isa_ok($ret_ar->[0], 'Data::MARC::Validator::Report::Error');
isa_ok($ret_ar->[1], 'Data::MARC::Validator::Report::Error');
