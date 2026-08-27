package Punk::Observe::WAL;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::WAL - the write-ahead log

=head1 SYNOPSIS

    use Punk::Observe::WAL;

    my $r = Punk::Observe::WAL::append(
        '/var/lib/observe/wal/000001.wal',
        [ { t => '1774224000000000000', kind => 3, body => 'POST /pay' } ],
        1,          # fsync policy: interval
        200_000_000 # the interval, in nanoseconds
    );

    my $replay = Punk::Observe::WAL::replay($bytes);
    warn "lost $replay->{bytes_truncated} bytes at the tail"
        if $replay->{bytes_truncated};

=head1 DESCRIPTION

Ingested telemetry is appended here before a request is answered, so what a
C<200> means depends on the fsync policy in force. That contract is stated in
L<Punk::Observe/DURABILITY> rather than left to be inferred.

A frame is a header, an array of records and the arena their variable-length
bytes live in, written in one C<writev> and covered by a CRC-32C.

=head2 A ragged tail is a success

A log being appended to is supposed to have an unfinished end, and a crash
guarantees one. Replay reads frames until one fails its magic, its bounds or
its checksum, then stops and reports how many bytes it could not read.

That is not an error. Refusing to start because the last frame is torn would
turn "the final few milliseconds did not make it" into "the service will not
come up" - the data was already lost, and the outage would be added on top.

A frame whose checksum fails stops replay B<at that frame> rather than being
skipped, because the length that would locate the next frame came from the same
untrusted bytes.

=head2 A frame carries the whole record

Every field of a record is stored: the severity, the trace and span ids, the
duration, the metric value and the attribute block, not only the timestamp and
the body. Until the store had a reader that was easy to get wrong and
impossible to notice - the append succeeded, the replay succeeded, and the
records came back with zeros in exactly the fields a query filters on.

That is also why the frame version is checked. A frame written by a version
this build does not know stops replay with C<reason> C<version> rather than
being read as records: the bytes are intact and mean something else, and
reading them anyway produces telemetry that is quietly wrong rather than
visibly absent.

=head1 FSYNC POLICIES

Passed as an integer wherever a policy is taken:

    0  never      the operating system decides when to flush
    1  interval   flushed on a timer; the default
    2  always     flushed before the call returns

=head1 FUNCTIONS

=head2 crc32c

    my $sum = Punk::Observe::WAL::crc32c($bytes);

The CRC-32C of a string, as an unsigned integer. Uses the hardware instruction
where the build found one.

=head2 crc32c_table

    my $sum = Punk::Observe::WAL::crc32c_table($bytes);

The same checksum computed from the software table, with the hardware path
forced off. It must agree with L</crc32c> on every input: a log written on a
machine with the instruction is replayed on machines without it.

=head2 crc32c_hardware

    my $bool = Punk::Observe::WAL::crc32c_hardware();

Whether this build checksums with a hardware instruction.

=head2 hdr_size

    my $bytes = Punk::Observe::WAL::hdr_size();

The size of a frame header, in bytes.

=head2 append

    my $r = Punk::Observe::WAL::append($path, \@records, $policy, $interval_ns);

Opens C<$path>, appends one frame holding C<@records>, and closes it.

A record is the hashref L<Punk::Observe::Decode/decode> produces, and all of it
is stored: C<t> (unix nanoseconds), C<kind> (1 metric, 2 log, 3 span), C<body>,
C<severity>, C<flags>, C<span_kind>, C<status>, C<duration>, C<value>,
C<trace_hi>, C<trace_lo>, C<span_id>, C<parent_id> and C<attrs>. What comes
back from C<replay_bodies> is what went in.

Attributes are re-encoded in canonical order rather than in hash order, because
the content-derived series id in L<Punk::Observe::Segment> is computed over
those bytes: the same labels written in two orders would otherwise be two
series. Their types are preserved too - a numeric attribute stored as a string
would make C<< where http.response.status_code >= 500 >> a string comparison,
which sorts 99 above 500.

The ingest path does not call this. It calls
L<Punk::Observe::Ingest/decode_append>, which writes the decoder's own record
array without building an C<SV> for it; this is the surface for a caller that
already has records in hand.

    { ok => 1, frames => 1, bytes => 312, fsyncs => 0 }

C<frames>, C<bytes> and C<fsyncs> are the counts for this handle. On failure
C<ok> is false and C<errno> carries the system error as a string. Opening the
path is fatal if it fails.

=head2 append_many

    my $r = Punk::Observe::WAL::append_many($path, $n, $policy, $interval_ns);

Appends C<$n> single-record frames through B<one> open handle, so that a policy
can be observed across frames rather than one at a time. Returns
C<< { ok, frames, fsyncs } >>. The point is C<fsyncs>: under C<always> it
tracks the frame count, and under C<interval> it does not.

=head2 seal

    my $ok = Punk::Observe::WAL::seal($path, $total_records);

Writes the sealing frame that marks a log complete and records how many records
it should hold. Replay stops cleanly at a seal and reports C<sealed>.

=head2 replay

    my $r = Punk::Observe::WAL::replay($bytes);

Replays a log image and reports what was readable.

    {
      frames          => 12,
      records         => 480,
      bytes_ok        => 40960,
      bytes_truncated => 0,
      sealed          => 0,
      reason          => 'eof',
    }

C<bytes_truncated> is the size of the unreadable tail, and it is the number
worth watching: a log that truncates on every restart means the durability
policy is wrong and somebody should be able to see that.

C<reason> says why replay stopped: C<eof> (the log ended cleanly), C<short> (a
frame ran past the end), C<crc> (a checksum failed), C<magic> (a frame header
was not one), C<version> (a frame this build cannot read) or C<sealed>.

=head2 replay_bodies

    my $records = Punk::Observe::WAL::replay_bodies($bytes);

Replays and returns the records themselves, in the shape
L<Punk::Observe::Decode/decode> produces - so a replayed record and a freshly
decoded one are indistinguishable, which is what lets
L<Punk::Observe::Store> query an unsealed log without a second row shape.

Only frames within C<bytes_ok> are returned, so a torn tail contributes
nothing. A sealing frame ends the walk, and so does a frame whose version this
build does not know.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Ingest>, L<Punk::Observe::Segment>

=cut
