use strict;
use warnings;

use English;
use Error::Pure::Utils qw(clean err_msg_hr);
use Mo::utils::Binary qw(check_bytes_len);
use Test::More 'tests' => 11;
use Test::NoWarnings;
use Unicode::UTF8 qw(decode_utf8);

# Test.
my $self = {
	'key' => 'foo',
};
my $ret = check_bytes_len($self, 'key', 3);
is($ret, undef, 'Right bytes length is present (expected 3, real 3).');

# Test.
$self = {
	'key' => 'foo',
};
$ret = check_bytes_len($self, 'key', 10);
is($ret, undef, 'Right bytes length is present (expected 10, real 3).');

# Test.
$self = {};
$ret = check_bytes_len($self, 'key');
is($ret, undef, "Right, key doesn't exists.");

# Test.
$self = {
	'key' => undef,
};
$ret = check_bytes_len($self, 'key');
is($ret, undef, "Value is undefined, that's ok.");

# Test.
$self = {
	# Chinese forest, 2x3 bytes.
	'key' => decode_utf8('森林'),
};
eval {
	check_bytes_len($self, 'key', 2);
};
is($EVAL_ERROR, "Parameter 'key' has bad bytes length.\n",
	"Parameter 'key' has bad bytes length (森林 = ? bytes length).");
my $err_msg_hr = err_msg_hr();
is($err_msg_hr->{'Value'}, decode_utf8('森林'), 'Test error parameter (Value: 森林).');
is($err_msg_hr->{'Expected bytes length'}, 2, 'Test error parameter (Expected bytes length: 2).');
is($err_msg_hr->{'Real bytes length'}, 6, 'Test error parameter (Real bytes length: 6).');
clean();

# Test.
$self = {
	# Chinese forest, 2x3 bytes.
	'key' => decode_utf8('森林'),
};
$ret = length($self->{'key'});
is($ret, 2, 'Get length of string (2, before check).');
check_bytes_len($self, 'key', 6);
$ret = length($self->{'key'});
is($ret, 2, 'Get length of string (2, after check).');
