use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Program;
use Logic::Relational::Goal::True;
use Logic::Relational::Goal::Fail;
use Logic::Relational::Goal::Unify;
use Logic::Relational::Goal::All;
use Logic::Relational::Goal::Any;
use Logic::Relational::Variable;

my $program = Logic::Relational::Program->new;
my $x       = Logic::Relational::Variable->new( name => 'X' );

# 1. True goal
my $q1   = $program->query( Logic::Relational::Goal::True->new );
my $sol1 = $q1->next;
ok( $sol1,      'True goal succeeds' );
ok( !$q1->next, 'Only one solution' );

# 2. Fail goal
my $q2 = $program->query( Logic::Relational::Goal::Fail->new );
ok( !$q2->next, 'Fail goal fails' );

# 3. Unify goal
my $q3   = $program->query( Logic::Relational::Goal::Unify->new( $x, 42 ) );
my $sol3 = $q3->next;
ok( $sol3, 'Unify goal succeeds' );
is( $sol3->value($x), 42, 'Unify goal binds variable' );

# 4. All (conjunction)
my $y   = Logic::Relational::Variable->new( name => 'Y' );
my $all = Logic::Relational::Goal::All->new(
    [
        Logic::Relational::Goal::Unify->new( $x, 1 ),
        Logic::Relational::Goal::Unify->new( $y, 2 ),
    ]
);
my $q4   = $program->query($all);
my $sol4 = $q4->next;
ok( $sol4, 'All goal succeeds' );
is( $sol4->value($x), 1, 'All: X = 1' );
is( $sol4->value($y), 2, 'All: Y = 2' );

# 5. Any (disjunction)
my $any = Logic::Relational::Goal::Any->new(
    [
        Logic::Relational::Goal::Unify->new( $x, 'red' ),
        Logic::Relational::Goal::Unify->new( $x, 'green' ),
    ]
);
my $q5    = $program->query($any);
my $sol5a = $q5->next;
is( $sol5a->value($x), 'red', 'Any: first choice is red' );
my $sol5b = $q5->next;
is( $sol5b->value($x), 'green', 'Any: second choice is green' );
ok( !$q5->next, 'Any: no more choices' );

done_testing;
