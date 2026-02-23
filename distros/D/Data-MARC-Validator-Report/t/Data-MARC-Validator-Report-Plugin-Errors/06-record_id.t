use strict;
use warnings;

use Data::MARC::Validator::Report::Plugin::Errors;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report::Plugin::Errors->new(
	'record_id' => 'id1',
);
my $ret = $obj->record_id;
is($ret, 'id1', 'Get record id (id1).');
