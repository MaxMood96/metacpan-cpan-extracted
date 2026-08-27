package API::Docker::Role::HTTP;
# ABSTRACT: HTTP transport role for Docker Engine API
our $VERSION = '0.003';
use Moo::Role;
use IO::Socket::UNIX;
use IO::Socket::INET;
use JSON::MaybeXS qw( encode_json decode_json );
use Carp qw( croak shortmess );
use Log::Any qw( $log );
use API::Docker::Error::Stream;
use namespace::clean;


requires 'host';
requires 'api_version';

# Docker stream frame types, indexed by the first byte of the frame header.
my @STREAM_TYPE = qw( stdin stdout stderr );

# A field name is an RFC 9110 token and nothing else. Anything outside this
# set -- CR, LF, a space, a colon -- is rejected rather than stripped; see
# _assert_header_name.
my $HEADER_NAME = qr/\A[0-9A-Za-z!#\$%&'*+.^_`|~-]+\z/;

has _socket => (
  is      => 'lazy',
  clearer => '_clear_socket',
);

sub _build__socket {
  my ($self) = @_;
  my $host = $self->host;

  if ($host =~ m{^unix://(.+)$}) {
    my $path = $1;
    $log->debugf("Connecting to Unix socket: %s", $path);
    my $sock = IO::Socket::UNIX->new(
      Peer => $path,
      Type => SOCK_STREAM,
    );
    croak "Cannot connect to Unix socket $path: $!" unless $sock;
    return $sock;
  }
  elsif ($host =~ m{^tcp://([^:]+):(\d+)$}) {
    my ($addr, $port) = ($1, $2);
    $log->debugf("Connecting to TCP %s:%s", $addr, $port);
    my $sock = IO::Socket::INET->new(
      PeerAddr => $addr,
      PeerPort => $port,
      Proto    => 'tcp',
    );
    croak "Cannot connect to $addr:$port: $!" unless $sock;
    return $sock;
  }
  else {
    croak "Unsupported host format: $host (expected unix:// or tcp://)";
  }
}

sub _reconnect {
  my ($self) = @_;
  $self->_clear_socket;
  return $self->_socket;
}

sub _request {
  my ($self, $method, $path, %opts) = @_;

  my $version = $self->api_version;
  my $url_path = defined $version ? "/v$version$path" : $path;

  # Kept before the query string is appended: it names the request in an
  # error message, and the query string is where /build carries buildargs,
  # which can hold credentials and have no business in an exception.
  my $endpoint = $method . ' ' . $url_path;

  my $body_content = '';
  my $content_type = 'application/json';
  if ($opts{raw_body}) {
    $body_content = $opts{raw_body};
    $content_type = $opts{content_type} // 'application/x-tar';
  }
  elsif ($opts{body}) {
    $body_content = encode_json($opts{body});
  }

  if ($opts{params}) {
    my @pairs;
    for my $k (sort keys %{$opts{params}}) {
      my $v = $opts{params}{$k};
      next unless defined $v;
      if (ref $v eq 'HASH') {
        $v = encode_json($v);
      }
      push @pairs, _uri_encode($k) . '=' . _uri_encode($v);
    }
    $url_path .= '?' . join('&', @pairs) if @pairs;
  }

  $log->debugf("%s %s", $method, $url_path);

  my $request = "$method $url_path HTTP/1.1\r\n";
  $request .= "Host: localhost\r\n";
  $request .= "Connection: close\r\n";
  $request .= "User-Agent: API-Docker\r\n";

  if ($body_content) {
    $request .= "Content-Type: $content_type\r\n";
    $request .= "Content-Length: " . length($body_content) . "\r\n";
  }

  if ($opts{headers}) {
    for my $h (sort keys %{$opts{headers}}) {
      # The name is validated before the value is even looked at: a name that
      # cannot go on the wire is a caller bug whether or not the header ends
      # up being sent.
      $self->_assert_header_name($h);
      my $v = $opts{headers}{$h};
      next unless defined $v;
      $v =~ s/[\r\n]//g;
      $request .= "$h: $v\r\n";
    }
  }

  $request .= "\r\n";
  $request .= $body_content if $body_content;

  my $sock = $self->_reconnect;
  print $sock $request;

  my $response = $self->_read_response($sock);
  close $sock;
  $self->_clear_socket;

  my ($status_code, $status_text, $headers, $body) = @$response;

  $log->debugf("Response: %s %s", $status_code, $status_text);

  if ($status_code >= 400) {
    my $error_msg = $body;
    if ($body && $body =~ /^\s*[\{\[]/) {
      eval {
        my $data = decode_json($body);
        # Docker answers with {"message":...}. Podman answers a failed push
        # with the stream shape instead -- {"errorDetail":{"message":...},
        # "error":...} and no message key at all -- so without these two
        # fallbacks the whole JSON object became the croak text (karr #13).
        my $detail = ref $data->{errorDetail} eq 'HASH'
          ? $data->{errorDetail}{message} : undef;
        $error_msg = $data->{message} // $detail // $data->{error} // $body;
      };
    }
    croak "Docker API error ($status_code): $error_msg";
  }

  if ($status_code == 204 || !defined($body) || $body eq '') {
    return undef;
  }

  # The framed endpoints (logs, attach, exec/start) carry arbitrary bytes
  # that must not be mistaken for JSON -- a TTY container printing a JSON
  # line would otherwise come back decoded.
  return $body if $opts{raw};

  # Streaming endpoints (/build, /images/create, /images/*/push) always
  # return an ArrayRef of events, even when the stream carried exactly one
  # object.  See _decode_stream.
  if ($opts{ndjson}) {
    my $events = $self->_decode_stream($body);
    # A failed build, pull or push is HTTP 200 with the failure buried in the
    # stream, so the status line above cannot catch it.  Opt out for a stream
    # whose objects are engine data rather than the outcome of one operation.
    $self->_assert_no_stream_error($endpoint, $events)
      if $opts{croak_on_error} // 1;
    return $events;
  }

  if ($body =~ /^\s*[\{\[]/) {
    my $result = eval { decode_json($body) };
    return $result if defined $result;
  }

  return $body;
}

sub _decode_stream {
  my ($self, $body) = @_;

  # Newline-delimited JSON: one object per line.  A literal newline cannot
  # occur inside a JSON string, so splitting on lines is safe.
  my @events;
  for my $line (split /\r?\n/, $body) {
    next unless $line =~ /\S/;
    my $event = eval { decode_json($line) };
    push @events, $event if defined $event;
  }

  # Fall back to the whole body for a stream that is not newline-framed
  # (a single pretty-printed object), so nothing is silently dropped.
  unless (@events) {
    my $event = eval { decode_json($body) };
    push @events, $event if defined $event;
  }

  return \@events;
}

sub _assert_no_stream_error {
  my ($self, $endpoint, $events) = @_;

  for my $event (@$events) {
    next unless ref $event eq 'HASH';
    my $detail = $event->{errorDetail};
    next unless defined $detail;

    # errorDetail is a HashRef carrying the message. The engine sends a flat
    # `error` next to it with the same text; that is the fallback, not the
    # trigger -- the trigger is errorDetail, and nothing else.
    my $reason = ref $detail eq 'HASH' ? $detail->{message} : undef;
    $reason = $event->{error}   unless defined $reason && length $reason;
    $reason = 'no message given' unless defined $reason && length $reason;
    # Engine messages end in a newline, and Carp appends no location to a
    # message that already does.
    $reason =~ s/\s+\z//;

    # Carp hands a reference straight back rather than decorating it, so this
    # croak is a die with an object -- hence the location captured by hand,
    # which names the same frame a croak of a plain string would have named.
    # The object goes into a variable first: `croak CLASS->new(...)` is
    # indirect object syntax and parses as CLASS->croak(new(...)).
    my $error = API::Docker::Error::Stream->new(
      message  => 'Docker API stream error (' . $endpoint . '): ' . $reason,
      events   => $events,
      location => shortmess(''),
    );
    croak $error;
  }

  return;
}

sub _assert_header_name {
  my ($self, $name) = @_;

  return if defined $name && $name =~ $HEADER_NAME;

  my $display = defined $name ? $name : '';
  $display =~ s/([^\x20-\x7E])/sprintf('\\x%02X', ord $1)/ge;
  croak __PACKAGE__ . '->_request invalid header name "' . $display . '": a '
    . 'header name must be an RFC 9110 token (letters, digits and '
    . '!#$%&\'*+-.^_`|~). A name is rejected rather than sanitised: unlike a '
    . 'value, there is no benign way for one to carry CR, LF, a space or a '
    . 'colon, and rewriting it would send a header the caller never wrote';
}

sub _read_response {
  my ($self, $sock) = @_;

  my $status_line = <$sock>;
  croak "No response from Docker daemon" unless defined $status_line;
  $status_line =~ s/\r?\n$//;

  my ($proto, $status_code, $status_text) = split /\s+/, $status_line, 3;

  my %headers;
  while (my $line = <$sock>) {
    $line =~ s/\r?\n$//;
    last if $line eq '';
    if ($line =~ /^([^:]+):\s*(.*)$/) {
      $headers{lc $1} = $2;
    }
  }

  my $body = '';
  if ($headers{'transfer-encoding'} && $headers{'transfer-encoding'} eq 'chunked') {
    $body = $self->_read_chunked($sock);
  }
  elsif (defined $headers{'content-length'}) {
    my $len = $headers{'content-length'};
    if ($len > 0) {
      my $read = 0;
      while ($read < $len) {
        my $buf;
        my $n = read($sock, $buf, $len - $read);
        last unless $n;
        $body .= $buf;
        $read += $n;
      }
    }
  }
  else {
    local $/;
    $body = <$sock> // '';
  }

  return [$status_code, $status_text, \%headers, $body];
}

sub _read_chunked {
  my ($self, $sock) = @_;
  my $body = '';

  while (1) {
    my $chunk_header = <$sock>;
    last unless defined $chunk_header;
    $chunk_header =~ s/\r?\n$//;
    my $chunk_size = hex($chunk_header);
    last if $chunk_size == 0;

    my $chunk = '';
    my $read = 0;
    while ($read < $chunk_size) {
      my $buf;
      my $n = read($sock, $buf, $chunk_size - $read);
      last unless $n;
      $chunk .= $buf;
      $read += $n;
    }
    $body .= $chunk;

    # Read trailing \r\n after chunk data
    <$sock>;
  }

  return $body;
}

sub _uri_encode {
  my ($str) = @_;
  $str =~ s/([^A-Za-z0-9\-_.~:\/])/sprintf("%%%02X", ord($1))/ge;
  return $str;
}

sub get {
  my ($self, $path, %opts) = @_;
  return $self->_request('GET', $path, %opts);
}


sub post {
  my ($self, $path, $body, %opts) = @_;
  $opts{body} = $body if defined $body;
  return $self->_request('POST', $path, %opts);
}


sub put {
  my ($self, $path, $body, %opts) = @_;
  $opts{body} = $body if defined $body;
  return $self->_request('PUT', $path, %opts);
}


sub delete_request {
  my ($self, $path, %opts) = @_;
  return $self->_request('DELETE', $path, %opts);
}


sub stream_frames {
  my ($self, $method, $path, %opts) = @_;

  my $tty = delete $opts{tty};
  my $body = $self->_request($method, $path, %opts, raw => 1);

  return [] unless defined $body && length $body;

  my $frames = $tty ? undef : $self->_demux_frames($body);

  return $frames if $frames;
  return [ { stream => 'raw', data => $body } ];
}


sub _demux_frames {
  my ($self, $body) = @_;

  my $len = length $body;
  my $pos = 0;
  my @frames;

  while ($pos < $len) {
    return undef if $len - $pos < 8;
    my ($type, $pad1, $pad2, $pad3, $size) = unpack 'C4 N', substr($body, $pos, 8);
    return undef if $type > $#STREAM_TYPE;
    return undef if $pad1 || $pad2 || $pad3;
    return undef if $len - $pos - 8 < $size;
    push @frames, {
      stream => $STREAM_TYPE[$type],
      data   => substr($body, $pos + 8, $size),
    };
    $pos += 8 + $size;
  }

  return undef unless @frames;
  return \@frames;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

API::Docker::Role::HTTP - HTTP transport role for Docker Engine API

=head1 VERSION

version 0.003

=head1 SYNOPSIS

    package MyDockerClient;
    use Moo;

    has host => (is => 'ro', required => 1);
    has api_version => (is => 'ro');

    with 'API::Docker::Role::HTTP';

    # Now use get, post, put, delete_request methods
    my $data = $self->get('/containers/json');

=head1 DESCRIPTION

This role provides HTTP transport for the Docker Engine API. It implements
HTTP/1.1 communication over Unix sockets and TCP sockets without depending on
heavy HTTP client libraries like LWP.

Features:

=over

=item * Unix socket transport (C<unix://...>)

=item * TCP socket transport (C<tcp://host:port>)

=item * HTTP/1.1 chunked transfer encoding

=item * Automatic JSON encoding/decoding

=item * Newline-delimited JSON event streams (C<< ndjson => 1 >>), including
the failures the engine reports inside an HTTP 200 body

=item * Demultiplexing of the Docker stream format (L</stream_frames>)

=item * Request/response logging via L<Log::Any>

=item * Automatic connection management

=back

Consuming classes must provide C<host> and C<api_version> attributes.

B<Both transports are plaintext.> There is no TLS here: a C<tcp://> host is
spoken to in the clear, whatever L<API::Docker/tls> and
L<API::Docker/cert_path> are set to. C<< tls => 1 >> croaks at construction
rather than pretending otherwise -- put a TLS terminator in front of the
daemon and point C<host> at that.

=head2 get

    my $data = $client->get($path, %opts);

Perform HTTP GET request. Returns decoded JSON or raw response body.

Options:

=over

=item * C<params> - HashRef of query parameters; a HashRef value is JSON-encoded

=item * C<headers> - HashRef of extra HTTP headers, e.g.
C<< { 'X-Registry-Auth' => $b64 } >>

=item * C<ndjson> - Parse the body as newline-delimited JSON and always
return an ArrayRef of events, even for a stream carrying a single object.
Named for the format rather than C<stream>, which is already a query
parameter of C</events> and C</containers/{id}/stats>. An C<errorDetail>
event in such a stream croaks; see L</"Failure inside a 200 response">

=item * C<croak_on_error> - Default true, and only consulted with
C<< ndjson => 1 >>. Set it false for a stream whose objects are engine data
rather than the outcome of one operation -- C</events> is the only such
endpoint here

=item * C<raw> - Never decode the body; return the response bytes verbatim

=item * C<headers> names are validated, not sanitised; see
L</"Header names are rejected, header values are stripped">

=back

=head2 Failure inside a 200 response

C</build>, C</images/create> (pull) and C</images/{name}/push> report a failed
operation as an C<errorDetail> object B<inside> a stream the daemon already
answered with HTTP 200. The status line is committed before the operation is
attempted, so the C<< >= 400 >> check above cannot see it, and a client that
trusts the status hands a broken build back as a success.

So an C<< ndjson => 1 >> request scans the decoded events and croaks with an
L<API::Docker::Error::Stream> the moment one carries C<errorDetail>. That
object stringifies to the reason plus Carp's usual location suffix, so
C<eval>-and-inspect-C<$@> code cannot tell it from the plain croak it
replaces; C<< $err->events >> carries the complete event list, so the progress
output that led up to the failure is not lost with the return value.

The trigger is the C<errorDetail> key alone. The flat C<error> key the engine
sends beside it holds the same text and is used only as a fallback message,
never as the trigger on its own.

C<< croak_on_error => 0 >> turns the scan off for a stream that is a feed
rather than an operation. The check is on by default, and opting out is per
endpoint, because the set of operation-shaped streaming endpoints is
open-ended while the feed-shaped ones are C</events> and nothing else: a new
endpoint added without a thought about this gets the loud behaviour, not the
silent one.

=head2 Header names are rejected, header values are stripped

A CR or LF in a header B<value> is stripped and the value is flattened onto
its own line. A header B<name> that is not an RFC 9110 token is refused with
a croak instead.

The asymmetry is deliberate. A value can pick up a stray newline honestly --
C<MIME::Base64::encode_base64> wraps its output by default, and a token pasted
out of a file brings its line ending along -- and flattening it preserves what
the caller meant. A name is a literal the programmer wrote; there is no benign
way for one to contain CR, LF, a space or a colon, and quietly rewriting
C<< "X-Foo\r\nX-Bar" >> into C<X-FooX-Bar> would put a header on the wire
under a name nobody asked for. Validating against the token grammar also
catches the separators that would corrupt the request without injecting
anything.

=head2 post

    my $data = $client->post($path, $body, %opts);

Perform HTTP POST request. C<$body> is automatically JSON-encoded if provided.

Options: C<params>, C<headers>, C<ndjson>, C<croak_on_error> and C<raw> as for
L</get>, plus C<raw_body> and C<content_type> for sending a non-JSON payload
such as a build context tarball.

=head2 put

    my $data = $client->put($path, $body, %opts);

Perform HTTP PUT request. C<$body> is automatically JSON-encoded if provided.

Options: C<params> (hashref of query parameters).

=head2 delete_request

    my $data = $client->delete_request($path, %opts);

Perform HTTP DELETE request.

Options: C<params> (hashref of query parameters).

=head2 stream_frames

    my $frames = $client->stream_frames('GET', "/containers/$id/logs", %opts);

Perform a request against one of the engine's framed endpoints
(C<< /containers/{id}/logs >>, C<< /exec/{id}/start >>) and return an ArrayRef
of frames:

    [ { stream => 'stdout', data => "OUT\n" },
      { stream => 'stderr', data => "ERR\n" } ]

C<stream> is C<stdout>, C<stderr> or C<stdin> for a multiplexed stream, and
C<raw> for an unframed one. It is always a plain string, so callers never need
a defined-check. Joining the payloads gives the plain text:

    my $text = join '', map { $_->{data} } @$frames;

The response body is never JSON-decoded, so a container printing JSON lines is
returned verbatim.

Options are those of C<_request> (C<params>, C<body>, C<headers>), plus:

=over

=item * C<tty> - Skip demultiplexing and return the body as a single C<raw>
frame. Set it when the container or exec instance was created with a TTY and
its output is binary; see L</"Detecting a framed stream"> for why.

=back

=head2 Detecting a framed stream

A container created without a TTY produces the Docker stream format -- an
8-byte header per frame (byte 0 the stream type, bytes 4-7 a big-endian uint32
payload length) followed by that many payload bytes. With a TTY there is no
header and the payload is raw pty output.

The engine is supposed to distinguish the two with the response C<Content-Type>
(C<application/vnd.docker.multiplexed-stream> against
C<application/vnd.docker.raw-stream>), but that signal is not dependable.
Measured against Podman 5.4.2 (API 1.41): C<< GET /containers/{id}/logs >>
sends no C<Content-Type> at all, for either kind of container, and
C<< POST /exec/{id}/start >> sends C<application/vnd.docker.raw-stream> for
both -- including the non-TTY exec whose body is in fact multiplexed. Trusting
the header would therefore hand frame headers to the caller on that engine.

The framing is decided from the bytes instead. The body is walked as frames:
each header must have a stream type of 0, 1 or 2, three zero bytes after it,
and a payload length that leaves at least that many bytes in the buffer. The
body is treated as framed only when the walk consumes it exactly and yields at
least one frame; anything else is returned as a single C<raw> frame.

This can be fooled in one direction only. Raw TTY output is misread as framed
if it begins with a byte no greater than C<0x02>, followed by three NUL bytes
and a length that happens to chain exactly to the end of the body. Text output
cannot do that -- a printable character is C<0x20> or above -- so it takes
binary output from a TTY-allocated container. Pass C<< tty => 1 >> for that
case. The reverse mistake cannot happen silently: a genuine frame stream is
only ever reported as raw when its final frame is truncated, which needs the
daemon to close the connection mid-frame.

=head1 SEE ALSO

=over

=item * L<API::Docker> - Main client using this role

=item * L<API::Docker::Error::Stream> - Raised for a failure reported inside
a 200 event stream

=back

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-api-docker/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <getty@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus <torsten@raudssus.de> L<https://raudssus.de/>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
