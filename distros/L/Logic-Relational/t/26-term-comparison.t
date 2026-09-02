#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Syntax;
use Logic::Relational::DSL qw(variable identical unify);
require Logic::Relational::Program;

# 1. Direct API tests
my $x = variable('X');
my $y = variable('Y');

my $p1     = Logic::Relational::Program->new;
my $query1 = $p1->query( identical( $x, $x ) );
ok( $query1->next, 'x == x (same variable instance) succeeds' );

my $query2 = $p1->query( identical( $x, $y ) );
ok( !$query2->next, 'x == y (distinct unbound variables) fails' );

# Verify identical did not bind x and y
my $query3 = $p1->query(
    Logic::Relational::Goal::All->new(
        [ identical( $x, $y ), unify( $x, 'apple' ) ]
    )
);
my $sol3 = $query3->next;
ok( !$sol3, 'identical does not bind variables' );

# 2. Syntax Layer tests
logic CompTest {
    rule check_identity($a, $b) {
        $a == $b;
    }

    rule check_not_unifiable($a, $b) {
        $a !:= $b;
    }
}

query CompTest::check_identity( 5, 5 )->my $q4;
ok( $q4->next, '5 == 5 in syntax succeeds' );

query CompTest::check_identity( 5, 10 )->my $q5;
ok( !$q5->next, '5 == 10 in syntax fails' );

query CompTest::check_not_unifiable( 'apple', 'banana' )->my $q10;
ok( $q10->next, "'apple' !:= 'banana' in syntax succeeds" );

query CompTest::check_not_unifiable( 'apple', 'apple' )->my $q11;
ok( !$q11->next, "'apple' !:= 'apple' in syntax fails" );

done_testing;
