use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Substitution;
use Logic::Relational::Variable;
use Logic::Relational::Term;

my $subst = Logic::Relational::Substitution->new;
my $x     = Logic::Relational::Variable->new( name => 'X' );
my $y     = Logic::Relational::Variable->new( name => 'Y' );

my $subst2 = $subst->bind( $x->id, $y );
my $subst3 = $subst2->bind( $y->id, 42 );

is( $subst->walk($x),  $x, 'Empty subst walk returns var' );
is( $subst2->walk($x), $y, 'Single bind walk returns bound var' );
is( $subst3->walk($x), 42, 'Chained bind walk returns final constant' );

# Reification
my $term = Logic::Relational::Term->new(
    functor => 'point',
    args    => [ $x, $y ],
);

my $reified = $subst3->reify($term);
is( $reified->functor, 'point', 'Reified term functor preserved' );
is( $reified->arg(0),  42,      'X reified to 42' );
is( $reified->arg(1),  42,      'Y reified to 42' );

done_testing;
