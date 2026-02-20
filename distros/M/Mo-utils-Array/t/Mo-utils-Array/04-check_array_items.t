use strict;
use warnings;

use English;
use Error::Pure::Utils qw(clean err_msg_hr);
use Mo::utils::Array qw(check_array_items);
use Test::More 'tests' => 10;
use Test::NoWarnings;

# Test.
my $self = {
	'key' => 'foo',
};
eval {
	check_array_items($self, 'key', 1);
};
is($EVAL_ERROR, "Parameter 'key' must be a array.\n",
	"Parameter 'key' must be a array.");
my $err_msg_hr = err_msg_hr();
is($err_msg_hr->{'Reference'}, 'SCALAR', 'Test error parameter (Reference: SCALAR).');
is($err_msg_hr->{'Value'}, 'foo', 'Test error parameter (Value: foo).');
clean();

# Test.
$self = {
	'key' => ['foo', 'bar', 'baz'],
};
eval {
	check_array_items($self, 'key', 2);
};
is($EVAL_ERROR, "Parameter 'key' has more items than expected.\n",
	"Parameter 'key' has more items than expected.");
$err_msg_hr = err_msg_hr();
is($err_msg_hr->{'Maximum items'}, 2, 'Test error parameter (Maximum items: 2).');
is($err_msg_hr->{'Number of items'}, 3, 'Test error parameter (Number of items: 3).');
clean();

# Test.
$self = {};
my $ret = check_array_items($self, 'key', 2);
is($ret, undef, 'Right not exist key.');

# Test.
$self = {
	'key' => [],
};
$ret = check_array_items($self, 'key', 2);
is($ret, undef, 'Right, array is blank.');

# Test.
$self = {
	'key' => ['foo', 'bar'],
};
$ret = check_array_items($self, 'key', 3);
is($ret, undef, 'Right, number of items is smaller than maximum number.');
