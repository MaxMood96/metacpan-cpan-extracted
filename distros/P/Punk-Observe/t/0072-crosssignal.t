#!perl
# The cross-signal jump. The reason this project exists.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $E = 'Punk::Observe::Exec';
my $Q = 'Punk::Observe::Query';
sub join_ { $E->can('join')->(@_) }

# --- seeded data where the expected answer is known by construction --------
#
# Three traces. Trace 1 is slow and has logs; trace 2 is fast and has logs;
# trace 3 has logs but no exemplar pointing at it.

my $exemplars = [
    { trace_hi => '1', trace_lo => '100', value => 900 },
    { trace_hi => '2', trace_lo => '200', value => 120 },
];

my $traces = [
    { trace_hi => '1', trace_lo => '100', kind => 'span',
      duration => '900000000', service => 'checkout', body => 'POST /pay' },
    { trace_hi => '2', trace_lo => '200', kind => 'span',
      duration => '120000000', service => 'checkout', body => 'GET /cart' },
    { trace_hi => '3', trace_lo => '300', kind => 'span',
      duration => '50000000',  service => 'checkout', body => 'GET /health' },
];

my $logs = [
    { trace_hi => '1', trace_lo => '100', kind => 'log', severity => 17,
      body => 'connection refused' },
    { trace_hi => '1', trace_lo => '100', kind => 'log', severity => 9,
      body => 'retrying' },
    { trace_hi => '2', trace_lo => '200', kind => 'log', severity => 9,
      body => 'ok' },
    { trace_hi => '3', trace_lo => '300', kind => 'log', severity => 9,
      body => 'health ok' },
    { trace_hi => '9', trace_lo => '900', kind => 'log', severity => 9,
      body => 'unrelated' },
];

# --- metric to traces -------------------------------------------------------

{
    my $t = join_($exemplars, $traces, 'traces');
    is(scalar @$t, 2, 'exemplars reach exactly the traces they name');
    # `map {;` disambiguates: `map { "..." => 1 }` is parsed as a hashref.
    my %got = map {; $_->{trace_hi} . '/' . $_->{trace_lo} => 1 } @$t;
    ok($got{'1/100'} && $got{'2/200'}, '  traces 1 and 2');
    ok(!$got{'3/300'},
       '  and NOT trace 3, which no exemplar points at');
}

# --- traces to logs ---------------------------------------------------------

{
    my $t = join_($exemplars, $traces, 'traces');
    my $l = join_($t, $logs, 'logs');
    is(scalar @$l, 3, 'those traces reach their three log lines');
    my $bad = grep { $_->{trace_hi} !~ /^[12]$/ } @$l;
    is($bad, 0, '  and only theirs');
    my ($refused) = grep { $_->{body} eq 'connection refused' } @$l;
    ok($refused, '  including the error line from the slow trace');
}

# THE WHOLE POINT, end to end: a spike, to the traces that caused it, to the
# lines those traces logged.
{
    my $l = join_(join_($exemplars, $traces, 'traces'), $logs, 'logs');
    my @bodies = sort map { $_->{body} } @$l;
    is_deeply(\@bodies, [ 'connection refused', 'ok', 'retrying' ],
              'metric to exemplars to traces to logs gives exactly the right lines');
}

# The unrelated log line is never reachable from any exemplar.
{
    my $l = join_(join_($exemplars, $traces, 'traces'), $logs, 'logs');
    my $unrelated = grep { $_->{body} eq 'unrelated' } @$l;
    is($unrelated, 0, 'a log line belonging to no traced request is not reached');
}

# --- a general join is REFUSED ---------------------------------------------

# Not a limitation to apologise for: three columnar stores with no shared key
# would need a planner nobody can predict and a cost model nobody can debug.
{
    my $ok = eval { join_($logs, $traces, 'anything'); 1 };
    ok(!$ok, 'an arbitrary join edge is refused');
    like($@, qr/only traces, logs and spans/,
         '  naming the three edges that physically exist');
}

for my $edge (qw(traces logs spans)) {
    my $ok = eval { join_($exemplars, $traces, $edge); 1 };
    ok($ok, "the '$edge' edge is accepted");
}

# --- the parser enforces the same rule -------------------------------------

# `metric x | traces` cannot work, and the ERROR is the discoverable half of
# the feature.
{
    my $r = $Q->can('parse')->('metric x | traces');
    ok(!$r->{ok}, 'metric to traces without exemplars is a parse error');
    like($r->{error}, qr/exemplars/, '  recommending | exemplars');

    my $ok = $Q->can('parse')->('metric x | exemplars | traces | logs');
    ok($ok->{ok}, 'and with exemplars the whole chain parses');
}

# --- empty sides ------------------------------------------------------------

{
    is(scalar @{ join_([], $traces, 'traces') }, 0,
       'no exemplars reach no traces');
    is(scalar @{ join_($exemplars, [], 'traces') }, 0,
       'exemplars into no traces give nothing');
}

# --- ids sharing a half must not join --------------------------------------

# The same reason the trace index stores all 16 bytes: joining on half an id
# would connect unrelated requests.
{
    my $left  = [ { trace_hi => '1', trace_lo => '100' } ];
    my $right = [ { trace_hi => '1', trace_lo => '999', body => 'wrong' },
                  { trace_hi => '9', trace_lo => '100', body => 'also wrong' },
                  { trace_hi => '1', trace_lo => '100', body => 'right' } ];
    my $j = join_($left, $right, 'logs');
    is(scalar @$j, 1, 'only the exact id joins');
    is($j->[0]{body}, 'right', '  and it is the right one');
}

# --- THE PIPELINE, THROUGH THE REAL QUERY PATH -----------------------------
#
# Everything above tests the join primitive. This tests the thing a person
# types: the stages parsed and planned for a release while nothing executed
# them, so the answer came back as the metric stream unchanged - the right
# row count, the wrong rows, silently. The assertion that catches that is not
# "some rows came back", it is "the rows are LOG lines and they belong to the
# traces the exemplars named".

SKIP: {
    eval { require Punk::Observe::Store; require Punk::Observe::WAL; 1 }
        or skip 'store not available', 12;
    require File::Temp;

    my $dir = File::Temp::tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $T = '1774224000000000000';
    my $at = sub { Punk::Observe::Store::nadd($T, $_[0]) };

    # Two traces are named by exemplars on the metric; a third is not, and
    # its log line is the one that must never appear.
    my @recs;
    for my $n (1, 2, 3) {
        push @recs,
            # the metric point - only 1 and 2 carry an exemplar
            { kind => 1, t => $at->($n * 1_000_000), body => 'http.server.request.count',
              value => 10 + $n, severity => 0, span_kind => 0, status => 0,
              duration => 0, span_id => 0, parent_id => 0,
              trace_hi => ($n < 3 ? $n : 0), trace_lo => ($n < 3 ? $n * 100 : 0),
              attrs => { 'service.name' => 'shop', 'http.route' => '/checkout' } },
            # the span
            { kind => 3, t => $at->($n * 1_000_000), body => "span $n",
              duration => 5_000_000, severity => 0, span_kind => 2, status => 0,
              trace_hi => $n, trace_lo => $n * 100, span_id => $n, parent_id => 0,
              attrs => { 'service.name' => 'shop' } },
            # the log line
            { kind => 2, t => $at->($n * 1_000_000), body => "line for trace $n",
              severity => 17, span_kind => 0, status => 0, duration => 0,
              span_id => $n, parent_id => 0,
              trace_hi => $n, trace_lo => $n * 100,
              attrs => { 'service.name' => 'shop' } };
    }
    ok(Punk::Observe::WAL::append($store->wal_path, \@recs, 0, 0)->{ok},
       'the cross-signal fixture reaches the log');
    ok($store->seal, '  and seals');

    my %W = (from => $T, to => $at->(60_000_000_000));
    my $run = sub { $store->query($_[0], %W) };

    my $base = $run->('metric http.server.request.count');
    ok($base->{ok}, 'the metric alone answers') or diag $base->{error};
    is(scalar @{ $base->{rows} }, 3, '  three points, one per trace');

    # `| exemplars` keeps only the points that carry a trace id.
    my $ex = $run->('metric http.server.request.count | exemplars');
    ok($ex->{ok}, 'the exemplars stage runs') or diag $ex->{error};
    is(scalar @{ $ex->{rows} }, 2,
       '  keeping only the points that carry a trace id');

    # `| traces` re-keys onto the spans of those traces.
    my $tr = $run->('metric http.server.request.count | exemplars | traces');
    ok($tr->{ok}, 'the traces stage runs') or diag $tr->{error};
    is(scalar @{ $tr->{rows} }, 2, '  two spans, one per named trace');
    is(scalar(grep { ($_->{body} // '') eq 'span 3' } @{ $tr->{rows} }), 0,
       '  and never the trace no exemplar pointed at');

    # THE FLAGSHIP, end to end.
    my $full = $run->(
        'metric http.server.request.count | where http.route = "/checkout"'
      . ' | exemplars | traces | logs');
    ok($full->{ok}, 'the whole cross-signal pipeline runs') or diag $full->{error};
    my @bodies = sort map { $_->{body} // '' } @{ $full->{rows} };
    is_deeply(\@bodies, [ 'line for trace 1', 'line for trace 2' ],
              '  and returns exactly the log lines of the traces the '
            . 'exemplars named');

    # The assertion that catches the silent no-op: the answer is a different
    # SIGNAL from the one the query started in.
    #
    # Written first as `grep { $_->{kind} == 1 }`, which was vacuous twice
    # over - `kind` is the WORD 'log', so the comparison warned and was
    # always false, and a metric row carries no `kind` at all, so the no-op
    # this exists to catch would have passed it too. Compared as the string
    # it is, against rows that must all have one.
    my %kinds;
    $kinds{ $_->{kind} // '(none)' } = 1 for @{ $full->{rows} };
    is_deeply([ sort keys %kinds ], [ 'log' ],
              '  and every row is a log row - a returned metric point has no '
            . '`kind` at all, so a pipeline that quietly handed back its own '
            . 'input fails here');

    # --- AN AGGREGATE BEFORE THE JUMP ---------------------------------------
    #
    # The flagship expression buckets to a percentile before it jumps, and an
    # aggregate CONSUMES its rows: the first working version of the join read
    # the result's rows, found buckets and none, and returned an empty answer
    # with `ok` true - a jump that silently reaches nothing, which is the
    # exact failure the refusal existed to prevent. The ids are collected
    # where each row passes the filters instead, so this is the row that
    # proves it.
    my $agg = $run->('metric http.server.request.count'
                   . ' | bucket(5m) count | exemplars | logs');
    ok($agg->{ok}, 'a jump AFTER an aggregate runs') or diag $agg->{error};
    my @ab = sort map { $_->{body} // '' } @{ $agg->{rows} };
    is_deeply(\@ab, [ 'line for trace 1', 'line for trace 2' ],
              '  and still reaches the traces the points carried, though the '
            . 'aggregate consumed the points');

    # `| exemplars` as the LAST stage after an aggregate leaves the chart
    # alone: replacing a bucketed answer with a row list is not what it was
    # asked to do.
    my $last = $run->('metric http.server.request.count'
                    . ' | bucket(5m) count | exemplars');
    ok($last->{ok}, 'exemplars last, after an aggregate, runs');
    is($last->{shape}, 'buckets', '  and leaves the buckets as the answer');
}

# --- a join wider than the cap REFUSES --------------------------------------
#
# A truncated join is a wrong answer wearing a complete one's clothes: the
# row it dropped is the row somebody was looking for. So past the cap it is
# refused, and the refusal says what to do instead.

SKIP: {
    eval { require Punk::Observe::Store; require Punk::Observe::WAL; 1 }
        or skip 'store not available', 4;
    require File::Temp;

    my $dir = File::Temp::tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $T = '1774224000000000000';

    # One metric point per trace, past PO_TRACESET_MAX (4096).
    my @recs;
    for my $n (1 .. 4200) {
        push @recs, { kind => 1, t => Punk::Observe::Store::nadd($T, $n * 1000),
                      body => 'm', value => 1, severity => 0, span_kind => 0,
                      status => 0, duration => 0, span_id => 0, parent_id => 0,
                      trace_hi => $n, trace_lo => $n, attrs => {} };
    }
    Punk::Observe::WAL::append($store->wal_path, \@recs, 0, 0);
    $store->seal;

    my $r = $store->query('metric m | exemplars | logs',
                          from => $T,
                          to => Punk::Observe::Store::nadd($T, '60000000000'));
    ok(!$r->{ok}, 'a join wider than the cap is refused');
    like($r->{error} || '', qr/more than 4096 traces/,
         '  naming the cap, so the number is not a mystery');
    like($r->{hint} || '', qr/aggregating before the jump/,
         '  and what to do about it');
    is(scalar @{ $r->{rows} || [] }, 0,
       '  carrying no rows - a refusal with rows renders as an answer');
}

done_testing();
