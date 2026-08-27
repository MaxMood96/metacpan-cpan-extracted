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

done_testing();
