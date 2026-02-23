use strict;
use warnings;

use Test::More 'tests' => 3;
use Test::NoWarnings;

BEGIN {

	# Test.
	use_ok('Data::MARC::Validator::Report::Plugin');
}

# Test.
require_ok('Data::MARC::Validator::Report::Plugin');
