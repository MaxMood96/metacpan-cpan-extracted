#!perl
# The service map layout, and the flamegraph's self-time tree.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $M = 'Punk::Observe::Map';
my $F = 'Punk::Observe::Flame';
sub layout { $M->can('layout')->($_[0]) }
sub flame  { $F->can('build')->($_[0]) }

sub node_of { my ($r, $s) = @_;
              my ($n) = grep { "$_->{service}" eq "$s" } @{ $r->{nodes} }; return $n }

use constant { GATEWAY => 1, CHECKOUT => 2, DB => 3, CACHE => 4 };

# --- layering ---------------------------------------------------------------

{
    my $r = layout([
        { caller => '*',      callee => GATEWAY,  count => 100 },
        { caller => GATEWAY,  callee => CHECKOUT, count => 100 },
        { caller => CHECKOUT, callee => DB,       count => 90 },
    ]);
    is($r->{layers}, 4, 'a three-hop chain lays out in four layers');
    is(node_of($r, '*')->{layer}, 0,       'the synthetic root is layer 0');
    is(node_of($r, GATEWAY)->{layer}, 1,   'the gateway is layer 1');
    is(node_of($r, CHECKOUT)->{layer}, 2,  'checkout is layer 2');
    is(node_of($r, DB)->{layer}, 3,        'the database is layer 3');
    is($r->{back_edges}, 0, 'and there are no back edges');
}

{
    # A fan-out: both callees share a layer.
    my $r = layout([
        { caller => '*',     callee => GATEWAY,  count => 10 },
        { caller => GATEWAY, callee => CHECKOUT, count => 10 },
        { caller => GATEWAY, callee => DB,       count => 10 },
        { caller => GATEWAY, callee => CACHE,    count => 10 },
    ]);
    is(node_of($r, CHECKOUT)->{layer}, 2, 'a fan-out puts callees on one layer');
    is(node_of($r, DB)->{layer}, 2, '  all of them');
    is(node_of($r, CACHE)->{layer}, 2, '  every one');
}

{
    # A diamond: the join takes the LONGEST path, not the shortest, or the
    # edge into it would point backwards on the drawing.
    my $r = layout([
        { caller => '*',        callee => GATEWAY,  count => 1 },
        { caller => GATEWAY,    callee => CHECKOUT, count => 1 },
        { caller => GATEWAY,    callee => DB,       count => 1 },
        { caller => CHECKOUT,   callee => CACHE,    count => 1 },
        { caller => DB,         callee => CACHE,    count => 1 },
    ]);
    is(node_of($r, CACHE)->{layer}, 3,
       'a diamond join sits below BOTH branches, by longest path');
    is($r->{back_edges}, 0, '  with no edge pointing backwards');
}

# --- A CYCLE IS REAL, NOT CORRUPTION ---------------------------------------

# Services genuinely call each other back. A longest-path layering loops
# forever on that, so back edges are detected and drawn differently rather
# than being dropped - an edge that exists and is not on the map is a lie
# about the topology.
{
    my $r = eval { layout([
        { caller => GATEWAY,  callee => CHECKOUT, count => 10 },
        { caller => CHECKOUT, callee => GATEWAY,  count => 5 },
    ]) };
    ok(defined $r, 'a two-service cycle does not hang');
    cmp_ok($r->{back_edges}, '>=', 1, '  and at least one edge is marked back');
    is(scalar @{ $r->{nodes} }, 2, '  both services are still on the map');
}

{
    my $r = eval { layout([
        { caller => GATEWAY,  callee => CHECKOUT, count => 1 },
        { caller => CHECKOUT, callee => DB,       count => 1 },
        { caller => DB,       callee => GATEWAY,  count => 1 },
    ]) };
    ok(defined $r, 'a three-service cycle does not hang');
    is(scalar @{ $r->{nodes} }, 3, '  all three are placed');
    cmp_ok($r->{back_edges}, '>=', 1, '  with a back edge reported');
    cmp_ok(scalar @{ $r->{back} }, '>=', 1, '  and identified by index');
}

{
    # A self-call should not appear at all - phase 7 excludes it - but if one
    # arrives the layout must not spin.
    my $r = eval { layout([ { caller => GATEWAY, callee => GATEWAY, count => 1 } ]) };
    ok(defined $r, 'a self-edge does not hang the layout');
}

# --- counts -----------------------------------------------------------------

{
    my $r = layout([
        { caller => '*',      callee => GATEWAY,  count => 100, errors => 0 },
        { caller => GATEWAY,  callee => CHECKOUT, count => 100, errors => 7 },
    ]);
    is("" . node_of($r, CHECKOUT)->{in}, '100', 'inbound counts are carried');
    is("" . node_of($r, CHECKOUT)->{errors}, '7', '  and errors');
    is("" . node_of($r, GATEWAY)->{out}, '100', '  and outbound');
}

# The busiest service in a layer comes first, so the eye lands on the traffic
# rather than on whatever order the edges arrived in.
{
    my $r = layout([
        { caller => '*', callee => CHECKOUT, count => 5 },
        { caller => '*', callee => DB,       count => 500 },
        { caller => '*', callee => CACHE,    count => 50 },
    ]);
    my @l1 = sort { $a->{slot} <=> $b->{slot} }
             grep { $_->{layer} == 1 } @{ $r->{nodes} };
    is("" . $l1[0]{service}, "" . DB, 'the busiest service in a layer is first');
    is("" . $l1[-1]{service}, "" . CHECKOUT, '  and the quietest is last');
}

{
    my $r = layout([]);
    is(scalar @{ $r->{nodes} }, 0, 'an empty graph lays out to nothing');
}

# --- the flamegraph ---------------------------------------------------------

# SELF TIME, not total. A root that lasts five seconds because it waited on a
# database did not SPEND five seconds.
{
    my $r = flame([
        { trace_hi=>'1', trace_lo=>'1', span_id=>'1', parent=>'0',
          start=>'0', end=>'1000', service=>GATEWAY, name=>10 },
        { trace_hi=>'1', trace_lo=>'1', span_id=>'2', parent=>'1',
          start=>'100', end=>'900', service=>DB, name=>20 },
    ]);
    my ($root) = grep { $_->{depth} == 0 } @{ $r->{frames} };
    my ($kid)  = grep { $_->{depth} == 1 } @{ $r->{frames} };
    is("$root->{total}", '1000', 'the root total is its duration');
    is("$root->{self}",  '200',
       '  but its SELF time excludes the 800 the child was running');
    is("$kid->{self}", '800', 'the child keeps its own time');
    is("$r->{total_self}", '1000', 'self times sum to the wall time');
}

# CONCURRENT children overlap. Summing them can exceed the parent and drive
# self time negative; merging the intervals first is what stops that.
{
    my $r = flame([
        { trace_hi=>'2', trace_lo=>'2', span_id=>'1', parent=>'0',
          start=>'0', end=>'1000', service=>GATEWAY, name=>10 },
        { trace_hi=>'2', trace_lo=>'2', span_id=>'2', parent=>'1',
          start=>'100', end=>'800', service=>DB, name=>20 },
        { trace_hi=>'2', trace_lo=>'2', span_id=>'3', parent=>'1',
          start=>'200', end=>'900', service=>CACHE, name=>30 },
    ]);
    my ($root) = grep { $_->{depth} == 0 } @{ $r->{frames} };
    # children cover 100..900 = 800, so self is 200 - NOT 1000-700-700 = -400
    is("$root->{self}", '200',
       'overlapping children are merged, so self time is never negative');
}

{
    # Non-overlapping children subtract in full.
    my $r = flame([
        { trace_hi=>'3', trace_lo=>'3', span_id=>'1', parent=>'0',
          start=>'0', end=>'1000', service=>GATEWAY, name=>10 },
        { trace_hi=>'3', trace_lo=>'3', span_id=>'2', parent=>'1',
          start=>'100', end=>'300', service=>DB, name=>20 },
        { trace_hi=>'3', trace_lo=>'3', span_id=>'3', parent=>'1',
          start=>'500', end=>'900', service=>DB, name=>30 },
    ]);
    my ($root) = grep { $_->{depth} == 0 } @{ $r->{frames} };
    is("$root->{self}", '400', 'disjoint children each subtract in full');
}

# The same function called from two places stays TWO frames - that is what
# makes a flamegraph a tree rather than a bar chart of function names.
{
    my $r = flame([
        { trace_hi=>'4', trace_lo=>'4', span_id=>'1', parent=>'0',
          start=>'0', end=>'1000', service=>GATEWAY, name=>10 },
        { trace_hi=>'4', trace_lo=>'4', span_id=>'2', parent=>'1',
          start=>'0', end=>'400', service=>CHECKOUT, name=>20 },
        { trace_hi=>'4', trace_lo=>'4', span_id=>'3', parent=>'1',
          start=>'500', end=>'900', service=>CACHE, name=>30 },
        { trace_hi=>'4', trace_lo=>'4', span_id=>'4', parent=>'2',
          start=>'10', end=>'100', service=>DB, name=>99 },
        { trace_hi=>'4', trace_lo=>'4', span_id=>'5', parent=>'3',
          start=>'510', end=>'600', service=>DB, name=>99 },
    ]);
    my @db = grep { $_->{name} == 99 } @{ $r->{frames} };
    is(scalar @db, 2,
       'the same call from two parents is two frames, not one merged bar');
    isnt($db[0]{parent}, $db[1]{parent}, '  with different parents');
}

# Several traces aggregate into one tree.
{
    my @spans;
    for my $t (1 .. 10) {
        push @spans,
          { trace_hi=>"$t", trace_lo=>'1', span_id=>"${t}1", parent=>'0',
            start=>'0', end=>'1000', service=>GATEWAY, name=>10 },
          { trace_hi=>"$t", trace_lo=>'1', span_id=>"${t}2", parent=>"${t}1",
            start=>'100', end=>'600', service=>DB, name=>20 };
    }
    my $r = flame(\@spans);
    my ($root) = grep { $_->{depth} == 0 } @{ $r->{frames} };
    is("$root->{count}", '10', 'ten traces aggregate into one frame');
    is("$root->{total}", '10000', '  with the totals summed');
    is("$root->{self}",  '5000',  '  and the self times summed');
}

done_testing();
