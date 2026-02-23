use strict;
use warnings;

use Data::MARC::Validator::Report::Plugin;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report::Plugin->new(
	'module_name' => 'MARC::Validator::Plugin::Foo',
	'name' => 'foo',
	'version' => '0.01',
);
my $ret = $obj->module_name;
is($ret, 'MARC::Validator::Plugin::Foo',
	'Get module name (MARC::Validator::Plugin::Foo).');
