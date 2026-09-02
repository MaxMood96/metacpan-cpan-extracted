use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Program;
BEGIN { no strict 'refs'; delete $main::{call}; }
use Logic::Relational qw(variable call all);

my $program = Logic::Relational::Program->new;
$program->fact( parent => 'alice', 'bob' );
$program->fact( parent => 'bob',   'carol' );

my $x = variable('x');
my $y = variable('y');
my $z = variable('z');

# grandparent(X, Y) :- parent(X, Z), parent(Z, Y).
$program->rule(
    head => call( grandparent => $x, $y ),
    body => all( call( parent => $x, $z ), call( parent => $z, $y ), ),
);

my $who = variable('who');
my $q   = $program->query( call( grandparent => 'alice', $who ) );
my $s   = $q->next;
ok( $s, 'Grandparent rule succeeds' );
is( $s->value($who), 'carol', 'grandparent of alice is carol' );
ok( !$q->next, 'No more grandparents' );

done_testing;
