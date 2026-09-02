use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Program;
BEGIN { no strict 'refs'; delete $main::{call}; }
use Logic::Relational qw(variable call);
use feature 'try';
no warnings 'experimental::try';

my $program = Logic::Relational::Program->new;
my $id1     = $program->fact( valuable => 'gold' );
my $id2     = $program->fact( valuable => 'rubies' );
my $id3     = $program->fact( valuable => 'diamonds' );

is( $program->clauses_for( 'valuable', 1 ), 3, '3 clauses exist' );

# Retract by pattern
my $res = $program->retract( valuable => 'rubies' );
is( $res,                                   1, 'retract rubies returns 1' );
is( $program->clauses_for( 'valuable', 1 ), 2, '2 clauses left' );

# Retract by ID
my $res2 = $program->retract_clause($id1);    # gold
is( $res2, 1, 'retract_clause gold returns 1' );
is( $program->clauses_for( 'valuable', 1 ), 1, '1 clause left' );

# Retract ID non-existent throws
my $ok = 0;
try {
    $program->retract_clause('clause-non-existent');
    $ok = 1;
}
catch ($e) {
    like( $e, qr/does not exist/, 'Retracting invalid ID throws' );
}
is( $ok, 0, 'Invalid ID caught' );

# Retract all
$program->fact( valuable => 'silver' );
$program->fact( valuable => 'silver' );
is( $program->clauses_for( 'valuable', 1 ),
    3, '3 clauses exist before retract_all' );
my $ret_count = $program->retract_all( valuable => 'silver' );
is( $ret_count,                             2, 'retract_all silver removed 2' );
is( $program->clauses_for( 'valuable', 1 ), 1, '1 clause remains' );

done_testing;
