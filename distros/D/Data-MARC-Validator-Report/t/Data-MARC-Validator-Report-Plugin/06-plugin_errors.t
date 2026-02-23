use strict;
use warnings;

use Data::MARC::Validator::Report::Error;
use Data::MARC::Validator::Report::Plugin;
use Data::MARC::Validator::Report::Plugin::Errors;
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report::Plugin->new(
	'module_name' => 'MARC::Validator::Plugin::Foo',
	'name' => 'foo',
	'version' => '0.01',
);
my $ret = $obj->plugin_errors;
is($ret, undef, 'Get plugin errors (undef - no Errors object).');

# Test.
$obj = Data::MARC::Validator::Report::Plugin->new(
	'module_name' => 'MARC::Validator::Plugin::Foo',
	'name' => 'foo',
	'plugin_errors' => [
		Data::MARC::Validator::Report::Plugin::Errors->new(
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
			'filters' => ['filter1', 'filter2'],
			'record_id' => 'id1',
		),
	],
	'version' => '0.01',
);
$ret = $obj->plugin_errors;
isa_ok($ret->[0], 'Data::MARC::Validator::Report::Plugin::Errors');
