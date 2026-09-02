use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Unifier;
use Logic::Relational::Substitution;
use Logic::Relational::Variable;
use Logic::Relational::Term;
use feature 'try';
no warnings 'experimental::try';

my $subst = Logic::Relational::Substitution->new;
my $x     = Logic::Relational::Variable->new( name => 'X' );
my $term  = Logic::Relational::Term->new(
    functor => 'thing',
    args    => [$x],
);

my $ok = 0;
try {
    Logic::Relational::Unifier::unify( $x, $term, $subst );
    $ok = 1;
}
catch ($e) {
    like( $e, qr/Occurs check failed/, 'Occurs check throws exception' );
}
is( $ok, 0, 'Occurs check prevented unification' );

done_testing;
