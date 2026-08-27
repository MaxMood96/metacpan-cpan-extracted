package Punk::Observe::Query;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Query - one query language over traces, metrics and logs

=head1 SYNOPSIS

    metric http.server.duration
      | where service = "api" and http.route = "/checkout"
      | rate(5m) by http.response.status_code
      | p95

    log {service="api"}
      | where severity >= error
      | search "connection refused"
      | count by service

    trace
      | where duration > 500ms and status = "error"
      | slowest 20

=head1 DESCRIPTION

A source, then stages. Every stage takes a stream of rows and returns a
stream of rows, so C<where>, C<by>, C<count> and the rest are B<one>
implementation each - they work on a log because a log line is a row, and on
a span because a span is a row.

The signals differ only in which columns exist.

=head1 THE CROSS-SIGNAL PIPELINE

Three stages re-key the stream, and they are the reason this is one language
rather than three:

    metric http.server.duration | p99 by http.route
      | exemplars     # the trace ids recorded alongside the spike
      | traces        # those traces, in full
      | logs          # every log line correlated by trace_id

A spike, to the traces that caused it, to the lines those traces logged, in
one expression.

C<| traces> needs a trace identifier on its rows. Logs and spans have one and
C<| exemplars> produces one; a bare metric stream does not. So
C<metric x | traces> is a parse error, and the error B<says to add
| exemplars first> - this is the feature, so it has to be discoverable by
typing rather than by reading this page.

=head1 GRAMMAR

    query      := source selector? pipeline?
    source     := 'metric' NAME | 'log' | 'trace' | 'spans'
    selector   := '{' cmp (',' cmp)* '}'          # sugar for a leading where
    pipeline   := ('|' stage)+

    stage      := 'where' expr
                | 'search' STRING
                | agg ('by' field (',' field)*)?
                | 'bucket' '(' DURATION ')' agg? ('by' field (',' field)*)?
                | 'rate' '(' DURATION ')' agg? ('by' field (',' field)*)?
                | 'top' INT 'by' agg
                | 'slowest' INT
                | 'limit' INT
                | 'sort' field ('asc' | 'desc')?
                | 'exemplars' | 'traces' | 'logs' | 'spans'

    agg        := 'count' | 'sum' | 'avg' | 'min' | 'max'
                | 'p50' | 'p90' | 'p95' | 'p99' | 'distinct'

    expr       := expr ('and' | 'or') expr | 'not' expr | '(' expr ')' | cmp
    cmp        := field OP value
    OP         := '=' | '!=' | '<' | '<=' | '>' | '>=' | '=~' | '!~'
    value      := STRING | NUMBER | DURATION | SEVERITY

C<not> binds tightest, then C<and>, then C<or>.

An aggregate carries its own grouping: C<count by service> is one stage.

=head2 Bucketing over time

C<bucket(1m)> cuts the range into equal spans and aggregates within each, so
the answer is a series over time rather than one number. Without an aggregate
it counts, which is the histogram of arrivals:

    log | bucket(1m) count by severity
    metric http.server.duration | bucket(5m) p95 by http.route

C<rate(5m)> is the same stage with the answer divided by the span, so it reads
per second and does not change when the window widens. Only C<count> and
C<sum> are divided: a percentile per second is not a quantity, and dividing
one would report a service getting faster because somebody chose a wider
bucket.

B<Boundaries are aligned to the epoch, not to the query.> A bucket covers the
same span whoever asks for it, so panning a chart does not move the
boundaries, and two panels over slightly different ranges agree about the
minutes they share.

B<A bucket with nothing in it is absent rather than zero.> For a count zero
would be right; for a percentile it would be invented, because no samples is
undefined rather than nought. What a gap means belongs to the caller, which
is the only party that knows the range that was asked for.

=head2 Durations

First-class tokens, not function calls: C<500ms>, C<1.5s>, C<5m>, C<2h>,
C<7d>, C<1w>. Also C<ns> and C<us>. There is deliberately no unit for a
month, because C<1m> meaning a month somewhere would be a trap nobody
recovers from.

=head2 Severities

C<trace>, C<debug>, C<info>, C<warn>, C<error>, C<fatal>, case-insensitive.
C<< severity >= error >> is a numeric comparison on OTLP's twenty-four point
scale, not a string match on a level name.

=head2 Columns

    every source     t, service, and any attribute
    metric           value
    log              body, severity, trace_id, span_id
    trace, spans     duration, name, status, kind, trace_id, span_id

B<Using a column that belongs to another signal is a parse error naming it,
never an empty result.> An empty result for a nonsensical query is the worst
outcome available, because it looks like an answer.

A name that is not a reserved column is an attribute, and attributes are
accepted on any source.

=head2 Values are quoted

C<where service = "api">, not C<where service = api>. A bare word is
ambiguous with a column reference, and accepting it would turn a mistyped
column name into a comparison that silently never matches. The error says so.

=head1 FUNCTIONS

Parsing only. To plan and run a query, see L<Punk::Observe::Exec/run>.

=head2 parse

    my $q = Punk::Observe::Query::parse($source);

Parses a query and returns its syntax tree.

On failure:

    { ok => 0, error => "...", offset => 24 }

C<offset> is the byte position in C<$source> where the parse stopped, so an
interface can point at the character rather than repeat the query back.

On success:

    {
      ok       => 1,
      source   => 'metric',
      name     => 'http.server.duration',
      selector => { ... },
      stages   => [ { kind => 'where', expr => { ... } }, ... ],
    }

C<source> is C<metric>, C<log>, C<trace> or C<spans>. C<name> is present only
for a metric source, and C<selector> only where one was given - it is sugar for
a leading C<where> and parses to the same expression shape.

Each stage carries C<kind>, and then whichever of these the stage has:

    expr     an expression tree, for where and the selector
    text     the literal, for search
    agg      the aggregate name, for agg and top
    window   the window in nanoseconds, for rate
    n        the count, for top, slowest and limit
    desc     present and true for a descending sort
    fields   the grouping or sort fields, as an arrayref

C<kind> is one of C<where>, C<search>, C<by>, C<agg>, C<rate>, C<top>,
C<slowest>, C<limit>, C<sort>, C<exemplars>, C<traces>, C<logs> or C<spans>.

An expression is a tree of comparisons joined by C<and>, C<or> and C<not>. A
duration literal has already become nanoseconds and a severity name has already
become its number on OTLP's twenty-four point scale, so a consumer never parses
either again.

=head2 parse_free_cycles

    my $ok = Punk::Observe::Query::parse_free_cycles($source, $n);

Parses and frees C<$n> times, returning how many parses succeeded. The syntax
tree is bump-allocated and released in one go, and this is what asserts that
holds under repetition: memory that grows across a few hundred thousand cycles
is a leak in the parser, on the one path a hostile caller can drive at will.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Exec>, L<Punk::Observe::Ingest>

=cut
