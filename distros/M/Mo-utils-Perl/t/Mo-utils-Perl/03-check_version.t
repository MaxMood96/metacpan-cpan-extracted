use strict;
use warnings;

use English;
use Error::Pure::Utils qw(clean);
use Mo::utils::Perl qw(check_version);
use Test::More 'tests' => 6;
use Test::NoWarnings;

# Test.
my $self = {
	'key' => '0.01',
};
my $ret = check_version($self, 'key');
is($ret, undef, "Perl version '0.01' is valid.");

# Test.
$self = {
	'key' => 'bad',
};
eval {
	check_version($self, 'key');
};
is($EVAL_ERROR, "Parameter 'key' isn't right Perl version.\n",
	"Parameter 'key' isn't right Perl version (bad).");
clean();

# Test.
$self = {
	'key' => '',
};
eval {
	check_version($self, 'key');
};
is($EVAL_ERROR, "Parameter 'key' isn't right Perl version.\n",
	"Parameter 'key' isn't right Perl version (blank string).");
clean();

# Test.
$self = {};
$ret = check_version($self, 'key');
is($ret, undef, 'Right not exist key.');

# Test.
$self = {
	'key' => undef,
};
$ret = check_version($self, 'key');
is($ret, undef, "Value is undefined, that's ok.");
