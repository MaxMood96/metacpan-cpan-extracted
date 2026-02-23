use strict;
use warnings;

use Data::MARC::Validator::Report::Error;
use Data::MARC::Validator::Report::Plugin::Errors;
use English;
use Error::Pure::Utils qw(clean);
use Test::More 'tests' => 6;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report::Plugin::Errors->new(
	'record_id' => 'id1',
);
isa_ok($obj, 'Data::MARC::Validator::Report::Plugin::Errors');

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
	'filters' => ['filter1', 'filter2'],
	'record_id' => 'id1',
);
isa_ok($obj, 'Data::MARC::Validator::Report::Plugin::Errors');

# Test.
eval {
	Data::MARC::Validator::Report::Plugin::Errors->new(
		'errors' => 'bad',
		'record_id' => 'id1',
	);
};
is($EVAL_ERROR, "Parameter 'errors' must be a array.\n",
	"Parameter 'errors' must be a array (bad).");
clean();

# Test.
eval {
	Data::MARC::Validator::Report::Plugin::Errors->new(
		'filters' => 'bad',
		'record_id' => 'id1',
	);
};
is($EVAL_ERROR, "Parameter 'filters' must be a array.\n",
	"Parameter 'filters' must be a array (string).");
clean();

# Test.
eval {
	Data::MARC::Validator::Report::Plugin::Errors->new;
};
is($EVAL_ERROR, "Parameter 'record_id' is required.\n",
	"Parameter 'record_id' is required.");
clean();
