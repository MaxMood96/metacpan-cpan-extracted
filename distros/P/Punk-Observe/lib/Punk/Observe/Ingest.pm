package Punk::Observe::Ingest;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

use File::Raw::JSON ();

our $VERSION = $Punk::Observe::VERSION;

our $MAX_RATIO = 20;

sub _inflate {
    my ($buf, $how, $max) = @_;
    my $class = $how eq 'gzip' ? 'IO::Uncompress::Gunzip'
                               : 'IO::Uncompress::Inflate';
    eval "require $class; 1" or return undef;

    my $z = $class->new(\$buf, Transparent => 0) or return undef;
    my $out = '';
    my $chunk;
    while (1) {
        my $n = $z->read($chunk, 65536);
        # A negative read is a stream error, and the commonest one is a body
        # that stops part way through. Returning what arrived so far would
        # make the C build and this one disagree, and would surface later as
        # a malformed OTLP payload with the real cause thrown away.
        return undef if !defined $n || $n < 0;
        last if $n == 0;
        $out .= $chunk;
        return undef if length($out) > $max;
    }
    return undef if $z->error;
    close $z;
    return $out;
}

1;

__END__

=head1 NAME

Punk::Observe::Ingest - the OTLP receiver

=head1 SYNOPSIS

    use Punk::Observe::Ingest;

    my $app = Punk::Observe::Ingest->new(
        max_body => 16 * 1024 * 1024,
        auth     => sub { my ($env) = @_; resolve_tenant($env) },
        on_batch => sub {
            my ($tenant, $signal, $body, $encoding) = @_;
            append_to_wal($tenant, $signal, $body);
        },
    )->to_app;

A PSGI application serving C</v1/traces>, C</v1/metrics> and C</v1/logs> over
C<application/x-protobuf> and C<application/json>, with optional C<gzip> or
C<deflate> request bodies.

PSGI rather than a set of Punk routes, so that the engine mounts into any
application: Punk's C<mount>, a bare C<plackup>, or L<Punk::Plugin::Observe>.
The three transports differ only in how bytes become records; everything after
that - the limits, the WAL append, the response - is one code path, and
sharing it is what keeps them from drifting into three behaviours.

C<to_app> hands back the receiver itself rather than a closure around it, so a
request reaches the decoder without a Perl frame in front of it.

=head1 METHODS

=head2 new

    Punk::Observe::Ingest->new(%options)

=over 4

=item C<max_body>

The largest request body accepted, in bytes. Default 16MB. Enforced from
C<CONTENT_LENGTH> B<before> the body is read, and again against the
decompressed size.

=item C<max_ratio>

How far a compressed body may expand, as a multiple of what arrived. Defaults
to C<$Punk::Observe::Ingest::MAX_RATIO>, which is 20.

=item C<max_records>

The per-batch record cap. Records over it are rejected and reported through
C<partial_success>; see L</STATUS CODES>. Unset means uncapped.

=item C<auth>

A coderef given the PSGI environment, returning a tenant identifier or undef.
See L</AUTHENTICATION>.

=item C<on_batch>

A coderef called as C<< ($tenant, $signal, $body, $encoding, $out) >> once per
accepted batch, where C<$body> is the decoded request body and C<$out> carries
C<records>, C<rejected>, C<dropped_bad_trace> and C<clamped_durations>. A false
return or a die is a C<503>.

=item C<grpc>

Dies. See L</GRPC>.

=back

=head2 to_app

The PSGI application: a coderef taking C<$env> and returning a PSGI response.

=head2 call

    $ingest->call($env)

The same thing as a method, for a caller that would rather mount the object.

=head1 STATUS CODES

These are a data-retention decision rather than a formality. An OTLP client
retries C<429>, C<502>, C<503> and C<504> and B<drops> everything else, so
getting them backwards means either losing telemetry or being retried forever.

    200  decoded and stored
    200  decoded, some records rejected - carries partial_success
    400  malformed body
    401  no ingest credential, where one is required
    404  not an OTLP path
    405  not a POST
    413  body over max_body, or a compressed body that cannot be inflated
         within it
    415  unsupported content type
    503  the store is unavailable - retryable, with Retry-After

A partial rejection is B<a 200 with a C<partial_success> body>, never a 4xx.
That is the channel that says "I kept 9,600 of these and rejected 400", and
L<Punk::OpenTelemetry>'s exporter reads and reports it. A 4xx would make the
client re-send the whole batch indefinitely at exactly the moment the server
is under pressure.

A batch that decodes to zero records is a C<200> with no append. An empty
frame would carry a nonsense timestamp span, and a reader pruning on it skips
exactly the wrong frames.

=head1 GRPC

B<Not available, deliberately.>

A gRPC call returns HTTP 200 even when it fails; the outcome lives entirely in
the C<grpc-status> and C<grpc-message> HTTP/2 trailers. PSGI has no trailer
channel, and Hyperman's HTTP/2 path has none either. An endpoint serving gRPC
without them would answer C<200> with no status, which an exporter reads as
complete success while every batch is discarded.

Passing C<< grpc => 1 >> therefore dies at construction, with the reason, so
the problem surfaces where somebody can act on it rather than as silent data
loss. Use the OTLP/HTTP endpoints.

=head1 COMPRESSION

C<gzip> and C<deflate> request bodies are accepted. The size limit applies to
the B<decompressed> body as well as the compressed one, bounded by
C<max_ratio> (default 20). Without that, a forty-kilobyte body expanding to
gigabytes is a denial of service that needs no exploit.

The two encodings are not the same stream and are not treated as one: C<gzip>
is gzip framing and C<deflate> is the zlib wrapper it names. A body labelled
as one and framed as the other is refused rather than guessed at, as is a body
that stops part way through - both are C<413>. Passing either on would turn a
mislabelled or truncated encoding into a malformed OTLP payload somewhere
further down, with the real cause thrown away.

Where the build found no zlib, the core decompressors do the work instead,
under the same ceiling.

=head1 AUTHENTICATION

C<auth> is a coderef given the PSGI environment, returning a tenant identifier
or undef. Undef is a C<401>, and so is a resolver that dies - a credential that
cannot be checked has not been checked.

It runs before anything is read or decoded, so an unauthenticated caller
cannot make the server spend on either.

With no C<auth>, every batch is accepted and attributed to the C<default>
tenant. That is the right default for a self-hosted install on a private
network, and it is the seam a multi-tenant deployment replaces - the engine
does not change, the resolver does.

The credential is read once, here, and no later code takes a tenant identifier
from anything a client can influence.

=head1 FUNCTIONS

The receiver itself is the object above. These are the decoding steps it is
built from, reachable on their own.

=head2 count

    my $out = Punk::Observe::Ingest::count($bytes, $signal, 'protobuf');

Decodes an OTLP protobuf batch and reports what is in it B<without building the
records>. This is what the receiving path does: decode, count, append, reply,
with no Perl value per record anywhere.

    { ok => 1, records => 600, dropped_bad_trace => 0, clamped_durations => 0 }

C<$signal> is C<traces>, C<metrics> or C<logs>. The encoding must be
C<protobuf>; anything else is fatal, as is an unknown signal.

To get the records themselves, use L<Punk::Observe::Decode/decode>.

=head2 decode_json

    my $out = Punk::Observe::Ingest::decode_json($doc, $signal);

Turns an already-parsed OTLP/JSON document into records. C<$doc> is what
C<File::Raw::JSON::file_json_decode> returned.

    { ok => 1, records => [ ... ], dropped_bad_trace => 0, clamped_durations => 0 }

The records have the shape in L<Punk::Observe::Decode/decode>, and must match
what the protobuf path produces for the same batch. Four rules make that true,
and each is a way telemetry silently goes missing when it is broken:

=over 4

=item 1. Keys are C<lowerCamelCase>. A C<snake_case> key parses as a message
with every field absent, which is proto3's own semantics: accepted, stored,
and empty.

=item 2. An identifier may be hex or base64, and both must land on the same
bytes. A trace whose ids are spelled two ways splits in half and presents as
data simply being missing.

=item 3. A 64-bit value is a B<string>. As a JSON number a nanosecond
timestamp loses its last digits.

=item 4. An enum may be its name or its number.

=back

=head2 decode_append

    my $r = Punk::Observe::Ingest::decode_append(
        $wal_path, $body, $signal, $encoding,
        $fsync_policy, $fsync_interval_ns, $want_records);

Decodes a batch and appends it to the write-ahead log in one pass. This is the
ingest path.

C<$body> is the wire bytes when C<$encoding> is C<protobuf>, and the document
C<File::Raw::JSON::file_json_decode> returned when it is C<json>.

    {
      ok       => 1,
      appended => 1,
      opened   => 1,
      n        => 480,       # records decoded
      frames   => 1,
      bytes    => 42880,
      fsyncs   => 0,
      records  => [ ... ],   # only when want_records is true
      dropped_bad_trace => 0,
      clamped_durations => 0,
    }

The decoder's record array and its arena go straight into the log's C<writev>.
Nothing is copied, and no C<SV> is built for a record unless C<$want_records>
asks for one - which is what an C<on_records> observer costs and why it is off
by default.

B<Read C<appended>, not only C<ok>.> C<ok> says the batch decoded; C<appended>
says the bytes reached the log, and C<errno> carries the system error when it
did not. A batch that decoded and was not stored must be refused to its
exporter, or the exporter drops the only other copy.

An empty batch is a success that writes nothing and does not create the file.

=head2 partial_success_pb

    my $body = Punk::Observe::Ingest::partial_success_pb($rejected, $message);

The OTLP C<partial_success> response body, in protobuf. C<$message> is
truncated to 40 characters.

This is the channel that says "I kept 9,600 of these and rejected 400", and
L<Punk::OpenTelemetry>'s exporter reads it. The JSON equivalent is built by the
receiver directly.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Decode>, L<Punk::Observe::WAL>,
L<Punk::Observe::Query>, L<Punk::OpenTelemetry>

=cut
