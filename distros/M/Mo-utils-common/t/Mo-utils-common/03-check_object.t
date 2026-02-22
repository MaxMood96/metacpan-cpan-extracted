use strict;
use warnings;

use English;
use Error::Pure::Utils qw(clean);
use Mo::utils::common qw(check_object);
use Test::MockObject;
use Test::More 'tests' => 6;
use Test::NoWarnings;

# Test.
my $value = 'string';
eval {
	check_object($value, 'Test', 'Error.');
};
is($EVAL_ERROR, "Error.\n", "String isn't class.");
clean();

# Test.
$value = 'string';
eval {
	check_object($value, 'Test', 'Error: key: %s, value: %s.', ['foo', 'bar']);
};
is($EVAL_ERROR, "Error: key: foo, value: bar.\n", "String isn't class (with error params).");
clean();

# Test.
$value = [];
eval {
	check_object($value, 'Test', "Reference to array isn't class.");
};
is($EVAL_ERROR, "Reference to array isn't class.\n", "Reference to array isn't class.");
clean();

# Test.
$value = Test::MockObject->new;
eval {
	check_object($value, 'Test', 'Error.');
};
is($EVAL_ERROR, "Error.\n", "Class isn't class.");
clean();

# Test.
$value = Test::MockObject->new;
my $ret = check_object($value, 'Test::MockObject', 'Error.');
is($ret, undef, 'Get returne value (undef).');
