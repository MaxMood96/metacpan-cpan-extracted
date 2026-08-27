package Punk::Observe::SegIO;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::SegIO - one segment carrying all three signals

=head1 SYNOPSIS

    use Punk::Observe::SegIO;

    Punk::Observe::SegIO::write_all('seg.po', {
        metrics => [ { series => 1, points => [ 1_000, 40.5, 2_000, 41.0 ] } ],
        logs    => [ [ 'connection refused', 'retrying' ] ],
        spans   => [ { trace_hi => 1, trace_lo => 2, span_id => 10,
                       start => 1_000, end => 501_000, service => 1 } ],
    }) or die 'write failed';

    my $out = Punk::Observe::SegIO::read_all('seg.po');
    printf "%d regions\n", $out->{regions};

=head1 DESCRIPTION

A segment holds regions, and each signal's structures are one of them: metric
chunks, log blocks with their filters, the span array, the trace summaries.
This is where the three storage layouts meet a disk together.

Reading is through a memory mapping, and the span array is read straight out of
it with no copy: the on-disk layout is the in-memory layout, which is what
makes opening a segment cheap enough to do per query.

=head2 Regions

    1  records      7  log directory
    2  arena        8  log blocks
    3  symbols      9  spans
    4  metric series  10  trace id index
    5  metric chunks  11  trace summaries
    6  exemplars      12  service graph

A region that was never written is simply absent, and a reader asking for one
gets nothing rather than an error. That is what lets a segment carry one signal
or all three without a separate format for each.

=head1 FUNCTIONS

=head2 write_all

    my $ok = Punk::Observe::SegIO::write_all($path, \%spec);

Writes one segment. Returns true on success.

C<%spec> takes three optional keys, and any combination of them:

=over 4

=item C<metrics>

An arrayref of hashrefs, each taking C<series> (the series id) and C<points> (a
flat list of timestamp, value, timestamp, value). Values are given as numbers
here and stored as bit patterns.

=item C<logs>

An arrayref of arrayrefs, one per block, each holding the line bodies. Blocks
are timestamped and sealed as they are written.

=item C<spans>

An arrayref of span specs: C<trace_hi>, C<trace_lo>, C<span_id>, C<parent>,
C<start>, C<end>, C<service> and C<status>. Trace summaries are built and
written alongside them.

=back

A seed record is always written so that the segment has a time span, which is
what pruning reads.

=head2 read_all

    my $out = Punk::Observe::SegIO::read_all($path);

Maps a segment and reads every signal back out. Returns undef when the file
will not open.

    {
      regions    => 6,
      metrics    => [ { series, count, points => [ t, v, ... ] }, ... ],
      metrics_ok => 1,
      logs       => [ [ 'connection refused', ... ], ... ],
      logs_ok    => 1,
      spans      => [ { trace_hi, trace_lo, span_id, start, duration,
                        service }, ... ],
      spans_ok   => 1,
      summaries  => [ { trace_hi, duration, spans }, ... ],
    }

Each signal's keys are present only where that region exists. Metric points
come back as a flat list of timestamp and value, values converted back from
their stored bit patterns.

Up to 64 metric chunks and 64 log blocks are returned.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Segment>, L<Punk::Observe::Metric>,
L<Punk::Observe::Log>, L<Punk::Observe::Trace>

=cut
