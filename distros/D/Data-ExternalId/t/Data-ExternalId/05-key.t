use strict;
use warnings;

use Data::ExternalId;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
my $obj = Data::ExternalId->new(
	'key' => 'VIAF',
	'value' => '265219579',
);
is($obj->key, 'VIAF', 'Get key (VIAF).');
