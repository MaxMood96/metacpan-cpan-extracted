use strict;
use warnings;

use Data::MARC::Validator::Report::Error;
use English;
use Error::Pure::Utils qw(clean);
use Test::More 'tests' => 5;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report::Error->new(
	'error' => 'This is the error',
	'params' => {
		'key1' => 'value1',
		'key2' => 'value2',
	},
);
isa_ok($obj, 'Data::MARC::Validator::Report::Error');

# Test.
$obj = Data::MARC::Validator::Report::Error->new(
	'error' => 'This is the error',
);
isa_ok($obj, 'Data::MARC::Validator::Report::Error');

# Test.
eval {
	Data::MARC::Validator::Report::Error->new;
};
is($EVAL_ERROR, "Parameter 'error' is required.\n",
	"Parameter 'error' is required.");
clean();

# Test.
eval {
	Data::MARC::Validator::Report::Error->new(
		'error' => 'This is the error',
		'params' => 'bad',
	);
};
is($EVAL_ERROR, "Parameter 'params' isn't hash reference.\n",
	"Parameter 'params' isn't hash reference (string).");
clean();
