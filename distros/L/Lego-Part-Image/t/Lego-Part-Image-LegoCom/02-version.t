use strict;
use warnings;

use Lego::Part::Image::LegoCom;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Lego::Part::Image::LegoCom::VERSION, 0.06, 'Version.');
