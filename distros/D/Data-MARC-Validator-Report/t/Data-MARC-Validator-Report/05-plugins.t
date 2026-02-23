use strict;
use warnings;

use Data::MARC::Validator::Report;
use Data::MARC::Validator::Report::Plugin;
use DateTime;
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = Data::MARC::Validator::Report->new(
	'datetime' => DateTime->now,
);
my $ret_ar = $obj->plugins;
is_deeply(
	$ret_ar,
	[],
	'Get plugins ([] - default).',
);

# Test.
$obj = Data::MARC::Validator::Report->new(
	'datetime' => DateTime->now,
	'plugins' => [
		Data::MARC::Validator::Report::Plugin->new(
			'module_name' => 'MARC::Validator::Plugin::Foo',
			'name' => 'foo',
			'version' => 0.01,
		),
	],
);
$ret_ar = $obj->plugins;
isa_ok($ret_ar->[0], 'Data::MARC::Validator::Report::Plugin');
