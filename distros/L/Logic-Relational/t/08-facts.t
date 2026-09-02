use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Program;
BEGIN { no strict 'refs'; delete $main::{call}; }
use Logic::Relational qw(variable call);

my $program = Logic::Relational::Program->new;
$program->fact( colour => 'red' );
$program->fact( colour => 'green' );

my $x     = variable('X');
my $query = $program->query( call( colour => $x ) );

my $s1 = $query->next;
is( $s1->value($x), 'red', 'First colour is red' );

my $s2 = $query->next;
is( $s2->value($x), 'green', 'Second colour is green' );

ok( !$query->next, 'No more colours' );

done_testing;
