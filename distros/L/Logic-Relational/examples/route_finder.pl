#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

# ==============================================================================
# LOGISTICS & MULTIMODAL ROUTE FINDER
# ==============================================================================

logic Logistics {
    # Bidirectional route link helper
    rule edge($from, $to, $cost, $time, $mode) {
        link($from, $to, $cost, $time, $mode);
    }
    rule edge($from, $to, $cost, $time, $mode) {
        link($to, $from, $cost, $time, $mode);
    }

    # Base case: Direct 1-hop connection
    rule find_route($from, $to, $visited, $total_cost, $total_time, $path) {
        fresh my ($c, $t, $m);
        edge($from, $to, $c, $t, $m);
        $total_cost := $c;
        $total_time := $t;
        $path := [$from, $to];
    }

    # Recursive case: Multi-hop path finding
    rule find_route($from, $to, $visited, $total_cost, $total_time, $path) {
        fresh my ($mid, $c1, $t1, $m1, $rest_cost, $rest_time, $sub_path, $next_visited);
        edge($from, $mid, $c1, $t1, $m1);
        $mid !:= $to;
        not_member($mid, $visited);

        $next_visited := [$mid, rest($visited)];
        find_route($mid, $to, $next_visited, $rest_cost, $rest_time, $sub_path);

        $total_cost is $c1 + $rest_cost;
        $total_time is $t1 + $rest_time;
        $path := [$from, rest($sub_path)];
    }
}

# 1. Perl Data Input: Transport Network Data Structure
my @network_data = (
    {
        from => 'London',
        to   => 'Paris',
        cost => 120,
        time => 2,
        mode => 'flight'
    },
    { from => 'London', to => 'Paris', cost => 80, time => 3, mode => 'train' },
    {
        from => 'London',
        to   => 'Amsterdam',
        cost => 70,
        time => 1,
        mode => 'flight'
    },
    {
        from => 'Paris',
        to   => 'Berlin',
        cost => 150,
        time => 4,
        mode => 'train'
    },
    { from => 'Paris', to => 'Rome', cost => 180, time => 2, mode => 'flight' },
    {
        from => 'Amsterdam',
        to   => 'Berlin',
        cost => 100,
        time => 6,
        mode => 'train'
    },
    {
        from => 'Berlin',
        to   => 'Vienna',
        cost => 90,
        time => 3,
        mode => 'train'
    },
    {
        from => 'Rome',
        to   => 'Vienna',
        cost => 110,
        time => 2,
        mode => 'flight'
    },
    {
        from => 'Vienna',
        to   => 'Budapest',
        cost => 40,
        time => 2,
        mode => 'train'
    },
);

# 2. Populate Logic Engine Facts from Perl Data Structure
for my $l (@network_data) {
    $Logistics::PROGRAM->fact(
        link => $l->{from},
        $l->{to}, $l->{cost}, $l->{time}, $l->{mode}
    );
}

say "=" x 60;
say "   LOGISTICS & MULTIMODAL ROUTE FINDER (RELATIONAL ENGINE)";
say "=" x 60;

# Demo 1: All routes between London and Vienna
say "\n--- 1. All Routes from London to Vienna ---";
query Logistics::find_route(
    'London', 'Vienna', ['London'],
    fresh my $cost1,
    fresh my $time1,
    fresh my $path1
)->my $q1;

my @all_routes;
while ( my $sol = $q1->next ) {
    my $p = $sol->value($path1);
    my $c = $sol->value($cost1);
    my $t = $sol->value($time1);
    push @all_routes, { path => $p, cost => $c, time => $t };
    say sprintf(
        "  Route #%d: %-42s (Cost: \$%3d, Time: %2dh)",
        scalar(@all_routes), join( " -> ", @$p ),
        $c,                  $t
    );
}

# Demo 2: Budget & Time Filtered Routes (Cost <= $380 AND Time <= 8h)
say "\n--- 2. Budget & Express Routes (Cost <= \$380 AND Time <= 8h) ---";
my @express_routes = grep { $_->{cost} <= 380 && $_->{time} <= 8 } @all_routes;
for my $r (@express_routes) {
    say sprintf(
        "  MATCH: %-42s (Cost: \$%3d, Time: %2dh)",
        join( " -> ", @{ $r->{path} } ),
        $r->{cost}, $r->{time}
    );
}

# Demo 3: Cheapest vs Fastest Route Analysis
say "\n--- 3. Route Optimization Summary ---";
my ($cheapest) = sort { $a->{cost} <=> $b->{cost} } @all_routes;
my ($fastest)  = sort { $a->{time} <=> $b->{time} } @all_routes;

say "  CHEAPEST: "
  . join( " -> ", @{ $cheapest->{path} } )
  . " (\$$cheapest->{cost}, $cheapest->{time}h)";
say "  FASTEST : "
  . join( " -> ", @{ $fastest->{path} } )
  . " (\$$fastest->{cost}, $fastest->{time}h)";
say "";

