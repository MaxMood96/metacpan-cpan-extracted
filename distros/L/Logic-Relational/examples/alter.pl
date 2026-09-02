#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

# ==============================================================================
# ALTER DEMO (SENTENCE TRANSFORMER)
# Based on the example in Clocksin & Mellish "Programming in Prolog"
# Demonstrates integrating Perl 'guard' closures to handle both scalar and
# array word replacements dynamically.
# ==============================================================================

logic AlterDemo {

    # Ground word-mapping facts (both scalar words and array replacements)
    facts {
        change( 'you',    'I' );
        change( 'You',    'I' );
        change( 'are',    [ 'am', 'not' ] );
        change( 'French', 'German' );
        change( 'Do',     'No' );
    }

	# Catch-all rule: if a word has no explicit change mapping, keep it unchanged
    rule change( $x, $x ) { }

    # Base case termination for recursion
    fact alter( [], [] );

	# Case 1: Replacement is a multi-word list (e.g., 'are' -> ['am', 'not'])
	# Uses Perl 'guard' to inspect the runtime reference type of the reified term
    rule alter( [ $h, rest($t) ], $out ) {
        fresh my ( $cx, $rest_out );
        change( $h, $cx );
        guard( [$cx], sub ($v) { ref($v) eq 'ARRAY' } );
        alter( $t, $rest_out );
        append( $cx, $rest_out, $out );
    }

    # Case 2: Replacement is a single scalar word (e.g., 'You' -> 'I')
    # Uses Perl 'guard' to ensure the reified term is a plain scalar
    rule alter( [ $h, rest($t) ], [ $x, rest($y) ] ) {
        change( $h, $x );
        guard( [$x], sub ($v) { !ref($v) } );
        alter( $t, $y );
    }

}

say "=== 1. FORWARD TRANSLATION WITH MULTI-WORD GUARD ===";
say "Input : ['You', 'are', 'a', 'computer']";
query AlterDemo::alter( [ 'You', 'are', 'a', 'computer' ], fresh my $out1 )->my $q1;
my $val1 = $q1->value($out1);
say "Output: [", join( ", ", map { "'$_'" } @$val1 ), "]";

# Output: ['I', 'am', 'not', 'a', 'computer']

say "\n=== 2. FORWARD TRANSLATION WITH SCALAR GUARD ===";
say "Input : ['You', 'know', 'French']";
query AlterDemo::alter( [ 'You', 'know', 'French' ], fresh my $out2 )->my $q2;
my $val2 = $q2->value($out2);
say "Output: [", join( ", ", map { "'$_'" } @$val2 ), "]";

# Output: ['I', 'know', 'German']

