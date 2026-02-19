use strict;
use warnings;

use English;
use Error::Pure::Utils qw(clean err_msg_hr);
use Mo::utils::Number::Alias qw(check_uint8);
use Readonly;
use Test::More 'tests' => 14;
use Test::NoWarnings;

Readonly::Array our @BAD_VALUES => (
	# Bad values.
	[10.0001, "Parameter 'key' must be a natural number."],
	['foo', "Parameter 'key' must be a natural number."],
	[-300, "Parameter 'key' must be a natural number."],

	# Right values, but in bad range.
	[256, "Parameter 'key' must be a natural number between 0 and 255."],
);
Readonly::Array our @RIGHT_VALUES => qw(0 2 255);

# Test.
my ($self, $ret);
foreach my $right_value (@RIGHT_VALUES) {
	$self = {
		'key' => $right_value,
	};
	$ret = check_uint8($self, 'key');
	is($ret, undef, 'Right value is present ('.$self->{'key'}.').');
}

# Test.
$self = {};
$ret = check_uint8($self, 'key');
is($ret, undef, 'Right not exist key.');

# Test.
$self = {
	'key' => undef,
};
$ret = check_uint8($self, 'key');
is($ret, undef, "Value is undefined, that's ok.");

foreach my $range_ar (@BAD_VALUES) {
	$self = {
		'key' => $range_ar->[0],
	};
	eval {
		check_uint8($self, 'key');
	};
	is($EVAL_ERROR, $range_ar->[1]."\n", $range_ar->[1]." Value is '".$range_ar->[0]."'.");
	my $err_msg_hr = err_msg_hr();
	is($err_msg_hr->{'Value'}, $range_ar->[0], 'Test error parameter (Value: '.$range_ar->[0].').');
	clean();
}
