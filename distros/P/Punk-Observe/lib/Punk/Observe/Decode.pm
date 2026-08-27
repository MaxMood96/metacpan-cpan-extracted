package Punk::Observe::Decode;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Decode - OTLP protobuf, read as records

=head1 SYNOPSIS

    use Punk::Observe::Decode;

    my $out = Punk::Observe::Decode::decode($bytes, 'traces');
    for my $rec (@{ $out->{records} }) {
        printf "%s %s %s\n", $rec->{t}, $rec->{duration}, $rec->{body};
    }

    my $wire = Punk::Observe::Decode::pb_fields($bytes);
    printf "field %d, wire type %d\n", $_->{field}, $_->{wire}
        for @{ $wire->{fields} };

=head1 DESCRIPTION

The reader that turns an OTLP export request into records. Two levels are
exposed: the generic protobuf walk, which knows the wire format and nothing
about OpenTelemetry, and the OTLP decoder above it, which knows what the field
numbers mean.

Field numbers come from L<Punk::OpenTelemetry>'s C<otel_proto.h> by dependency
rather than by being copied. Two sources of truth for a field number is the one
thing that must not happen here: a client writing field 9 and a server reading
field 9 as something else produces plausible wrong data, silently, with no
error anywhere.

Nothing here is a transport. To receive OTLP over HTTP, see
L<Punk::Observe::Ingest>.

=head1 FUNCTIONS

=head2 pb_fields

    my $out = Punk::Observe::Decode::pb_fields($bytes);

Walks one protobuf message and returns a hashref describing its top-level
fields, with no schema applied. Useful for looking at a payload that will not
decode, where the question is what actually arrived.

    {
      fields => [ { field => 1, wire => 2, bytes => "..." }, ... ],
      err    => 0,
      errstr => 'ok',
    }

Every entry carries C<field> (the field number) and C<wire> (the wire type: 0
varint, 1 fixed64, 2 length-delimited, 5 fixed32). Depending on the wire type
one more key is present:

    0   varint    the value, and int32 as the sign-extended 32-bit reading
    1   fixed64   the raw bits, and double as the same eight bytes as a float
    2   bytes     the payload
    5   fixed32   the value

The walk stops at the first malformed field, so C<fields> is the prefix that
parsed. C<err> is zero on a clean read, and C<errstr> is one of C<ok>,
C<truncated>, C<varint too long>, C<unsupported wire type> or
C<field number 0>.

A 64-bit value crosses as a number where that is lossless and as a decimal
string where it is not. See L<Punk::Observe/TIMESTAMPS>.

=head2 decode

    my $out = Punk::Observe::Decode::decode($bytes, $signal);

Decodes an OTLP export request into records. C<$signal> is C<traces>,
C<metrics> or C<logs>, and naming anything else is fatal.

    {
      ok                => 1,
      records           => [ ... ],
      dropped_bad_trace => 0,
      clamped_durations => 0,
    }

C<ok> is false when the payload did not parse, in which case C<records> is
empty. An empty message is B<not> a failure: proto3 says every field of an
empty message is absent, so a zero-length body decodes to zero records and
C<ok> is true.

C<dropped_bad_trace> counts spans refused for an all-zero trace identifier, and
C<clamped_durations> counts spans whose end preceded their start. Both are
reported rather than hidden, because either one arriving steadily means the
instrumentation upstream is wrong.

Each record is a hashref:

    kind          1 metric, 2 log, 3 span
    t             event time, unix nanoseconds
    duration      nanoseconds, 0 where the signal has none
    severity      OTLP's 24-point scale, 0 where absent
    flags         record flags
    span_kind     OTLP span kind
    status        OTLP status code
    trace_hi      the trace id, high 8 bytes
    trace_lo      the trace id, low 8 bytes
    span_id       the span id
    parent_id     the parent span id, 0 for a span with none
    value         a metric value, as a number or an integer
    value_is_int  whether value came off the wire as an integer
    body          the log body, empty string where absent
    attrs         a hashref of the flattened attributes
    attr_order    the attribute keys in canonical order

C<attrs> and C<attr_order> carry the same keys. The order matters and is not
the hash's: it is the canonical sort that the content-derived series id is
built from, which is what lets separate workers agree on an id without
coordinating.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Ingest>, L<Punk::OpenTelemetry>

=cut
