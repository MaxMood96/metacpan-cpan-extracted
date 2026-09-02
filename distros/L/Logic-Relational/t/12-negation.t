use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Program;
BEGIN { no strict 'refs'; delete $main::{call}; }
use Logic::Relational qw(variable call all not_goal);
use feature 'try';
no warnings 'experimental::try';

my $program = Logic::Relational::Program->new;
$program->fact( thief => 'badguy' );
$program->fact( knows => 'badguy', 'merlyn' );

my $perp   = variable('perp');
my $victim = variable('victim');

# 1. Success case: ground negation
# knows(badguy, david) should fail, so not_goal(knows(badguy, david)) should succeed
my $q1 =
  $program->query( all( not_goal( call( knows => 'badguy', 'david' ) ), ) );
ok( $q1->next, 'Ground negation succeeds when inner goal fails' );

# 2. Failure case: ground negation fails
# knows(badguy, merlyn) succeeds, so not_goal(knows(badguy, merlyn)) should fail
my $q2 =
  $program->query( all( not_goal( call( knows => 'badguy', 'merlyn' ) ), ) );
ok( !$q2->next, 'Ground negation fails when inner goal succeeds' );

# 3. Floundering case: unbound variable inside negated goal
my $q3 =
  $program->query( all( not_goal( call( knows => 'badguy', $victim ) ), ) );
my $ok = 0;
try {
    $q3->next;
    $ok = 1;
}
catch ($e) {
    like(
        $e,
        qr/Negated goal contains unbound variable \$victim/,
        'Throws floundering error'
    );
}
is( $ok, 0, 'Unbound variable in negation was caught' );

done_testing;
