# Load testing for YAML::Tiny

use strict;
use warnings;
use lib 't/lib';

BEGIN {
    $|  = 1;
}

use Test::More 0.88;

# Check their perl version
ok( "$]" >= 5.008001, "Your perl is new enough" );

# Does the module load
require_ok( 'YAML::Tiny' );
require_ok( 'TestUtils' );
require_ok( 'TestBridge' );
require_ok( 'TestML::Tiny' );

done_testing;
