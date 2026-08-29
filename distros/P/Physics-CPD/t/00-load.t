use strict;
use warnings;
use Test::More;

use_ok('Physics::CPD')              or BAIL_OUT('Physics::CPD failed to load');
use_ok('Physics::CPD::Stellarator') or BAIL_OUT('Physics::CPD::Stellarator failed to load');

ok( Physics::CPD->can('new'),              'Physics::CPD has a constructor' );
ok( Physics::CPD::Stellarator->can('new'), 'Stellarator has a constructor' );

my $s = Physics::CPD::Stellarator->new;
isa_ok( $s, 'Physics::CPD::Stellarator', 'object' );
isa_ok( $s, 'Physics::CPD', 'inherits from Physics::CPD' );

done_testing;
