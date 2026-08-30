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

    metric http.server.request.count
      | where service = "api" and http.route = "/checkout"
      | rate(5m) by http.response.status_code

    log {service="api"}
      | where severity >= error
      | search "connection refused"
      | count by service

    trace
      | where duration > 500ms and status = error
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

    spans | where http.route = "/checkout" | bucket(5m) p99
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

Each re-key runs as a B<second pass over the store>: the ids the surviving
rows carry become a set, and the target signal is read filtered to it. So the
answer to a cross-signal expression is rows of the B<last> signal named, not
of the one it started in.

C<| exemplars> keeps only the points that B<carry> a trace id. That id comes
from an OTLP exemplar recorded by the SDK at the moment the measurement was
taken; a point without one joins to nothing, which is not the same as joining
to everything and must never be confused for it.

A join covering more than B<4,096> traces is refused rather than trimmed. A
truncated join is a wrong answer wearing a complete one's clothes, and the
row it dropped is the row somebody was looking for; the refusal says to
aggregate before the jump.

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
    spans | bucket(5m) p95 by http.route

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
C<7d>, C<1w>, C<1y>. Also C<ns> and C<us>. There is deliberately no unit for
a month, because C<1m> meaning a month somewhere would be a trap nobody
recovers from, and because a month has no length to give it.

C<y> is B<exactly 365 days>, not a calendar year. A duration here is a count
of nanoseconds rather than a date arithmetic, so there is no date for a leap
day to attach to; seven years is 2,555 days and not 2,557.

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

=head2 Values are quoted, except the names that are numbers

C<where service = "api">, not C<where service = api>. A bare word is
ambiguous with a column reference, and accepting it would turn a mistyped
column name into a comparison that silently never matches. The error says so.

The exception is the two closed vocabularies, which are B<bare>:

    severity   trace debug info warn warning error fatal
    status     unset ok error

Both resolve to their numbers when the query is parsed, so C<severity >=
error> and C<status = error> are numeric comparisons and orderings on them
mean what they look like. They are not string matches on a level name, and
quoting them does not work - C<status = "error"> compares a numeric column
against a string, which no row answers.

C<error> appears in both lists and is a different number in each - 17 and 2.
Which one a bare word means is decided by the column it is compared against.

=head1 FUNCTIONS

Parsing only. To plan and run a query, see L<Punk::Observe::Exec/run>.

=head2 What the grammar above does not tell you

Three things surprise people, and none of them is visible in a grammar.

B<An aggregate takes no argument, and reads a column it chose.> There is no
C<p95(some.attribute)>: the column comes from the row kind - C<value> for a
metric, C<duration> for a span, C<severity> for a log line. So C<spans | p95>
is the 95th percentile I<of duration>, and a log source refuses everything but
C<count> and C<distinct> because it has no numeric column worth averaging.

B<C<=~> is not a regular expression engine.> It takes an anchored prefix
C<"^api-">, an anchored suffix C<"error$">, both anchors for an exact match,
or a plain substring. Anything else is refused when the query is planned, with
a message saying which forms are available - a full engine over a log block is
a scan this cannot afford.

B<Absent is not zero, and C<null> is how you ask about it.> A comparison
against a field the row does not carry is false in I<both> directions - the
alternative is a filter that quietly matches everything without the field.
The one place absence is an answer is the C<null> literal:
C<where risk.outcome != null> keeps exactly the rows carrying the attribute
(whatever its value, empty included), C<= null> keeps the rows without it,
and any other operator against C<null> is refused, because an ordering
against nothing would have to invent a meaning.

B<Absent is not zero.> A comparison against a column the row does not carry is
false in I<both> directions, so neither C<duration E<gt> 0> nor
C<duration E<lt> 1> matches a log line. The alternative - treating a missing
column as zero - is a filter that quietly matches everything that does not
have the thing being filtered on.

B<C<| viz>> names the chart the answer should be drawn as - C<line>,
C<area>, C<bar>, C<stat> or C<table> - and is a property of the query rather
than a stage: it transforms no rows, appears at most once, and rides wherever
the query string goes, so a saved view or a pasted explorer URL keeps its
chart. A kind the answer's shape cannot take is refused where it is drawn,
naming the stage that would fix it. In a dashboard panel the query's own
C<viz> wins over the panel's stored one, because the one written next to the
question is the one somebody meant.

Also accepted and not canonical: C<logs>, C<traces> and C<span> as source
aliases, C<==> for C<=>, single-quoted strings, C<warning> for C<warn>,
C<time> for C<t>, and C<#> to the end of the line as a comment.

L<Punk::Observe> mounts a reference for all of this at
C<< <prefix>/help >>, generated from the parser's own tables.

=head2 grammar

    my $g = Punk::Observe::Query::grammar();

The language's surface, read from the tables the parser consults: C<sources>,
C<columns> keyed by source, C<aggregates>, C<severities> with the numbers they
resolve to, C<units> with their nanosecond values, and C<operators>.

This exists so the help page can be generated rather than written out. A
reference maintained by hand is one that goes wrong, and this one would go
wrong about four static tables a few lines apart.

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
      name     => 'http.server.request.count',
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
    window   the window in nanoseconds, for bucket and rate
    n        the count, for top, slowest and limit
    desc     present and true for a descending sort
    fields   the grouping or sort fields, as an arrayref

C<kind> is one of C<where>, C<search>, C<by>, C<agg>, C<bucket>, C<rate>,
C<top>, C<slowest>, C<limit>, C<sort>, C<exemplars>, C<traces>, C<logs> or
C<spans>.

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
