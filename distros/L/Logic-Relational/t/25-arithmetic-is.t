#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Syntax;
use Logic::Relational::DSL qw(variable is_goal);
require Logic::Relational::Program;

# 1. Direct API test
my $a = variable('A');
my $b = variable('B');

# Bind A to 10
my $p1 = Logic::Relational::Program->new;
$p1->fact( val => 10 );

my $query1 = $p1->query(
    Logic::Relational::Goal::All->new( [
            Logic::Relational::Goal::Call->new( 'val', [$a] ),
            is_goal( $b, [$a], sub ($val) { return $val * 2 + 5 } )
        ] )
);

my $sol1 = $query1->next;
ok( $sol1, 'Query with is_goal succeeded' );
is( $sol1->value($b), 25, 'is_goal calculated 10 * 2 + 5 = 25 correctly' );

# 2. Custom syntax test: Math program with factorial recursion
logic MathMath {
    fact val(5);

    rule factorial(0, 1) {
        true_goal;
    }

    rule factorial($n, $f) {
        fresh my $n1;
        fresh my $f1;

        $n1 is $n - 1;
        factorial($n1, $f1);
        $f is $n * $f1;
    }
}

query MathMath::factorial( 5, fresh my $fact5 ) -> my $q2;
my $sol2 = $q2->next;
ok( $sol2, 'Factorial query succeeded' );
is( $sol2->value($fact5), 120, '5! calculated correctly as 120' );

query MathMath::factorial( 6, fresh my $fact6 ) -> my $q3;
my $sol3 = $q3->next;
ok( $sol3, 'Factorial 6 query succeeded' );
is( $sol3->value($fact6), 720, '6! calculated correctly as 720' );

# 3. Unbound variable error check
# Calling is_goal on unbound variable should croak
my $unbound_var = variable('unbound');
my $res_var     = variable('res');
my $bad_query   = $p1->query(
    is_goal( $res_var, [$unbound_var], sub ($v) { return $v + 1 } )
);

like(
    dies { $bad_query->next },
    qr/Arithmetic evaluation 'is' attempted to read unbound logical variable \$unbound/,
    'Croaks with clear message when reading unbound variable'
);

done_testing;
