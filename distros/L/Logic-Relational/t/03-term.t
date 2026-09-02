use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Term;
use Logic::Relational::Variable;

my $x    = Logic::Relational::Variable->new( name => 'X' );
my $term = Logic::Relational::Term->new(
    functor => 'point',
    args    => [ $x, 42 ],
);

is( $term->functor,      'point', 'Functor is point' );
is( $term->arity,        2,       'Arity is 2' );
is( $term->arg(0)->name, 'X',     'First arg is X' );
is( $term->arg(1),       42,      'Second arg is 42' );
like( $term->as_string, qr/^point\(_X_\d+, 42\)$/,
    'Term as_string is correct' );

my $map   = {};
my $fresh = $term->freshen($map);
is( $fresh->functor, 'point', 'Freshened term keeps functor' );
is( $fresh->arity,   2,       'Freshened term keeps arity' );
ok( $fresh->arg(0)->id != $x->id, 'Freshened variable argument gets new ID' );
is( $fresh->arg(1), 42, 'Constant argument is preserved' );

done_testing;
