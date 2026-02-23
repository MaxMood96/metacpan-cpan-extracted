use strict;
use warnings;

use Data::MARC::Validator::Report::Error;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report::Error->new(
	'error' => 'This is the error',
);
my $ret = $obj->error;
is($ret, 'This is the error', 'Get error (This is the error).');
