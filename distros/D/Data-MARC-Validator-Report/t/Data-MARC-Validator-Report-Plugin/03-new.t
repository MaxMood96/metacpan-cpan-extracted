use strict;
use warnings;

use Data::MARC::Validator::Report::Error;
use Data::MARC::Validator::Report::Plugin;
use Data::MARC::Validator::Report::Plugin::Errors;
use English;
use Error::Pure::Utils qw(clean);
use Test::More 'tests' => 7;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report::Plugin->new(
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
isa_ok($obj, 'Data::MARC::Validator::Report::Plugin');

# Test.
$obj = Data::MARC::Validator::Report::Plugin->new(
	'module_name' => 'MARC::Validator::Plugin::Foo',
	'name' => 'foo',
	'version' => '0.01',
);
isa_ok($obj, 'Data::MARC::Validator::Report::Plugin');

# Test.
eval {
	Data::MARC::Validator::Report::Plugin->new(
		'name' => 'foo',
		'version' => '0.01',
	);
};
is($EVAL_ERROR, "Parameter 'module_name' is required.\n",
	"Parameter 'module_name' is required.");
clean();

# Test.
eval {
	Data::MARC::Validator::Report::Plugin->new(
		'module_name' => 'MARC::Validator::Plugin::Foo',
		'version' => '0.01',
	);
};
is($EVAL_ERROR, "Parameter 'name' is required.\n",
	"Parameter 'name' is required.");
clean();

# Test.
eval {
	Data::MARC::Validator::Report::Plugin->new(
		'module_name' => 'MARC::Validator::Plugin::Foo',
		'name' => 'foo',
	);
};
is($EVAL_ERROR, "Parameter 'version' is required.\n",
	"Parameter 'version' is required.");
clean();

# Test.
eval {
	Data::MARC::Validator::Report::Plugin->new(
		'module_name' => 'MARC::Validator::Plugin::Foo',
		'name' => 'foo',
		'version' => 'bad',
	);
};
is($EVAL_ERROR, "Parameter 'version' isn't right Perl version.\n",
	"Parameter 'version' isn't right Perl version (bad).");
clean();
