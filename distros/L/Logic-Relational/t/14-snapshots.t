use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Program;
BEGIN { no strict 'refs'; delete $main::{call}; }
use Logic::Relational qw(variable call);

my $program = Logic::Relational::Program->new;
$program->fact( colour => 'red' );

my $x     = variable('X');
my $query = $program->query( call( colour => $x ) );

# Assert another fact while query is active
$program->fact( colour => 'green' );

# Query should only see 'red'
my $s1 = $query->next;
is( $s1->value($x), 'red', 'First colour is red' );
ok( !$query->next, 'Query snapshot does not see green' );

# New query should see both
my $query2 = $program->query( call( colour => $x ) );
my @colours;
while ( my $sol = $query2->next ) {
    push @colours, $sol->value($x);
}
is( \@colours, [ 'red', 'green' ], 'New query sees green' );

done_testing;
