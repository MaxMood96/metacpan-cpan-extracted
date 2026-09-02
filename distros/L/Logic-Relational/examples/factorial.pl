#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

# Define Math program using declarative logic syntax
logic Math {
    # Base case: 0! = 1
    rule factorial(0, 1) {
        true_goal;
    }

    # Recursive case: N! = N * (N - 1)!
    rule factorial($n, $f) {
        fresh my $n1;
        fresh my $f1;

        # Evaluate N - 1 and bind to N1
        $n1 is $n - 1;

        # Recursively compute N1! into F1
        factorial($n1, $f1);

        # Evaluate N * F1 and bind to F
        $f is $n * $f1;
    }
}

say
  "=== Calculating Factorials using Relational Logic & Arithmetic Binding ===";

for my $num ( 0 .. 10 ) {
    query Math::factorial( $num, fresh my $result )->my $q;
    if ( my $sol = $q->next ) {
        say sprintf( "%d! = %d", $num, $sol->value($result) );
    }
}

