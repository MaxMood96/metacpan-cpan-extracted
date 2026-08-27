package Punk::Observe::Metric;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Metric - compressed metric chunks

=head1 SYNOPSIS

    use Punk::Observe::Metric;

    my $bits = Punk::Observe::Metric::d2b(40.5);
    my $back = Punk::Observe::Metric::b2d($bits);

    my $c = Punk::Observe::Metric::chunk(
        [ map { 1_000_000_000 * $_ } 1 .. 120 ],
        [ map { Punk::Observe::Metric::d2b($_ * 1.0) } 1 .. 120 ],
        0, 0);
    printf "%.2f bytes per point\n", $c->{bytes} / $c->{count};

=head1 DESCRIPTION

Metric points are stored with delta-of-delta timestamps and XOR-encoded values,
in chunks of 120 points or two hours, whichever comes first. The measured
compression, and the corpus each figure was measured on, is in
L<Punk::Observe/METRIC COMPRESSION>.

=head2 Values are bit patterns

A value crosses this boundary as the 64 bits of its IEEE double, never as a
number. Use L</d2b> and L</b2d> to convert.

That is not fussiness. A NaN payload, both infinities, negative zero and any
integer above 2^53 survive as exactly what they are through a bit pattern and
do not survive a round trip through an NV. The store holds bit patterns
throughout for the same reason.

=head2 Counter resets are detected when written

A cumulative monotonic counter that goes backwards means the process restarted,
and the chunk records that it happened. It is detected at write time rather
than at query time because rollups outlive raw points: a rate computed over a
rolled-up range containing an undetected reset is simply wrong, with nothing
left in the data to reveal it.

A gauge falling is not a reset and is not treated as one.

=head1 FUNCTIONS

=head2 d2b

    my $bits = Punk::Observe::Metric::d2b($double);

The bit pattern of a double, as a 64-bit value.

=head2 b2d

    my $double = Punk::Observe::Metric::b2d($bits);

The inverse.

=head2 bits_roundtrip

    my $out = Punk::Observe::Metric::bits_roundtrip([ $width, $value, ... ]);

Writes a flat list of (width in bits, value) pairs into the bit stream and
reads them back with the same widths.

    { values => [ ... ], bits => 96, err => 0 }

C<values> are what came back, C<bits> is the total written, and C<err> is
non-zero if the reader ran past the end.

=head2 sext

    my $signed = Punk::Observe::Metric::sext($value, $bits);

Sign-extends the low C<$bits> of a value, returning a signed integer. A 12-bit
-2047 that reads back as 2049 is one missing sign extension, and the symptom is
a point in the wrong place on a chart.

=head2 gorilla_roundtrip

    my $out = Punk::Observe::Metric::gorilla_roundtrip(\@timestamps, \@value_bits);

Encodes a series and decodes it back.

    { t => [...], v => [...], bits => 1920, bytes => 240, points => 120, err => 0 }

C<t> and C<v> are what came back, and must equal what went in. C<bytes> over
C<points> is the compression figure.

Timestamps are unix nanoseconds and values are bit patterns.

=head2 chunk

    my $out = Punk::Observe::Metric::chunk(\@t, \@value_bits, $is_int, $flags);

Builds one chunk and reads it back. C<$is_int> marks the series as
integer-valued. Points are added until the chunk is full - 120 points or a
two-hour span - and any beyond that are not.

    {
      t       => [...],   v     => [...],
      count   => 120,     bytes => 131,
      flags   => 0,       resets => 0,
      t_first => ...,     t_last => ...,
    }

C<count> is how many points the chunk took, which is not necessarily how many
were offered. C<resets> counts counter resets detected while writing.

B<An C<as_int> series is currently the weakest case, not the strongest.> A
small integer keeps its meaningful bits at the bottom, which is the opposite of
what XOR encoding exploits.

=head2 exemplars

    my $out = Punk::Observe::Metric::exemplars(\@specs);

Adds exemplars - the trace identifiers recorded alongside a metric point - and
reports which were kept. Each spec is a hashref taking C<t>, C<value>,
C<trace_hi>, C<trace_lo> and C<span_id>.

    { kept => [ { t, trace_hi, trace_lo, span_id }, ... ], refused => 3 }

The reservoir is bounded, so C<refused> counts those that did not fit. They are
counted rather than dropped quietly, because exemplars are the bridge from a
metric spike to the traces that caused it and a bridge with unexplained gaps is
worse than a narrow one.

=head2 postings

    my $out = Punk::Observe::Metric::postings([ \@ids, \@more_ids ]);

Encodes one or more sorted series-id lists into the gap-encoded postings format
and reads the first back.

    {
      first        => [ 1, 4, 9 ],
      sizes        => [ 12, 14 ],
      intersection => [ 4 ],
    }

C<first> is the first list decoded, C<sizes> the encoded size of each, and
C<intersection> the intersection of the first two, present only when at least
two lists were given. At least one list is required.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::SegIO>, L<Punk::Observe::Retain>

=cut
