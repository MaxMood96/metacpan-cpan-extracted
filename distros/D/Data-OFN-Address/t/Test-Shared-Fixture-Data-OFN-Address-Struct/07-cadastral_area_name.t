use strict;
use warnings;

use Test::More 'tests' => 2;
use Test::NoWarnings;
use Test::Shared::Fixture::Data::OFN::Address::Struct;

# Test.
my $obj = Test::Shared::Fixture::Data::OFN::Address::Struct->new;
is_deeply(
	$obj->cadastral_area_name,
	[],
	'Get cadastral area name (reference to blank array - default).',
);
