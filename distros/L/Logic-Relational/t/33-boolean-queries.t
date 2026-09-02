#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Syntax;

logic PrincesOfWalesTest {
    facts {
        reigns('Rhodri', 844, 878);
        reigns('Cadwallon', 985, 986);
    }

    rule prince($x, $y) {
        fresh my ($u, $v);
        reigns($x, $u, $v);
        $y >= $u;
        $y <= $v;
    }
}

# 1. Test boolean query object in if statement
query PrincesOfWalesTest::prince('Cadwallon', 986) -> my $q1;
ok( !!$q1, "prince('Cadwallon', 986) evaluates to true in boolean context" );

query PrincesOfWalesTest::prince('Rhodri', 1977) -> my $q2;
ok( !$q2, "prince('Rhodri', 1979) evaluates to false in boolean context" );

# 2. Test ->is_true method
query PrincesOfWalesTest::prince('Cadwallon', 986) -> my $q3;
is( $q3->is_true, 1, "is_true returns 1 for valid ground query" );

query PrincesOfWalesTest::prince('Rhodri', 1977) -> my $q4;
is( $q4->is_true, 0, "is_true returns 0 for invalid ground query" );

done_testing;
