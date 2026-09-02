use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Program;
BEGIN { no strict 'refs'; delete $main::{call}; }
use Logic::Relational qw(variable call all);

my $program = Logic::Relational::Program->new;
$program->fact( sibling => 'alice', 'bob' );
$program->fact( sibling => 'bob',   'carol' );

# related(X, Y) :- sibling(X, Y).
# related(X, Y) :- sibling(X, Z), related(Z, Y).
my $x = variable('x');
my $y = variable('y');
my $z = variable('z');

$program->rule(
    head => call( related => $x, $y ),
    body => call( sibling => $x, $y ),
);
$program->rule(
    head => call( related => $x, $y ),
    body => all( call( sibling => $x, $z ), call( related => $z, $y ), ),
);

# If freshening does not work, variable $z will clash across recursive steps.
my $who = variable('who');
my $q   = $program->query( call( related => 'alice', $who ) );

my $s1 = $q->next;
is( $s1->value($who), 'bob', 'Alice related to Bob directly' );
my $s2 = $q->next;
is( $s2->value($who), 'carol', 'Alice related to Carol recursively' );
ok( !$q->next, 'No more relations' );

done_testing;
