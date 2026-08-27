package Punk::Observe::View;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();
use Punk::Observe::Store ();
use Punk::Observe::Map ();
use Punk::Observe::SVG ();
use Punk::Observe::Flame ();
use Punk::Observe::Segment ();
use Punk::Observe::Dashboard ();
use Punk::Observe::Plot ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::View - the screens, and what they are given to render

=head1 SYNOPSIS

    use Punk::Observe::View;

    my $vars = Punk::Observe::View->page($store, 'logs', {
        q => 'log | where severity >= error', from => $t0, to => $t1 });

=head1 DESCRIPTION

One function per screen, each taking a store and the request's parameters and
returning the variables its template reads. Nothing here touches a request or
a response, which is what lets every screen be rendered and asserted without a
server.

=head2 The window is never unbounded

A page given no range reads the last hour. A page that read everything would
get slower every day it ran and eventually stop answering, and the first
person to notice would be the one who needed it during an incident.

=head2 An aggregate is a table

C<p95 by http.route> is one number per route. Drawing one number as a line is
a chart that lies about having a shape, so an aggregated answer renders as a
table of numbers with a bar per row, and only a row-shaped answer becomes a
line.

=head2 A record has no id, so the id is derived

There is no row identifier in telemetry and there should not be one: a record
is whatever the exporter sent. The identifier a detail page links to is
derived from the record - its timestamp and a hash of what it says - which
makes the page a lookup rather than an offset into a file that compaction may
have moved.

=head2 Nanoseconds are strings

A unix nanosecond timestamp passes 2^53, so the split into seconds and the
fraction is done on the digits. Dividing by a billion first is the bug that
renders two lines a microsecond apart at the same instant.

=head1 FUNCTIONS

=head2 page

    my $vars = Punk::Observe::View->page($store, $name, \%params);

Renders one screen's variables. C<$name> is C<status>, C<logs>, C<record>,
C<trace>, C<map>, C<metrics>, C<explore> or C<alerts>. C<%params> carries
C<q>, C<from>, C<to> and whatever else that screen reads.

The nav's C<here_*> flag is set from the page name rather than from the path,
because a mount can be anywhere and the path is not the page.

=head2 severity_name

    my $name = Punk::Observe::View::severity_name(17);   # 'error'

OTLP's twenty-four point scale in the six bands it is defined in. The number
is what is stored and compared; the name is for the person reading.

=head2 span_kind_name

    my $name = Punk::Observe::View::span_kind_name(2);   # 'server'

=head2 fmt_time

=head2 fmt_date

=head2 fmt_dur

=head2 trace_hex

    my $id = Punk::Observe::View::trace_hex($hi, $lo);

A trace identifier as the 32 hex characters everyone else spells it with.

B<The id in the URL and the id on the screen have to be the same id.> The
list once showed eight hex characters derived from the high half by a modulo
and linked to C<< <hi>-<lo> >> in decimal, so what you read was not a prefix
of what you clicked, was not what a C<traceparent> header carries, and could
not be pasted anywhere.

=head2 trace_id

    my ($hi, $lo) = Punk::Observe::View::trace_id($text);

A trace identifier out of whatever was pasted, or an empty list when the text
is not one - which is the signal to treat it as a search term instead.

Two spellings are in circulation and a search box has to take both: this UI's
own links carry C<< <hi>-<lo> >> in decimal, because that is what the record
holds, and every other tool spells the same id as 32 hex characters. Somebody
pasting the second into a box that only understood the first gets "no traces",
which reads as "that trace is gone".

An all-zero id is not an identifier. OTLP says so, and it is also what a
truncated paste looks like.

=head2 chart_x

    my $x = Punk::Observe::View::chart_x($t, $from, $to, $width);

The x of a point as a fraction of the window, in pixels.

The subtraction is on B<integers>. Writing C<< ($t - $from) / ($to - $from) >>
in Perl converts two nanosecond instants to doubles before the difference is
taken, which loses their low digits - far under a pixel on any chart, and the
same mistake the rest of this distribution goes out of its way to avoid.

=head2 chart_y

    my $y = Punk::Observe::View::chart_y($value, $lo, $hi, $height);

The y of a value, flipped: y grows downward in SVG and upward on a chart. A
zero range does not divide by zero - a flat series is a real case, and it
draws as a flat line rather than as nothing.

=head2 fmt_bytes

=head2 fmt_count

Formatters for a timestamp, a date, a duration, a byte count and a thousands
separator. C<fmt_dur> never emits an exponent.

=head2 url_esc

Percent-encoding for a query string. Not HTML escaping, which the template
does afterwards, and not the same job: a C<+> that survives as a plus is a
space by the time the form comes back.

=head2 record_id

=head2 record_matches

The derived identifier for one record, and the test that a record is the one
an identifier names.

=head2 chart_x

=head2 chart_y

    my $x = Punk::Observe::View::chart_x($t, $from, $to, $width);
    my $y = Punk::Observe::View::chart_y($v, $lo, $hi, $height);

A point's position in a chart box. C<chart_x> takes nanosecond instants,
which is why it exists: the subtraction that projects one is on values a
double cannot hold, so doing it in Perl is wrong by whole pixels at the right
of any real window - and an exemplar drawn with its own arithmetic is a dot
that does not sit on the point it marks.

=head2 range_vars

    my %vars = Punk::Observe::View::range_vars(\%params, $active);

The time-range control's own variables: C<range> (the active key), C<ranges>
(the list the control draws, each with C<key>, C<label> and C<current>) and
C<range_all>, which is true only for the unbounded range - an empty state has
no wider range to suggest there, and must not suggest one.

=head2 min_duration

    my ($ns, $bound) = Punk::Observe::View::min_duration($text);

The duration box, as a number of nanoseconds and the end it bounds.
B<Three answers, not two.> An empty box returns the empty list, which is not
a filter. A duration returns its nanosecond count and either C<min> or
C<max>. Text that was meant to be a duration and is not returns a single
C<undef>, so the caller can say so.

That third case is why this is not a regular expression at the call site. The
box used to accept digits and drop everything else, so typing the placeholder's
own words back at it removed the filter without a word, and the page answered
with the whole unfiltered table - the one outcome that looks like an answer.

A bare number is milliseconds, which is what the field has always meant. A
unit overrides it, and the units are the query language's own, so C<500ms>
here and C<duration E<gt> 500ms> in a query cannot disagree.

C<E<gt>> and C<E<gt>=> bound the slow end, C<E<lt>> and C<E<lt>=> the fast
one, and no operator means the slow end - which is what the box meant before
it could be asked the other question. "Faster than 100ms" is a question about
the same column as "slower than 100ms", and there is no reason one direction
should be askable and the other not.

B<The bound is inclusive either way.> A strict bound differs from an inclusive
one by a single nanosecond, which is not a distinction this box can usefully
make. An exact comparison belongs in the query language, which has one:
C<traces | where duration E<lt> 100ms>.

=head2 window

    my ($from, $to, $range) = Punk::Observe::View::window(\%params);

The range a page reads, and the key naming it. Three sources, most specific
first: an explicit C<from>/C<to> pair - which is what the brush writes into
the URL when a chart is dragged - then a named C<range>, then the default of
the last hour.

C<all> returns C<undef> for both bounds, which is the store's own "no limit",
so nothing downstream has to special-case it.

B<The default is bounded and the control is not optional.> A page that reads
everything gets slower every day it runs, so an hour is right to start from -
but a bounded default with no way to widen it says "nothing matched" to
somebody whose data is from this morning, and that reads as "there is no
data".

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Store>, L<Punk::Plugin::Observe>

=cut
