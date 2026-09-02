#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

# Define Cryptarithmetic logic package
logic Cryptarithmetic {
    # LOGIC + LOGIC = PROLOG
    rule solve_logic_prolog($L, $O, $G, $I, $C, $P, $R) {
        fresh my ($l, $o, $g, $i, $c, $p, $r) in 0..9;

        $l #/= 0;
        $p #/= 0;

        all_different($l, $o, $g, $i, $c, $p, $r);

        2 * ($l * 10000 + $o * 1000 + $g * 100 + $i * 10 + $c) #=
            $p * 100000 + $r * 10000 + $o * 1000 + $l * 100 + $o * 10 + $g;

        label($p, $l, $o, $g, $i, $c, $r);

        $L := $l;
        $O := $o;
        $G := $g;
        $I := $i;
        $C := $c;
        $P := $p;
        $R := $r;
    }

    # SEND + MORE = MONEY
    rule solve_send_more_money($S, $E, $N, $D, $M, $O, $R, $Y) {
        fresh my ($s, $e, $n, $d, $m, $o, $r, $y) in 0..9;

        $s #/= 0;
        $m #/= 0;

        all_different($s, $e, $n, $d, $m, $o, $r, $y);

        ($s * 1000 + $e * 100 + $n * 10 + $d) +
        ($m * 1000 + $o * 100 + $r * 10 + $e) #=
        ($m * 10000 + $o * 1000 + $n * 100 + $e * 10 + $y);

        label($m, $s, $o, $e, $n, $r, $d, $y);

        $S := $s; $E := $e; $N := $n; $D := $d;
        $M := $m; $O := $o; $R := $r; $Y := $y;
    }
}

say "=" x 55;
say "   CRYPTARITHMETIC PUZZLE SOLVER (CLP(FD) ENGINE)";
say "=" x 55;

# 1. Solve LOGIC + LOGIC = PROLOG
say "\n--- Solving: LOGIC + LOGIC = PROLOG ---";
query Cryptarithmetic::solve_logic_prolog(
    fresh my $L,
    fresh my $O,
    fresh my $G,
    fresh my $I,
    fresh my $C,
    fresh my $P,
    fresh my $R
)->my $q1;

if ( my $sol = $q1->next ) {
    my ( $l, $o, $g, $i, $c, $p, $r ) = (
        $sol->value($L), $sol->value($O), $sol->value($G), $sol->value($I),
        $sol->value($C), $sol->value($P), $sol->value($R)
    );
    my $logic  = $l * 10000 + $o * 1000 + $g * 100 + $i * 10 + $c;
    my $prolog = $p * 100000 + $r * 10000 + $o * 1000 + $l * 100 + $o * 10 + $g;

    say "  L=$l, O=$o, G=$g, I=$i, C=$c, P=$p, R=$r";
    say "  LOGIC  = $logic";
    say "  PROLOG = $prolog";
    say "  Check: $logic + $logic = ", $logic + $logic, " (Matches PROLOG: ",
      ( $logic * 2 == $prolog ? "YES" : "NO" ), ")";
}

# 2. Solve SEND + MORE = MONEY
say "\n--- Solving: SEND + MORE = MONEY ---";
query Cryptarithmetic::solve_send_more_money(
    fresh my $S,
    fresh my $E,
    fresh my $N,
    fresh my $D,
    fresh my $M,
    fresh my $O2,
    fresh my $R2,
    fresh my $Y
)->my $q2;

if ( my $sol = $q2->next ) {
    my ( $s, $e, $n, $d, $m, $o, $r, $y ) = (
        $sol->value($S),  $sol->value($E),
        $sol->value($N),  $sol->value($D),
        $sol->value($M),  $sol->value($O2),
        $sol->value($R2), $sol->value($Y)
    );
    my $send  = $s * 1000 + $e * 100 + $n * 10 + $d;
    my $more  = $m * 1000 + $o * 100 + $r * 10 + $e;
    my $money = $m * 10000 + $o * 1000 + $n * 100 + $e * 10 + $y;

    say "  S=$s, E=$e, N=$n, D=$d, M=$m, O=$o, R=$r, Y=$y";
    say "  SEND  = $send";
    say "  MORE  = $more";
    say "  MONEY = $money";
    say "  Check: $send + $more = ", $send + $more, " (Matches MONEY: ",
      ( $send + $more == $money ? "YES" : "NO" ), ")";
}
say "";

