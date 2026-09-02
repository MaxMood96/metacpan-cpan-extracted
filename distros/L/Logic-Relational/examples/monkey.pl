#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;
use Logic::Relational::DSL qw(term);

# Declare the classic Monkey and Banana program using logic syntax
logic Monkey {
    # State representation: state(MonkeyPos, BoxPos, OnBoxOrFloor, HasBanana)

    # Action 1: Grasp banana when monkey and box are at middle and monkey is on box
    fact perform(
        'grasp',
        term( state => 'middle', 'middle', 'onbox', 'hasnot' ),
        term( state => 'middle', 'middle', 'onbox', 'has' )
    );

    # Action 2: Climb onto box when monkey and box are at same position on floor
    rule perform(
        'climb',
        term( state => $mp, $bp, 'onfloor', $h ),
        term( state => $mp, $bp, 'onbox',   $h )
    ) {
        true_goal;
    }

    # Action 3: Push box from P1 to P2 when monkey and box are at P1 on floor
    rule perform(
        term( push => $p1, $p2 ),
        term( state => $p1, $p1, 'onfloor', $h ),
        term( state => $p2, $p2, 'onfloor', $h )
    ) {
        true_goal;
    }

    # Action 4: Walk from P1 to P2 when monkey is on floor
    rule perform(
        term( walk => $p1, $p2 ),
        term( state => $p1, $bp, 'onfloor', $h ),
        term( state => $p2, $bp, 'onfloor', $h )
    ) {
        true_goal;
    }

    # Base Case: Goal state reached (monkey has banana); remaining plan sequence is []
    rule getfood( term( state => $a1, $a2, $a3, 'has' ), [] ) {
        true_goal;
    }

    # Recursive Step: Perform action $act transitioning $s1 -> $s2, accumulating $act into plan list [$act, rest($rest_plan)]
    rule getfood( $s1, [$act, rest($rest_plan)] ) {
        fresh my $s2;
        perform( $act, $s1, $s2 );
        getfood( $s2, $rest_plan );
    }
}

say "Solving Monkey and Banana problem using declarative plan accumulation...";
my $start_state = term( state => 'atdoor', 'atwindow', 'onfloor', 'hasnot' );

# Run query for state and plan sequence
query Monkey::getfood( $start_state, fresh my $plan ) -> my $q;

if ( my $sol = $q->next ) {
    say "\nSuccess: Monkey retrieved the banana!";
    say "Plan sequence:";
    my $steps = $sol->value($plan);
    for my $i ( 0 .. $#$steps ) {
        my $act     = $steps->[$i];
        my $act_str = ref($act) ? $act->as_string : $act;
        printf "  Step %d: %s\n", $i + 1, $act_str;
    }
}
else {
    say "\nFailure: No solution found.";
}

