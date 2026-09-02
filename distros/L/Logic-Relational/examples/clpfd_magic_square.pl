#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

# 3x3 Magic Square solver using declarative CLP(FD) arithmetic constraints (#=)
logic MagicCLPFD {

    rule solve($square) {

        # Declare cells and constrain their integer domain to 1..9
        fresh my ( $m11, $m12, $m13, $m21, $m22, $m23, $m31, $m32, $m33 ) in 1..9;

        # Output square structure
        $square := [ $m11, $m12, $m13, $m21, $m22, $m23, $m31, $m32, $m33 ];

        # Constraint 1: All cells must be distinct
        all_different( $m11, $m12, $m13, $m21, $m22, $m23, $m31, $m32, $m33 );

        # Constraint 2: Declarative CLP(FD) row sum constraints (#=)
        $m11 + $m12 + $m13 #= 15;
        $m21 + $m22 + $m23 #= 15;
        $m31 + $m32 + $m33 #= 15;

        # Constraint 3: Declarative CLP(FD) column sum constraints (#=)
        $m11 + $m21 + $m31 #= 15;
        $m12 + $m22 + $m32 #= 15;
        $m13 + $m23 + $m33 #= 15;

        # Constraint 4: Declarative CLP(FD) diagonal sum constraints (#=)
        $m11 + $m22 + $m33 #= 15;
        $m31 + $m22 + $m13 #= 15;

        # Trigger backtracking search labeling
        label( $m11, $m12, $m13, $m21, $m22, $m23, $m31, $m32, $m33 );
    }
}

# Run logic query
query MagicCLPFD::solve( fresh my $sol )->my $q;


my $count = 0;
while ( my $s = $q->next ) {
    $count++;
    my $p = $s->value($sol);
    say "Solution #$count:\n";
    say "+---+---+---+";
    say "| $p->[0] | $p->[1] | $p->[2] |";
    say "+---+---+---+";
    say "| $p->[3] | $p->[4] | $p->[5] |";
    say "+---+---+---+";
    say "| $p->[6] | $p->[7] | $p->[8] |";
    say "+---+---+---+\n";
}

