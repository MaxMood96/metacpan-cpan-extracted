use strict;
use warnings;

use Test::More 'tests' => 2;
use Test::NoWarnings;
use Test::Shared::Fixture::Data::OFN::Address::Place;

# Test.
my $obj = Test::Shared::Fixture::Data::OFN::Address::Place->new;
is_deeply($obj->vusc_name, [], 'Get street name (reference to blank array - default).');
