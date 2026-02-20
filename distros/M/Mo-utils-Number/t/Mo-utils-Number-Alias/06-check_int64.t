use strict;
use warnings;

use English;
use Error::Pure::Utils qw(clean err_msg_hr);
use Math::BigInt;
use Mo::utils::Number::Alias qw(check_int64);
use Readonly;
use Test::More 'tests' => 14;
use Test::NoWarnings;

Readonly::Array our @BAD_VALUES => (
	# Bad values.
	[10.0001, "Parameter 'key' must be a integer."],
	['foo', "Parameter 'key' must be a integer."],

	# Right values, but in bad range.
	[Math::BigInt->new("-9223372036854775809"), "Parameter 'key' must be a integer between -9223372036854775808 and 9223372036854775807."],
	[Math::BigInt->new("9223372036854775808"), "Parameter 'key' must be a integer between -9223372036854775808 and 9223372036854775807."],
);
Readonly::Array our @RIGHT_VALUES => qw(-2 0 2);

# Test.
my ($self, $ret);
foreach my $right_value (@RIGHT_VALUES) {
	$self = {
		'key' => $right_value,
	};
	$ret = check_int64($self, 'key');
	is($ret, undef, 'Right value is present ('.$self->{'key'}.').');
}

# Test.
$self = {};
$ret = check_int64($self, 'key');
is($ret, undef, 'Right not exist key.');

# Test.
$self = {
	'key' => undef,
};
$ret = check_int64($self, 'key');
is($ret, undef, "Value is undefined, that's ok.");

foreach my $range_ar (@BAD_VALUES) {
	$self = {
		'key' => $range_ar->[0],
	};
	eval {
		check_int64($self, 'key');
	};
	is($EVAL_ERROR, $range_ar->[1]."\n", $range_ar->[1]." Value is '".$range_ar->[0]."'.");
	my $err_msg_hr = err_msg_hr();
	is($err_msg_hr->{'Value'}, $range_ar->[0], 'Test error parameter (Value: '.$range_ar->[0].').');
	clean();
}
