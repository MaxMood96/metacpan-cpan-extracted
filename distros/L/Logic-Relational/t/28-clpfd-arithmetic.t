#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Syntax;

# 1. Test #= equality constraint with domain propagation
logic EqFDTest {
    rule solve( $x, $y ) {
        fresh my ($a, $b) in 1..10;
        $a + 5 #= 12;
        $b #= $a + 2;
        $x := $a;
        $y := $b;
        label($a, $b);
    }
}

query EqFDTest::solve( fresh my $res1, fresh my $res2 )->my $q1;

my $sol1 = $q1->next;
ok( $sol1, '#= equality query succeeded' );
is( $sol1->value($res1), 7, '$a + 5 #= 12 derived $a = 7' );
is( $sol1->value($res2), 9, '$b #= $a + 2 derived $b = 9' );

# 2. Test #< and #> inequality constraints
logic CompareFDTest {
    rule solve( $x, $y ) {
        fresh my ($a, $b) in 1..3;
        $a #< $b;
        $x := $a;
        $y := $b;
        label($a, $b);
    }
}

query CompareFDTest::solve( fresh my $val1, fresh my $val2 )->my $q2;

my @comp_sols;
while ( my $sol = $q2->next ) {
    push @comp_sols, [ $sol->value($val1), $sol->value($val2) ];
}
is( \@comp_sols, [ [ 1, 2 ], [ 1, 3 ], [ 2, 3 ] ], '#< correctly pruned non-less pairs' );

# 3. Test #/= disequality constraint
logic NeFDTest {
    rule solve( $x, $y ) {
        fresh my ($a, $b) in 1..2;
        $a #/= $b;
        $x := $a;
        $y := $b;
        label($a, $b);
    }
}

query NeFDTest::solve( fresh my $n1, fresh my $n2 )->my $q3;

my @ne_sols;
while ( my $sol = $q3->next ) {
    push @ne_sols, [ $sol->value($n1), $sol->value($n2) ];
}
is( \@ne_sols, [ [ 1, 2 ], [ 2, 1 ] ], '#/= disequality pruned equal pairs' );

# 4. Test multi-variable sum constraint $a + $b + $c #= 6
logic SumFDTest {
    rule solve( $x, $y, $z ) {
        fresh my ($a, $b, $c) in 1..3;
        all_different($a, $b, $c);
        $a + $b + $c #= 6;
        $x := $a;
        $y := $b;
        $z := $c;
        label($a, $b, $c);
    }
}

query SumFDTest::solve( fresh my $s1, fresh my $s2, fresh my $s3 )->my $q4;

my @sum_sols;
while ( my $sol = $q4->next ) {
    push @sum_sols, [ $sol->value($s1), $sol->value($s2), $sol->value($s3) ];
}
is( scalar @sum_sols, 6, 'Sum constraint $a + $b + $c #= 6 produced 6 permutations' );

# 5. Test standard comparison operators >= and <= without # prefix
logic BareCompareFDTest {
    rule prince($x, $y) {
        fresh my ($u, $v);
        reigns($x, $u, $v);
        $y >= $u;
        $y <= $v;
    }
    rule reigns($name, $start, $end) {
        $name  := 'Cadwallon';
        $start := 985;
        $end   := 986;
    }
}

query BareCompareFDTest::prince(fresh my $pname, 986)->my $q5;

my $sol5 = $q5->next;
ok( $sol5, 'Bare >= and <= comparison query succeeded' );
is( $sol5->value($pname), 'Cadwallon', 'Cadwallon found using bare >= and <= operators' );

done_testing;
