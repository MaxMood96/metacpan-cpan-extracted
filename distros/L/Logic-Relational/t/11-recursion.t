use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Program;
BEGIN { no strict 'refs'; delete $main::{call}; }
use Logic::Relational qw(variable call all);

my $family = Logic::Relational::Program->new;
$family->fact( parent => 'alice', 'bob' );
$family->fact( parent => 'bob',   'carol' );
$family->fact( parent => 'alice', 'david' );

my $x = variable('x');
my $y = variable('y');
my $z = variable('z');

$family->rule(
    head => call( ancestor => $x, $y ),
    body => call( parent   => $x, $y ),
);
$family->rule(
    head => call( ancestor => $x, $y ),
    body => all( call( parent => $x, $z ), call( ancestor => $z, $y ), ),
);

# Direction 1: find descendants
my $who1 = variable('who');
my $q1   = $family->query( call( ancestor => 'alice', $who1 ) );
my %descendants;
while ( my $s = $q1->next ) {
    $descendants{ $s->value($who1) } = 1;
}
is( \%descendants, { bob => 1, carol => 1, david => 1 },
    'Descendants correct' );

# Direction 2: find ancestors
my $who2 = variable('who');
my $q2   = $family->query( call( ancestor => $who2, 'carol' ) );
my %ancestors;
while ( my $s = $q2->next ) {
    $ancestors{ $s->value($who2) } = 1;
}
is( \%ancestors, { alice => 1, bob => 1 }, 'Ancestors correct' );

# Direction 3: test proposition
my $q3 = $family->query( call( ancestor => 'alice', 'carol' ) );
ok( $q3->next, 'alice is ancestor of carol' );
my $q4 = $family->query( call( ancestor => 'david', 'carol' ) );
ok( !$q4->next, 'david is NOT ancestor of carol' );

done_testing;
