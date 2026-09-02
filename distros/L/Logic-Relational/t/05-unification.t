use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Unifier;
use Logic::Relational::Substitution;
use Logic::Relational::Variable;
use Logic::Relational::Term;
use Logic::Relational::Atom;

my $subst = Logic::Relational::Substitution->new;
my $x     = Logic::Relational::Variable->new( name => 'X' );
my $y     = Logic::Relational::Variable->new( name => 'Y' );

# Constant unification
ok( Logic::Relational::Unifier::unify( 1, 1, $subst ),
    'Identical numbers unify' );
ok( !Logic::Relational::Unifier::unify( 1, 2, $subst ),
    'Different numbers fail' );
ok( Logic::Relational::Unifier::unify( 'foo', 'foo', $subst ),
    'Identical strings unify' );
ok( !Logic::Relational::Unifier::unify( 'foo', 'bar', $subst ),
    'Different strings fail' );

# Atom unification
my $atom1 = Logic::Relational::Atom->new('gold');
my $atom2 = Logic::Relational::Atom->new('gold');
my $atom3 = Logic::Relational::Atom->new('rubies');
ok( Logic::Relational::Unifier::unify( $atom1, $atom2, $subst ),
    'Identical atoms unify' );
ok( !Logic::Relational::Unifier::unify( $atom1, $atom3, $subst ),
    'Different atoms fail' );
ok( Logic::Relational::Unifier::unify( $atom1, 'gold', $subst ),
    'Atom unifies with raw string' );

# Variable unification
my $s2 = Logic::Relational::Unifier::unify( $x, 42, $subst );
ok( $s2, 'Unifying var with constant succeeds' );
is( $s2->walk($x), 42, 'Var is bound to constant' );

# Compound term unification
my $t1 = Logic::Relational::Term->new( functor => 'point', args => [ $x, 2 ] );
my $t2 = Logic::Relational::Term->new( functor => 'point', args => [ 1, $y ] );
my $s3 = Logic::Relational::Unifier::unify( $t1, $t2, $subst );
ok( $s3, 'Compound terms unify' );
is( $s3->walk($x), 1, 'X is bound to 1' );
is( $s3->walk($y), 2, 'Y is bound to 2' );

done_testing;
