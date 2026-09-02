use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Variable;

my $v1 = Logic::Relational::Variable->new( name => 'X' );
my $v2 = Logic::Relational::Variable->new( name => 'Y' );
my $v3 = Logic::Relational::Variable->new;

ok( $v1->id != $v2->id, 'Variable IDs are unique' );
is( $v1->name, 'X', 'Variable name is correct' );
like( $v1->as_string, qr/^_X_\d+$/,
    'Variable string representation is correct' );

my $map    = {};
my $fresh1 = $v1->freshen($map);
my $fresh2 = $v1->freshen($map);
is( $fresh1->id, $fresh2->id, 'Freshening maps to same variable in same map' );
is( $fresh1->name, $v1->name, 'Fresh variable preserves name' );
ok( $fresh1->id != $v1->id, 'Fresh variable gets a new ID' );

done_testing;
