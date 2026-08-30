package Punk::Observe::Plot;

use 5.010;
use strict;
use warnings;

# The XS calls into every one of these BY NAME, so nothing in this file
# mentions them and all of them have to be loaded anyway.
use Punk::Observe ();
use Punk::Observe::Store ();
use Punk::Observe::View ();    # fmt_time, for the bucket table
use File::Raw::JSON ();        # the serialiser encode() goes through

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Plot - query results as chart figures

=head1 SYNOPSIS

    use Punk::Observe::Plot;

    my $fig = Punk::Observe::Plot::timeseries($result, unit => 'lines');
    $vars{volume_plot} = Punk::Observe::Plot::encode($fig);

=head1 DESCRIPTION

Turns what the executor returns into a figure the read interface draws, and
encodes it for the page.

Charts are drawn in the browser. The waterfall, the flamegraph and the service
map are still laid out here and arrive complete in the markup, because a trace
that exists only after a script runs is a trace that does not exist in a saved
page or an email to a colleague. A chart of a hundred thousand points is a
different problem, and it is the one this module hands over.

=head2 Colour is named by role

A figure never carries a colour value. It carries C<series:0>, C<sev:error>
and the like, resolved in the browser against the stylesheet's custom
properties at the moment of drawing.

That is what makes one figure correct in both themes - the server does not
know which theme the reader is in, and cannot know they are about to change it
- and it is what keeps the categorical ramp measured for perceptual distance
under colour vision deficiency rather than replaced by the plotting library's
own defaults.

=head2 A gap is a gap

The executor omits a bucket with nothing in it. A line chart joins the points
it is handed, so a quiet minute would be drawn as a straight line across it -
a claim about traffic that did not happen, and one that hides exactly the
outage somebody opened the page to find.

So a missing bucket becomes an explicit hole. C<zero_fill> substitutes zero
instead, and is only correct for a count: a bucket with no rows genuinely saw
nothing arrive. For a percentile there is no value, and drawing nought would
put a latency cliff on the chart that never occurred.

=head1 FUNCTIONS

=head2 ms

    my $millis = Punk::Observe::Plot::ms($nanoseconds);

An instant, narrowed to milliseconds for a chart axis.

A chart axis is a number and an instant is a decimal string, so the narrowing
happens here and nowhere else. Milliseconds fit a double with three orders of
magnitude to spare, and are finer than any screen resolves. The arithmetic is
done by taking digits rather than by dividing, because dividing the
nanoseconds rounds them before the division and the error lands in the digits
the chart is drawn from.

The exact instant travels beside the point, and every range the reader sends
back is recomputed from it in decimal.

=head2 timeseries

    my $fig = Punk::Observe::Plot::timeseries($buckets_result, %opt);

One line per series from a C<buckets> answer. C<unit> labels the y axis,
C<zero_fill> fills empty buckets with zero, C<fill> stacks the series, and
C<kind> is C<line>, C<area> or C<bar> and decides what shape the same numbers
take - C<area> implies C<fill>, and bars stack rather than overlay, because
two series of bars drawn on top of each other hide one of them and the reader
cannot tell that is what happened. C<log> asks for a logarithmic y axis - honoured only where no point is zero or
negative, since a log axis silently drops those and the gaps read as missing
data.

=head2 severity_bars

    my $fig = Punk::Observe::Plot::severity_bars($buckets_result, %opt);

Stacked bars per bucket, coloured from the severity ramp rather than the
categorical one, so a reader who has learnt that error is red does not have to
relearn it here. A label outside the six known severities still gets a bar: a
row dropped for being unexpected is a row the operator cannot see, on the
screen they opened to find it.

=head2 bars

    my $fig = Punk::Observe::Plot::bars($groups, %opt);

A horizontal bar per group. Horizontal because the labels are service names
and route templates, which a vertical chart turns into diagonal text.

=head2 latency_scatter

    my $fig = Punk::Observe::Plot::latency_scatter($traces, %opt);

Duration against time, one point per trace, split into failing and succeeding.
Each point carries its trace identifier, so a click opens that trace.

=head2 service_flow

    my $fig = Punk::Observe::Plot::service_flow($edges, %opt);

The service graph as a flow diagram, where the width of a band is the number
of calls.

Drawn beside the node graph rather than instead of it, because they answer
different questions: the map says what calls what, this says how much. Edge
width on the map carries volume too, and it compares two edges well and eight
badly - a four-pixel stroke against a six-pixel one does not read as three to
two.

An edge that closes a cycle is B<omitted>. A flow diagram places nodes by
following the flow, and an edge that returns has no position in that order.
Those edges appear on the map, dashed, which is where a cycle belongs -
services calling each other back is a real topology, not a fault.

Returns C<undef> when there is nothing with a positive count to draw.

=head2 ingest_figure

    my $json = Punk::Observe::Plot::ingest_figure($store, $from, $to);

Logs and spans arriving over time, stacked, encoded for a page.

Metric points are excluded: C<metric> takes a name, so there is no query for
"every metric point", and choosing one name to stand for the rest would give a
chart whose height depended on which name was chosen.

Every other figure on the overview is a total, and a total cannot answer the
question that screen exists for: is this normal. A receiver that stopped being
sent anything an hour ago looks, in a column of totals, exactly like one that
is busy.

Three queries, because a source is one signal. The language has no C<all>, and
inventing one to save two aggregate scans would be a grammar change made to
shorten a sparkline.

Counts are zero-filled: a bucket with nothing in it genuinely received
nothing, which is the whole point of the chart.

=head2 gauge

    my $fig = Punk::Observe::Plot::gauge(value => $n, max => $cap, title => '...');

A dial against a limit, or C<undef> when there is no limit to draw against - a
gauge with no maximum is a number in a circle, and the circle implies a bound
that does not exist.

=head2 alert_timeline

    my $fig = Punk::Observe::Plot::alert_timeline($events, to => $end);

A band per state, per series, along time. Also accepts the alert seam's whole
answer, taking C<events> and C<to> out of it.

What a table of current state cannot say is B<how long> and B<how often>. A
row reading C<firing> answers neither "since when" nor "for the third time
today", and both change what somebody does about it: a rule that flaps every
twenty minutes and a rule that broke once an hour ago look identical in a
table and nothing alike here.

Bands come from recorded transitions - C<alert_events> in the shipped schema -
and never from inference. One drawn from current state alone would be a
straight line claiming the present has always been the case.

The last band runs to C<to>, or to now, because a state nobody has left is
still in force. Ending it at the last transition would draw an ongoing
incident as an instant that finished when it started.

One legend entry per state rather than per band, or a rule that flapped twelve
times gets twelve identical legend rows.

=head2 timeline_figure

    my $json = Punk::Observe::Plot::timeline_figure($seam);

L</alert_timeline>, encoded for a page.

The convention across this module is that a name ending in C<_figure> hands
back JSON ready to embed and everything else hands back the structure. Pointing
a template at the structure builder puts C<HASH(0x...)> in the markup, which is
a chart that renders as nothing and reports no error.

=head2 result_figure

    my $json = Punk::Observe::Plot::result_figure($result);

A query result drawn as whatever shape it turned out to be, encoded for a
page. An empty string where there is nothing to draw.

C<explore> is one box over every signal, so it cannot know in advance what
shape an answer will take. It branched on rows-versus-groups, which was every
shape there was until C<bucket> added a third - and a bucketed answer carries
C<series> and no C<groups>, so it took the groups branch, found nothing there
and rendered a heading over an empty panel. Dispatching on the shape in one
place means the next shape is added in one place.

Nothing is zero-filled here, because the caller has not said which aggregate
produced the answer and a zero is right for a count and invented for a
percentile.

=head2 bucket_vars

    Punk::Observe::Plot::bucket_vars($vars, $result);

Fills a page's variables from a C<buckets> answer: C<series_plot> for the
chart, and C<bucket_rows> for the table under it.

A chart answers "what shape" and refuses to answer "what exactly" - reading a
value off a line is guessing, and the exact figure is what goes into a ticket.
So a bucketed answer contributes both.

Rows are newest first, because on a screen opened during an incident the
bucket that matters is the last one. They are capped, and C<bucket_truncated>
carries the full count when they were, so a shortened table says so rather
than looking complete.

Values are formatted for reading rather than for precision: a whole number
prints whole however large, and nothing comes out in exponential form. This is
deliberately not L<Punk::Observe::SVG/fmt>, which looks like the right tool
and is a B<coordinate> formatter - it clamps at a billion and rounds to two
decimals, so a large count and a sub-millisecond latency both come back wrong
and silently.

=head2 bucket_for

    my $width = Punk::Observe::Plot::bucket_for($from, $to);

The bucket width to use over a window, as a duration the query language
accepts.

A fixed width is wrong at both ends - a minute over thirty days is
forty-three thousand bars and is refused, an hour over fifteen minutes is one
bar - and nobody wants to configure it, so it is computed. The result is drawn
from a ladder of round numbers rather than from the arithmetically ideal
C<span/80>, because "each bar is five minutes" is something a reader can hold
and "each bar is 3m17s" is not.

=head2 volume_figure

    my $json = Punk::Observe::Plot::volume_figure($store, $query, $from, $to);

The log volume histogram: the reader's own query with a bucket stage added,
stacked by severity.

Built from their query rather than from a fresh one, so a filter typed into
the box narrows the chart and the table together - a chart of everything above
a table of errors is two answers on one screen with nothing to say which is
which. Returns C<undef> where their query already aggregated, since appending
a second aggregate is a different question and usually a parse error.

=head2 encode

    my $json = Punk::Observe::Plot::encode($fig);

The figure as JSON, for a C<< <script type="application/json"> >> block.

C<< </ >> is escaped, because that sequence ends the element early whatever
the browser thinks the content type is. The escape leaves the JSON valid and
the string identical.

=head1 SEE ALSO

L<Punk::Observe::View>, which builds the pages these appear on, and
L<Punk::Observe::Query> for the C<bucket> stage that produces the answers
plotted here.

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION.

This is free software, licensed under the Artistic License 2.0.

=cut
