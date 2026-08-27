#!perl
# The service graph, accumulated at seal so the map is not a scan per page
# load.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $T = 'Punk::Observe::Trace';
sub analyse { $T->can('analyse')->($_[0]) }

use constant { GATEWAY => 1, CHECKOUT => 2, DB => 3, CACHE => 4 };
use constant { ST_OK => 1, ST_ERROR => 2 };

sub edges_of {
    my ($r) = @_;
    my %e;
    $e{"$_->{caller}->$_->{callee}"} = $_ for @{ $r->{edges} };
    return \%e;
}

# --- a straight chain -------------------------------------------------------

{
    my $r = analyse([
        { trace_hi=>'1', trace_lo=>'1', span_id=>'1', parent=>'0',
          start=>'1000', end=>'5000', service=>GATEWAY },
        { trace_hi=>'1', trace_lo=>'1', span_id=>'2', parent=>'1',
          start=>'1100', end=>'4000', service=>CHECKOUT },
        { trace_hi=>'1', trace_lo=>'1', span_id=>'3', parent=>'2',
          start=>'1200', end=>'3000', service=>DB },
    ]);
    my $e = edges_of($r);
    is(scalar @{ $r->{edges} }, 3, 'a three-service chain gives three edges');
    ok($e->{'*->1'},  'entry traffic comes from the synthetic root');
    ok($e->{'1->2'},  'gateway calls checkout');
    ok($e->{'2->3'},  'checkout calls the database');
    is("$e->{'2->3'}{count}", '1', '  once');
}

# --- a fan-out --------------------------------------------------------------

{
    my $r = analyse([
        { trace_hi=>'2', trace_lo=>'2', span_id=>'1', parent=>'0',
          start=>'1000', end=>'9000', service=>GATEWAY },
        { trace_hi=>'2', trace_lo=>'2', span_id=>'2', parent=>'1',
          start=>'1100', end=>'2000', service=>CHECKOUT },
        { trace_hi=>'2', trace_lo=>'2', span_id=>'3', parent=>'1',
          start=>'1200', end=>'3000', service=>DB },
        { trace_hi=>'2', trace_lo=>'2', span_id=>'4', parent=>'1',
          start=>'1300', end=>'4000', service=>CACHE },
    ]);
    my $e = edges_of($r);
    is("$e->{'1->2'}{count}", '1', 'gateway to checkout');
    is("$e->{'1->3'}{count}", '1', 'gateway to database');
    is("$e->{'1->4'}{count}", '1', 'gateway to cache');
}

# --- same-service calls are NOT edges --------------------------------------

# An internal call is not a graph edge. Counting one would make every service
# a self-loop dominating the map.
{
    my $r = analyse([
        { trace_hi=>'3', trace_lo=>'3', span_id=>'1', parent=>'0',
          start=>'1000', end=>'5000', service=>CHECKOUT },
        { trace_hi=>'3', trace_lo=>'3', span_id=>'2', parent=>'1',
          start=>'1100', end=>'2000', service=>CHECKOUT },
        { trace_hi=>'3', trace_lo=>'3', span_id=>'3', parent=>'2',
          start=>'1200', end=>'1900', service=>CHECKOUT },
        { trace_hi=>'3', trace_lo=>'3', span_id=>'4', parent=>'3',
          start=>'1300', end=>'1800', service=>DB },
    ]);
    my $e = edges_of($r);
    ok(!exists $e->{'2->2'}, 'a service calling itself is not an edge');
    is(scalar @{ $r->{edges} }, 2,
       'four spans in two services give exactly two edges');
    ok($e->{'*->2'}, '  entry to checkout');
    ok($e->{'2->3'}, '  and checkout to the database');
}

# --- an absent parent is shown, not hidden ---------------------------------

# A request whose caller was not instrumented is exactly what a service map
# should surface. Dropping it would make the traffic appear from nowhere.
{
    my $r = analyse([
        { trace_hi=>'4', trace_lo=>'4', span_id=>'2', parent=>'99',
          start=>'1100', end=>'2000', service=>CHECKOUT },
    ]);
    my $e = edges_of($r);
    is(scalar @{ $r->{edges} }, 1, 'a span with a missing parent still makes an edge');
    ok($e->{'*->2'}, '  attributed to the synthetic root');
    is($r->{orphans}, 1, '  and the orphan is counted so the gap is visible');
}

# --- counts, errors and durations aggregate --------------------------------

{
    my @s;
    for my $t (1 .. 30) {
        push @s,
          { trace_hi=>"$t", trace_lo=>'1', span_id=>"${t}1", parent=>'0',
            start=>'1000', end=>'5000', service=>GATEWAY },
          { trace_hi=>"$t", trace_lo=>'1', span_id=>"${t}2", parent=>"${t}1",
            start=>'1100', end=>"" . (1100 + $t * 100), service=>CHECKOUT,
            status => ($t % 5 == 0 ? ST_ERROR : ST_OK) };
    }
    my $r = analyse(\@s);
    my $e = edges_of($r);
    is("$e->{'1->2'}{count}", '30', 'the edge counts every call');
    is("$e->{'1->2'}{errors}", '6', '  and the errors among them');
    is("$e->{'1->2'}{dur_max}", '3000', '  and tracks the slowest');
    ok($r->{any_error}, 'the segment records that it holds errors');
}

# --- a cycle in the CALL GRAPH is legitimate -------------------------------

# Services do call each other back. That is a real topology, not corruption,
# and it must not be confused with a parent-pointer cycle.
{
    my $r = analyse([
        { trace_hi=>'5', trace_lo=>'5', span_id=>'1', parent=>'0',
          start=>'1000', end=>'9000', service=>GATEWAY },
        { trace_hi=>'5', trace_lo=>'5', span_id=>'2', parent=>'1',
          start=>'1100', end=>'8000', service=>CHECKOUT },
        { trace_hi=>'5', trace_lo=>'5', span_id=>'3', parent=>'2',
          start=>'1200', end=>'7000', service=>GATEWAY },
    ]);
    my $e = edges_of($r);
    is($r->{cycles}, 0, 'a service calling back is not a parent cycle');
    ok($e->{'1->2'}, 'gateway to checkout');
    ok($e->{'2->1'}, 'and checkout back to gateway, both edges present');
}

# --- many traces ------------------------------------------------------------

{
    my @s;
    for my $t (1 .. 200) {
        push @s,
          { trace_hi=>"$t", trace_lo=>'9', span_id=>"${t}1", parent=>'0',
            start=>"" . (1000 + $t), end=>"" . (5000 + $t), service=>GATEWAY },
          { trace_hi=>"$t", trace_lo=>'9', span_id=>"${t}2", parent=>"${t}1",
            start=>"" . (1100 + $t), end=>"" . (4000 + $t), service=>CHECKOUT },
          { trace_hi=>"$t", trace_lo=>'9', span_id=>"${t}3", parent=>"${t}2",
            start=>"" . (1200 + $t), end=>"" . (3000 + $t),
            service=> ($t % 2 ? DB : CACHE) };
    }
    my $r = analyse(\@s);
    is($r->{traces}, 200, '200 traces');
    is($r->{spans}, 600, '600 spans');

    my $e = edges_of($r);
    # entry, gateway->checkout, checkout->db, checkout->cache
    is(scalar @{ $r->{edges} }, 4,
       'the edge table is services-squared, not spans: four edges for 600 spans');
    is("$e->{'1->2'}{count}", '200', 'every call is counted');
    is("$e->{'2->3'}{count}", '100', '  and the split branches correctly');
    is("$e->{'2->4'}{count}", '100', '  both ways');
}

done_testing();
