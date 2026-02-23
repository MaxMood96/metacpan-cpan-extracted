use strict;
use warnings;

use Data::MARC::Validator::Report;
use DateTime;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report->new(
	'datetime' => DateTime->now,
);
isa_ok($obj, 'Data::MARC::Validator::Report');
