use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Program;
BEGIN { no strict 'refs'; delete $main::{call}; }
use Logic::Relational qw(variable call all guard);
use feature 'try';
no warnings 'experimental::try';

my $program = Logic::Relational::Program->new;
$program->fact( age => 'alice', 20 );
$program->fact( age => 'bob',   15 );

# adult(Person) :- age(Person, Age), guard([Age], sub($age) { $age >= 18 }).
my $person = variable('person');
my $age    = variable('age');
$program->rule(
    head => call( adult => $person ),
    body => all(
        call( age => $person, $age ),
        guard(
            [$age],
            sub ($age_val) {
                return $age_val >= 18;
            }
        ),
    ),
);

# 1. Test success and failure of guard
my $who = variable('who');
my $q1  = $program->query( call( adult => $who ) );
my @adults;
while ( my $sol = $q1->next ) {
    push @adults, $sol->value($who);
}
is( \@adults, ['alice'], 'Only alice is an adult (age >= 18)' );

# 2. Test floundering check: guard fails if variable is unbound
my $q2 = $program->query(
    all( guard( [$age], sub ($age_val) { return $age_val >= 18 } ), ) );
my $ok = 0;
try {
    $q2->next;
    $ok = 1;
}
catch ($e) {
    like(
        $e,
        qr/Guard attempted to read unbound logical variable \$age/,
        'Throws error on unbound var'
    );
}
is( $ok, 0, 'Unbound variable in guard caught' );

done_testing;
