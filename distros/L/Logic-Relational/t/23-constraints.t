#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0 '!call';
no warnings 'redefine';
no warnings 'prototype';
use Logic::Relational      qw(variable call all guard);
use Logic::Relational::DSL qw(in_domain all_different label);
use Logic::Relational::Program;

# 1. Test Domain Object directly
use Logic::Relational::Domain;
my $d1 = Logic::Relational::Domain->new( { min => 1, max => 5 } );
is( $d1->size,       5,                 'Domain range size is 5' );
is( [ $d1->values ], [ 1, 2, 3, 4, 5 ], 'Domain values are 1..5' );
ok( $d1->contains(3),  'Domain contains 3' );
ok( !$d1->contains(6), 'Domain does not contain 6' );

my $d2 = Logic::Relational::Domain->new( { values => [ 3, 4, 6 ] } );
my $d3 = $d1->intersect($d2);
is( [ $d3->values ], [ 3, 4 ], 'Intersection is [3, 4]' );
ok( !$d3->is_bound, 'Not yet bound' );

my $d4 = $d3->intersect(3);
ok( $d4->is_bound, 'Is bound now' );
is( $d4->bound_value, 3, 'Bound value is 3' );

# 2. Test in_domain constraint and unification
my $p = Logic::Relational::Program->new;
my $x = variable('X');
my $y = variable('Y');

my $q = $p->query(
    all(
        in_domain( $x, 1, 3 ),
        in_domain( $y, 2, 4 ),
        Logic::Relational::Goal::Unify->new( $x, $y ),
        label( [ $x, $y ] )
    )
);

my @sols;
while ( my $sol = $q->next ) {
    push @sols, [ $sol->value($x), $sol->value($y) ];
}
is(
    \@sols,
    [ [ 2, 2 ], [ 3, 3 ] ],
    'Domain variables unified and labeled correctly'
);

# 3. Test all_different constraint
my $q_diff = $p->query(
    all(
        in_domain( $x, 1, 2 ),
        in_domain( $y, 1, 2 ),
        all_different( $x, $y ),
        label( [ $x, $y ] )
    )
);

my @sols_diff;
while ( my $sol = $q_diff->next ) {
    push @sols_diff, [ $sol->value($x), $sol->value($y) ];
}
is( \@sols_diff, [ [ 1, 2 ], [ 2, 1 ] ], 'all_different prunes duplicates' );

# 4. Solve 4-Queens using constraints + guards
# Variables Q1, Q2, Q3, Q4 represent rows 1..4.
# Columns must be distinct.
my $q1 = variable('Q1');
my $q2 = variable('Q2');
my $q3 = variable('Q3');
my $q4 = variable('Q4');

my $q_queens = $p->query(
    all(
        in_domain( $q1, 1, 4 ),
        in_domain( $q2, 1, 4 ),
        in_domain( $q3, 1, 4 ),
        in_domain( $q4, 1, 4 ),
        all_different( $q1, $q2, $q3, $q4 ),
        label( [ $q1, $q2, $q3, $q4 ] ),

        # Diagonal constraints (guards run when variables are bound)
        guard( [ $q1, $q2 ], sub ( $a, $b ) { return abs( $a - $b ) != 1 } ),
        guard( [ $q1, $q3 ], sub ( $a, $b ) { return abs( $a - $b ) != 2 } ),
        guard( [ $q1, $q4 ], sub ( $a, $b ) { return abs( $a - $b ) != 3 } ),
        guard( [ $q2, $q3 ], sub ( $a, $b ) { return abs( $a - $b ) != 1 } ),
        guard( [ $q2, $q4 ], sub ( $a, $b ) { return abs( $a - $b ) != 2 } ),
        guard( [ $q3, $q4 ], sub ( $a, $b ) { return abs( $a - $b ) != 1 } )
    )
);

my @queens_sols;
while ( my $sol = $q_queens->next ) {
    push @queens_sols,
      [
        $sol->value($q1), $sol->value($q2),
        $sol->value($q3), $sol->value($q4),
      ];
}
is(
    \@queens_sols,
    [ [ 2, 4, 1, 3 ], [ 3, 1, 4, 2 ] ],
    '4-Queens solved successfully'
);

done_testing;
