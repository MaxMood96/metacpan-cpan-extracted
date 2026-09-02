#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

# ==============================================================================
# BATTLESHIP AI VS. AI TOURNAMENT (DUAL RELATIONAL LOGIC BRAINS)
# Demonstrates using TWO completely independent, encapsulated Relational Logic
# packages (ParityAI vs. NaiveAI) playing a game against each other.
#
# Architecture:
# - Tournament Engine: Perl manages both secret 10x10 fleet grids, turn loop,
#   hit/miss detection, and side-by-side board rendering.
# - AI #1 Cognitive Brain (logic ParityAI):
#     - Uses Checkerboard Parity Search ((X + Y) % 2 == 0) in Hunt Mode.
#     - Uses Line Extension (horizontal & vertical) when 2+ hits occur.
# - AI #2 Cognitive Brain (logic NaiveAI):
#     - Uses Linear Row-by-Row Scanning in Hunt Mode.
#     - Uses Basic Adjacent Probing without line-extension awareness.
# ==============================================================================

# Private shot histories for guard validation
my %parity_shots_history;
my %naive_shots_history;

# ==============================================================================
# 1. AI #1 BRAIN: TACTICAL PARITY AI (logic ParityAI)
# ==============================================================================

logic ParityAI {
    # Dummy base rules so predicates are defined before facts are asserted
    rule shot_hit($x, $y)  { $x := 0; $y := 0; }
    rule shot_miss($x, $y) { $x := 0; $y := 0; }
    rule sunk_cell($x, $y) { $x := 0; $y := 0; }

    # Unshot Guard
    rule cell_unshot($x, $y) {
        guard([$x, $y], sub ($vx, $vy) {
            return 0 if $vx < 1 || $vx > 10 || $vy < 1 || $vy > 10;
            return $parity_shots_history{"$vx,$vy"} ? 0 : 1;
        });
    }

    rule cell_valid($x, $y) {
        between(1, 10, $x);
        between(1, 10, $y);
        cell_unshot($x, $y);
    }

    rule adjacent($x1, $y1, $x2, $y2) { $x2 is $x1 + 1; $y1 := $y2; }
    rule adjacent($x1, $y1, $x2, $y2) { $x2 is $x1 - 1; $y1 := $y2; }
    rule adjacent($x1, $y1, $x2, $y2) { $y2 is $y1 + 1; $x1 := $x2; }
    rule adjacent($x1, $y1, $x2, $y2) { $y2 is $y1 - 1; $x1 := $x2; }

    # Priority 1: Line Extension (Horizontal)
    rule select_target($x, $y, $mode) {
        fresh my ($x1, $x2, $yh);
        shot_hit($x1, $yh);
        $x2 is $x1 + 1;
        shot_hit($x2, $yh);
        $y := $yh;
        line_endpoint_h($x1, $x2, $x);
        cell_valid($x, $y);
        $mode := 'Line Extension (Horizontal)';
    }
    rule line_endpoint_h($x1, $x2, $x) { $x is $x2 + 1; }
    rule line_endpoint_h($x1, $x2, $x) { $x is $x1 - 1; }

    # Priority 1: Line Extension (Vertical)
    rule select_target($x, $y, $mode) {
        fresh my ($y1, $y2, $xh);
        shot_hit($xh, $y1);
        $y2 is $y1 + 1;
        shot_hit($xh, $y2);
        $x := $xh;
        line_endpoint_v($y1, $y2, $y);
        cell_valid($x, $y);
        $mode := 'Line Extension (Vertical)';
    }
    rule line_endpoint_v($y1, $y2, $y) { $y is $y2 + 1; }
    rule line_endpoint_v($y1, $y2, $y) { $y is $y1 - 1; }

    # Priority 2: Orthogonal Neighbor Probe
    rule select_target($x, $y, $mode) {
        fresh my ($hx, $hy);
        shot_hit($hx, $hy);
        adjacent($hx, $hy, $x, $y);
        cell_valid($x, $y);
        $mode := 'Orthogonal Target Probe';
    }

    # Priority 3: Checkerboard Parity Hunt
    rule select_target($x, $y, $mode) {
        between(1, 10, $x);
        between(1, 10, $y);
        cell_unshot($x, $y);
        guard([$x, $y], sub ($vx, $vy) { return ($vx + $vy) % 2 == 0; });
        $mode := 'Checkerboard Parity Hunt';
    }

    # Priority 4: Fallback Search
    rule select_target($x, $y, $mode) {
        between(1, 10, $x);
        between(1, 10, $y);
        cell_unshot($x, $y);
        $mode := 'Fallback Grid Search';
    }
}

# ==============================================================================
# 2. AI #2 BRAIN: NAIVE LINEAR AI (logic NaiveAI)
# ==============================================================================

logic NaiveAI {
    # Dummy base rules so predicates are defined before facts are asserted
    rule shot_hit($x, $y)  { $x := 0; $y := 0; }
    rule shot_miss($x, $y) { $x := 0; $y := 0; }
    rule sunk_cell($x, $y) { $x := 0; $y := 0; }

    # Unshot Guard
    rule cell_unshot($x, $y) {
        guard([$x, $y], sub ($vx, $vy) {
            return 0 if $vx < 1 || $vx > 10 || $vy < 1 || $vy > 10;
            return $naive_shots_history{"$vx,$vy"} ? 0 : 1;
        });
    }

    rule cell_valid($x, $y) {
        between(1, 10, $y);
        between(1, 10, $x);
        cell_unshot($x, $y);
    }

    rule adjacent($x1, $y1, $x2, $y2) { $x2 is $x1 + 1; $y1 := $y2; }
    rule adjacent($x1, $y1, $x2, $y2) { $x2 is $x1 - 1; $y1 := $y2; }
    rule adjacent($x1, $y1, $x2, $y2) { $y2 is $y1 + 1; $x1 := $x2; }
    rule adjacent($x1, $y1, $x2, $y2) { $y2 is $y1 - 1; $x1 := $x2; }

    # Priority 1: Basic Neighbor Probe (No Line Extension)
    rule select_target($x, $y, $mode) {
        fresh my ($hx, $hy);
        shot_hit($hx, $hy);
        adjacent($hx, $hy, $x, $y);
        cell_valid($x, $y);
        $mode := 'Basic Adjacent Probe';
    }

    # Priority 2: Linear Sequential Scan (Row by Row)
    rule select_target($x, $y, $mode) {
        between(1, 10, $y);
        between(1, 10, $x);
        cell_unshot($x, $y);
        $mode := 'Linear Sequential Scan';
    }
}

# ==============================================================================
# 3. PERL TOURNAMENT ENGINE (PHYSICAL WORLD & BOARD MANAGEMENT)
# ==============================================================================

my %ship_types = (
    Carrier    => 5,
    Battleship => 4,
    Cruiser    => 3,
    Submarine  => 3,
    Destroyer  => 2,
);

# Secret Grids
my %board1_grid;     # Defended by ParityAI
my %board1_shots;    # NaiveAI's shots against Board 1

my %board2_grid;     # Defended by NaiveAI
my %board2_shots;    # ParityAI's shots against Board 2

sub place_ship ( $grid, $type, $x, $y, $dir, $len ) {
    for my $i ( 0 .. $len - 1 ) {
        my $cx = $dir eq 'H' ? $x + $i : $x;
        my $cy = $dir eq 'V' ? $y + $i : $y;
        $grid->{"$cx,$cy"} = $type;
    }
    return;
}

sub setup_fleets () {

    # Board 1 (Parity AI's fleet)
    place_ship( \%board1_grid, 'Carrier',    1, 1, 'H', 5 );
    place_ship( \%board1_grid, 'Battleship', 3, 4, 'V', 4 );
    place_ship( \%board1_grid, 'Cruiser',    6, 2, 'V', 3 );
    place_ship( \%board1_grid, 'Submarine',  7, 7, 'H', 3 );
    place_ship( \%board1_grid, 'Destroyer',  2, 9, 'H', 2 );

    # Board 2 (Naive AI's fleet)
    place_ship( \%board2_grid, 'Carrier',    2, 2, 'H', 5 );
    place_ship( \%board2_grid, 'Battleship', 8, 4, 'V', 4 );
    place_ship( \%board2_grid, 'Cruiser',    1, 7, 'V', 3 );
    place_ship( \%board2_grid, 'Submarine',  4, 6, 'H', 3 );
    place_ship( \%board2_grid, 'Destroyer',  9, 1, 'H', 2 );
    return;
}

# Render Side-by-Side Boards
sub print_side_by_side_boards () {
    say
"\n   PARITY AI KNOWLEDGE BOARD      NAIVE AI KNOWLEDGE BOARD";
    say "     1 2 3 4 5 6 7 8 9 10           1 2 3 4 5 6 7 8 9 10";
    for my $y ( 1 .. 10 ) {
        my $l1 = sprintf( "%2d |", $y );
        for my $x ( 1 .. 10 ) {
            my $char = $board2_shots{"$x,$y"} // '.';
            $l1 .= " $char";
        }
        my $l2 = sprintf( "%2d |", $y );
        for my $x ( 1 .. 10 ) {
            my $char = $board1_shots{"$x,$y"} // '.';
            $l2 .= " $char";
        }
        say "$l1       $l2";
    }
    say "";
    return;
}

sub process_turn (
    $attacker_name, $ai_package, $program_obj, $history_href,
    $target_grid,   $shots_href, $stats_href
  )
{
    my $tx = Logic::Relational::variable('x');
    my $ty = Logic::Relational::variable('y');
    my $tm = Logic::Relational::variable('mode');

    # Query AI Logic Brain for next target
    my $q = $program_obj->query(
        Logic::Relational::Goal::Call->new(
            'select_target', [ $tx, $ty, $tm ]
        )
    );

    my $sol  = $q->next // return 0;
    my $x    = $sol->value($tx);
    my $y    = $sol->value($ty);
    my $mode = $sol->value($tm);

    $history_href->{"$x,$y"} = 1;
    $stats_href->{shots}++;

    my $hit_ship = $target_grid->{"$x,$y"};

    if ($hit_ship) {
        $shots_href->{"$x,$y"} = 'H';
        $stats_href->{hits}++;
        $program_obj->fact( shot_hit => $x, $y );

        # Check if ship is sunk
        my $len      = $ship_types{$hit_ship};
        my $sunk_cnt = 0;
        my @coords;
        for my $cy ( 1 .. 10 ) {
            for my $cx ( 1 .. 10 ) {
                if ( ( $target_grid->{"$cx,$cy"} // '' ) eq $hit_ship ) {
                    push @coords, [ $cx, $cy ];
                    $sunk_cnt++
                      if ( $shots_href->{"$cx,$cy"} // '' ) eq 'H';
                }
            }
        }

        if ( $sunk_cnt == $len ) {
            for my $c (@coords) {
                $shots_href->{"$c->[0],$c->[1]"} = 'S';
                $program_obj->retract( shot_hit => $c->[0], $c->[1] );
                $program_obj->fact( sunk_cell => $c->[0], $c->[1] );
            }
            $stats_href->{ships_sunk}++;
            say sprintf( "  [%-8s] Fires (%2d,%2d) -> SUNK %s! (%s)",
                $attacker_name, $x, $y, $hit_ship, $mode );
        }
        else {
            say sprintf( "  [%-8s] Fires (%2d,%2d) -> HIT %s! (%s)",
                $attacker_name, $x, $y, $hit_ship, $mode );
        }
    }
    else {
        $shots_href->{"$x,$y"} = 'M';
        $program_obj->fact( shot_miss => $x, $y );
        say sprintf( "  [%-8s] Fires (%2d,%2d) -> MISS (%s)",
            $attacker_name, $x, $y, $mode );
    }

    return 1;
}

sub run_tournament () {
    setup_fleets();

    say "=" x 70;
    say "    BATTLESHIP TOURNAMENT: PARITY AI vs. NAIVE LINEAR AI";
    say "=" x 70;
    say "Two encapsulated Relational Logic Brains facing off in real-time!";

    my $turn         = 0;
    my %parity_stats = ( shots => 0, hits => 0, ships_sunk => 0 );
    my %naive_stats  = ( shots => 0, hits => 0, ships_sunk => 0 );

    my $winner;

    while ( $turn < 100 ) {
        $turn++;
        say "\n=== TURN $turn ===";

        # 1. Parity AI Turn
        process_turn( 'ParityAI', 'ParityAI',
            $ParityAI::PROGRAM, \%parity_shots_history, \%board2_grid,
            \%board2_shots,     \%parity_stats );

        if ( $parity_stats{ships_sunk} == scalar keys %ship_types ) {
            $winner = 'ParityAI (Tactical Checkerboard Parity AI)';
            last;
        }

        # 2. Naive AI Turn
        process_turn( 'NaiveAI', 'NaiveAI',
            $NaiveAI::PROGRAM, \%naive_shots_history, \%board1_grid,
            \%board1_shots,    \%naive_stats );

        if ( $naive_stats{ships_sunk} == scalar keys %ship_types ) {
            $winner = 'NaiveAI (Linear Sequential AI)';
            last;
        }
    }

    print_side_by_side_boards();

    say "=" x 70;
    say "                  TOURNAMENT RESULTS & STATS";
    say "=" x 70;
    say "WINNER          : $winner";
    say "Total Turns     : $turn";
    say sprintf(
        "ParityAI Stats  : %d shots, %d hits (%.1f%% accuracy), %d ships sunk",
        $parity_stats{shots}, $parity_stats{hits},
        ( $parity_stats{hits} / $parity_stats{shots} ) * 100,
        $parity_stats{ships_sunk}
    );
    say sprintf(
        "NaiveAI Stats   : %d shots, %d hits (%.1f%% accuracy), %d ships sunk",
        $naive_stats{shots}, $naive_stats{hits},
        ( $naive_stats{hits} / $naive_stats{shots} ) * 100,
        $naive_stats{ships_sunk}
    );
    say "=" x 70;
    return;
}

run_tournament();
say "";

