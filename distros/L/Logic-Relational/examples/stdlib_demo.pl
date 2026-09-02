#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

logic Demo {
    # Custom rule using non-unifiability operator (!:=)
    rule distinct_items($x, $y) {
        $x !:= $y;
    }
}

say "=== 1. Standard Relational List Predicates ===";

# Reverse a list
query Demo::reverse( [ 'alpha', 'beta', 'gamma' ], fresh my $rev )->my $q1;
if ( my $s1 = $q1->next ) {
    say "reverse(['alpha', 'beta', 'gamma']) = ["
      . join( ", ", @{ $s1->value($rev) } ) . "]";
}

# Permutations of a list
say "\nPermutations of [1, 2, 3]:";
query Demo::permutation( [ 1, 2, 3 ], fresh my $perm )->my $q2;
my $p_count = 0;
while ( my $s2 = $q2->next ) {
    $p_count++;
    say "  #$p_count: [" . join( ", ", @{ $s2->value($perm) } ) . "]";
}

say "\n=== 2. Term Comparison Operators ===";

query Demo::distinct_items( 'apple', 'banana' )->my $q3;
say "'apple' vs 'banana': " . ( $q3->next ? "PASS (distinct)" : "FAIL" );

query Demo::distinct_items( 'apple', 'apple' )->my $q4;
say "'apple' vs 'apple': " . ( $q4->next ? "FAIL" : "PASS (not distinct)" );

say "\n=== 3. Backtracking Range Generators (between/3) ===";

say "Numbers between 10 and 15:";
query Demo::between( 10, 15, fresh my $num )->my $q5;
while ( my $s5 = $q5->next ) {
    say "  Value: " . $s5->value($num);
}

