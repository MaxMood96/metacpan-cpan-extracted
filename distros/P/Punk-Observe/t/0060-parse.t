#!perl
# The query language. Every production, and the precedence that produces
# plausible wrong answers rather than errors when it is wrong.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $Q = 'Punk::Observe::Query';
sub parse { $Q->can('parse')->($_[0]) }
sub kinds { [ map { $_->{kind} } @{ $_[0]{stages} } ] }

# --- sources ----------------------------------------------------------------

{
    my $r = parse('metric http.server.duration');
    ok($r->{ok}, 'a bare metric parses') or diag $r->{error};
    is($r->{source}, 'metric', '  source is metric');
    is($r->{name}, 'http.server.duration',
       '  and a dotted name is ONE identifier, not a field access');
}

for my $s (['log', 'log'], ['logs', 'log'], ['trace', 'trace'],
           ['traces', 'trace'], ['spans', 'spans'], ['span', 'spans']) {
    my $r = parse($s->[0]);
    ok($r->{ok}, "'$s->[0]' parses") or diag $r->{error};
    is($r->{source}, $s->[1], "  as $s->[1]");
}

# --- the selector sugar -----------------------------------------------------

# `log {service="api"}` is the shape people type; forcing `| where` for the
# common case is friction for nothing.
{
    my $a = parse('log {service="api"}');
    my $b = parse('log | where service = "api"');
    ok($a->{ok} && $b->{ok}, 'both spellings parse');
    is($a->{selector}, 'service = "api"', 'the selector holds the predicate');
    is($b->{stages}[0]{expr}, 'service = "api"',
       '  and the explicit where holds the same one');
}

{
    my $r = parse('log {service="api", severity=error}');
    ok($r->{ok}, 'a multi-pair selector parses') or diag $r->{error};
    is($r->{selector}, '(service = "api" and severity = sev:17)',
       '  and folds to a conjunction, with severity on the 24-point scale');
}

# --- precedence -------------------------------------------------------------

# `and` binds tighter than `or`. Getting this wrong does not error, it gives
# plausible wrong answers.
{
    my $r = parse('log | where a = 1 or b = 2 and c = 3');
    is($r->{stages}[0]{expr}, '(a = 1 or (b = 2 and c = 3))',
       'and binds tighter than or');
}
{
    my $r = parse('log | where a = 1 and b = 2 or c = 3');
    is($r->{stages}[0]{expr}, '((a = 1 and b = 2) or c = 3)',
       '  in the other order too');
}
{
    my $r = parse('log | where not a = 1 and b = 2');
    is($r->{stages}[0]{expr}, '((not a = 1) and b = 2)',
       'not binds tighter than and');
}
{
    my $r = parse('log | where (a = 1 or b = 2) and c = 3');
    is($r->{stages}[0]{expr}, '((a = 1 or b = 2) and c = 3)',
       'parentheses override precedence');
}

# --- durations are first-class ---------------------------------------------

{
    my @cases = (
        [ '500ms', '500000000' ],
        [ '1s',    '1000000000' ],
        [ '5m',    '300000000000' ],
        [ '2h',    '7200000000000' ],
        [ '7d',    '604800000000000' ],
        [ '1w',    '604800000000000' ],
        [ '100ns',  '100' ],
        [ '250us',  '250000' ],
    );
    for my $c (@cases) {
        my $r = parse("trace | where duration > $c->[0]");
        ok($r->{ok}, "duration literal $c->[0] parses") or diag $r->{error};
        is($r->{stages}[0]{expr}, "duration > $c->[1]ns",
           "  $c->[0] is $c->[1] nanoseconds");
    }
    # 7d exceeds 2^32 nanoseconds many times over, so this is also the 64-bit
    # assertion for the lexer.
    my $r = parse('trace | where duration > 7d');
    is($r->{stages}[0]{expr}, 'duration > 604800000000000ns',
       'a 7-day duration is exact, well past 2^32');
}

{
    my $r = parse('trace | where duration > 1.5s');
    ok($r->{ok}, 'a fractional duration parses') or diag $r->{error};
    is($r->{stages}[0]{expr}, 'duration > 1500000000ns', '  1.5s is 1.5e9 ns');
}

# --- severities -------------------------------------------------------------

# `severity >= error` is a NUMERIC comparison on the 24-point scale, not a
# string match on a level name.
{
    my %want = (trace => 1, debug => 5, info => 9, warn => 13,
                warning => 13, error => 17, fatal => 21);
    for my $name (sort keys %want) {
        my $r = parse("log | where severity >= $name");
        ok($r->{ok}, "severity name $name parses") or diag $r->{error};
        is($r->{stages}[0]{expr}, "severity >= sev:$want{$name}",
           "  $name is $want{$name}");
    }
    my $r = parse('log | where severity >= ERROR');
    is($r->{stages}[0]{expr}, 'severity >= sev:17', 'and the name is case-insensitive');
}

# --- stages -----------------------------------------------------------------

{
    my $r = parse('log | where severity >= error | search "refused" | count by service | limit 20');
    ok($r->{ok}, 'a four-stage pipeline parses') or diag $r->{error};
    # `count by service` is ONE stage: an aggregate carries its grouping.
    is_deeply(kinds($r), [ 'where', 'search', 'agg', 'limit' ],
              '  in order, with the grouping attached to the aggregate');
    is($r->{stages}[1]{text}, 'refused', '  search carries its term');
    is($r->{stages}[2]{agg}, 'count', '  the aggregate is count');
    is_deeply($r->{stages}[2]{fields}, [ 'service' ],
              '  and its own grouping, not a separate stage');
    is("$r->{stages}[3]{n}", '20', '  limited to 20');
}

{
    my $r = parse('metric x | rate(5m) | p95');
    ok($r->{ok}, 'rate and a percentile parse') or diag $r->{error};
    is("$r->{stages}[0]{window}", '300000000000', 'the rate window is 5 minutes');
    is($r->{stages}[1]{agg}, 'p95', 'and p95 follows');
}

{
    my $r = parse('trace | where duration > 2s | slowest 10');
    ok($r->{ok}, 'slowest parses') or diag $r->{error};
    is("$r->{stages}[1]{n}", '10', '  with its count');
}

{
    my $r = parse('spans | count by http.route | top 5 by count');
    ok($r->{ok}, 'top N by an aggregate parses') or diag $r->{error};
    is_deeply(kinds($r), [ 'agg', 'top' ], '  as two stages');
    is($r->{stages}[1]{agg}, 'count', '  with the aggregate named');
    is("$r->{stages}[1]{n}", '5', '  and the count');
}

{
    my $r = parse('trace | sort duration desc | limit 50');
    ok($r->{ok}, 'sort desc parses') or diag $r->{error};
    is($r->{stages}[0]{desc}, 1, '  descending');
    is_deeply($r->{stages}[0]{fields}, [ 'duration' ], '  on duration');
}

{
    my $r = parse('log | count by service, severity');
    is_deeply($r->{stages}[0]{fields}, [ 'service', 'severity' ],
              'by takes several fields');
}

# --- THE CROSS-SIGNAL PIPELINE ---------------------------------------------

# The reason this project exists.
{
    my $q = 'metric http.server.duration | where service = "api" '
          . '| p99 by http.route | exemplars | traces | logs';
    my $r = parse($q);
    ok($r->{ok}, 'the full cross-signal query parses') or diag $r->{error};
    is_deeply(kinds($r),
              [ 'where', 'agg', 'exemplars', 'traces', 'logs' ],
              '  metric to exemplars to traces to logs');
    is_deeply($r->{stages}[1]{fields}, [ 'http.route' ],
              '  with p99 grouped by route');
}

{
    my $r = parse('trace | where duration > 2s | slowest 10 | logs');
    ok($r->{ok}, 'traces to logs parses, since a trace already has the key')
        or diag $r->{error};
}
{
    my $r = parse('log | where severity >= error | traces');
    ok($r->{ok}, 'logs to traces parses for the same reason') or diag $r->{error};
}

# --- operators --------------------------------------------------------------

{
    for my $op ('=', '!=', '<', '<=', '>', '>=', '=~', '!~') {
        my $r = parse("log | where service $op \"api\"");
        ok($r->{ok}, "operator $op parses") or diag $r->{error};
        is($r->{stages}[0]{expr}, "service $op \"api\"", "  and round-trips");
    }
}

# --- comments and whitespace -----------------------------------------------

{
    my $r = parse("log   {service=\"api\"}\n  | where severity >= error # only errors\n  | limit 5");
    ok($r->{ok}, 'newlines and a trailing comment parse') or diag $r->{error};
    is_deeply(kinds($r), [ 'where', 'limit' ], '  with the right stages');
}

# --- the AST frees ----------------------------------------------------------

# Parsed and freed ten thousand times. A bump allocator that leaked a chunk
# per parse, or an AST holding pointers into a growing arena, shows up here.
{
    my $q = 'metric http.server.duration | where service = "api" and '
          . 'http.route =~ "^/api" | p99 by http.route | exemplars | traces | logs';
    my $ok = $Q->can('parse_free_cycles')->($q, 10000);
    is($ok, 10000, '10,000 parse-and-free cycles all succeed');
}

done_testing();
