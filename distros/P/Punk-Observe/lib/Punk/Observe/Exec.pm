package Punk::Observe::Exec;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Exec - planning and running a query

=head1 SYNOPSIS

    use Punk::Observe::Exec;

    my @rows = (
        { kind => 'span', t => 1, duration => 700_000_000,
          service => 'api', status => 2 },
        { kind => 'log',  t => 2, body => 'connection refused',
          severity => 17, service => 'api' },
    );

    my $r = Punk::Observe::Exec::run(
        'trace | where duration > 500ms | slowest 20', \@rows, {});

    die "$r->{stage}: $r->{error}" unless $r->{ok};
    warn 'partial answer' if $r->{meta}{truncated};

=head1 DESCRIPTION

A query is parsed by L<Punk::Observe::Query>, planned, and then executed in
B<steps>.

=head2 It yields

A worker holds hundreds of connections. A query that scans two gigabytes
synchronously stalls every one of them, and what the operator sees is that the
service froze because somebody opened a dashboard.

So the executor is a resumable state machine rather than a function: it
processes a bounded number of rows and returns, and the caller drives it from a
timer so the event loop runs in between. Yielding is invisible in the answer -
the same query over the same data gives the same result whatever the step
budget.

=head2 It refuses

Estimating a query's cost and refusing it is the fourth thing the planner does,
and a refusal carries what to add rather than what went wrong:

    this query would scan too much - try narrowing the time range, as in
    | where t > ...

A refused query with an actionable message is a better product than a
thirty-second one, and far better than a timeout.

=head2 The result is honest

C<meta> is never optional and never absent. It carries how many rows were
scanned, whether a budget cut the answer short, and whether a percentile is
exact.

B<A truncated result that looks complete is the observability equivalent of a
green dashboard over dropped spans> - which is the failure this whole project
exists to stop. A partial answer is the correct prefix of the real one, and it
says so.

=head1 THE ROW

Rows are hashrefs. C<kind> is C<metric>, C<span> or C<log>, defaulting to
C<log>.

    kind       metric, span or log
    t          event time, unix nanoseconds
    duration   nanoseconds, spans
    value      a number, metrics
    body       the text, logs
    severity   OTLP's 24-point scale, logs
    status     the OTLP status code, spans
    service    the service name
    trace_hi   the trace id, high 8 bytes
    trace_lo   the trace id, low 8 bytes
    span_id    the span id
    attrs      a hashref of attributes

There is one row shape for all three signals, which is what makes C<where>,
C<by> and C<count> one implementation each rather than three.

=head1 FUNCTIONS

=head2 run

    my $r = Punk::Observe::Exec::run($query, \@rows, \%opts);

Parses, plans and runs a query to completion.

Options:

=over 4

=item C<max_rows>

The planner's budget. A query estimated to scan more than this is refused
before it runs.

=item C<rows_available>

How many rows the planner should believe exist, for estimating against
C<max_rows>.

=item C<step>

Rows processed per step. Zero runs to completion in one step.

=item C<hard_max>

An absolute ceiling on rows scanned. Reaching it truncates the answer and sets
C<< meta->{truncated} >>.

=back

On failure:

    { ok => 0, stage => 'parse', error => "..." }

C<stage> is C<parse> or C<plan>. The error is the actionable message, not a
diagnostic.

On success:

    {
      ok    => 1,
      shape => 'rows',
      rows  => [ ... ],       # when shape is rows
      groups => [ ... ],      # when shape is series or scalar
      meta  => {
        scanned_rows  => 4096,
        scanned_bytes => 262144,
        truncated     => 0,
        degraded      => 0,
        exact         => 1,
        steps         => 1,
      },
    }

C<shape> is C<rows> for a query that yields rows, C<series> or C<scalar> for
one that aggregates, and C<buckets> for one that aggregates over time. A
C<rows> answer carries C<rows>, each with C<t> and whichever of C<body>,
C<service>, C<severity>, C<duration>, C<value>, C<trace_hi> and C<trace_lo>
the row has. An aggregated answer carries C<groups>, each with C<key>,
C<value> and C<count>.

A C<buckets> answer carries C<bucket_ns> and C<series>, one entry per group,
each with a C<key> and its C<points> in time order:

    {
      shape     => 'buckets',
      bucket_ns => '60000000000',
      series    => [
        { key => 'api', points => [ [ $t, $value, $count ], ... ] },
      ],
    }

C<$t> is the instant the bucket B<starts>, as a decimal string like every
other instant here. A bucket with no rows is absent rather than present and
zero - see L<Punk::Observe::Query/Bucketing over time>.

A query asking for more series than can be drawn is B<refused> rather than
answered short, because a chart that simply stops reads as a service that
went quiet. The refusal carries C<meta>, so how much was scanned before it
gave up is still visible.

B<Read C<meta> before trusting the answer.> C<truncated> means a budget cut it
short, C<degraded> means a source could not be read in full, and C<exact> is
false when a percentile was estimated rather than computed.

=head2 steps

    my $r = Punk::Observe::Exec::steps($query, \@rows, $step);

Drives the executor one step at a time and reports the cursor after each, so
that yielding can be observed rather than assumed.

    { cursors => [ 100, 200, 300, 300 ], steps => 4, scanned => 300, rows => 12 }

C<cursors> is the scan position after each step. With a step budget below the
row count it must have more than one entry, and its last value must equal
C<scanned>. Parse and plan failures are fatal here rather than returned.

=head2 join

    my $rows = Punk::Observe::Exec::join(\@left, \@right, $edge);

The cross-signal join: every row of C<@right> whose trace identifier appears in
C<@left>. Rows without C<trace_hi> and C<trace_lo> on either side are skipped.

C<$edge> is C<traces>, C<logs> or C<spans>, and anything else is fatal.

B<This is not a general relational join, deliberately.> There are exactly three
named edges, and they are the three that physically exist in the data:

    metric -> traces   the exemplar's trace id
    traces -> logs     LogRecord.trace_id
    traces -> spans    the same trace, already contiguous

A general join across three columnar stores with no shared key would need a
planner nobody can predict and a cost model nobody can debug. Refusing it is
the design.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Query>

=cut
