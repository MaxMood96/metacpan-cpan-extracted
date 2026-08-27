use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw( encode_json decode_json );
use API::Docker;

# API::Docker::Role::HTTP sits below _request as far as Test::API::Docker::Mock
# is concerned -- the mock replaces _request wholesale, so request-line
# assembly, header sanitising, chunked reading, status handling and the
# >=400 croak path are exercised by nothing but use_ok in t/basic.t.
#
# Nothing here opens a real socket or reaches a daemon: the socket-facing
# methods (_read_response, _read_chunked) are driven directly over an
# in-memory filehandle, and _request itself is driven through a subclass
# that fakes the socket instead of connecting one. So this file needs no
# is_live()/can_write() gating -- it is unconditionally safe with no Docker
# installed.

# ---------------------------------------------------------------------------
# A tied filehandle that hands back only a few bytes per read() call
# regardless of how much was asked for, so "a chunk arriving in several
# reads" is a real multi-call scenario for _read_chunked's inner while loop,
# not just a single read() that happens to satisfy the whole request. An
# in-memory scalar filehandle (open $fh, '<', \$str) never does this --
# PerlIO::scalar always returns everything available in one call.
package Test::RoleHTTP::PartialReader;

sub TIEHANDLE {
  my ($class, $data, $step) = @_;
  return bless { buf => $data, pos => 0, step => $step || 3 }, $class;
}

sub READLINE {
  my ($self) = @_;
  return undef if $self->{pos} >= length $self->{buf};
  my $idx = index($self->{buf}, "\n", $self->{pos});
  my $end = $idx == -1 ? length($self->{buf}) : $idx + 1;
  my $line = substr($self->{buf}, $self->{pos}, $end - $self->{pos});
  $self->{pos} = $end;
  return $line;
}

sub READ {
  my $self   = $_[0];
  my $len    = $_[2];
  my $offset = $_[3] || 0;
  my $avail  = length($self->{buf}) - $self->{pos};
  return 0 if $avail <= 0;
  my $n = $len > $self->{step} ? $self->{step} : $len;
  $n = $avail if $n > $avail;
  my $chunk = substr($self->{buf}, $self->{pos}, $n);
  if ($offset) {
    substr($_[1], $offset, $n) = $chunk;
  }
  else {
    $_[1] = $chunk;
  }
  $self->{pos} += $n;
  return $n;
}

sub CLOSE { 1 }

package main;

# ---------------------------------------------------------------------------
# A client whose socket is a captured in-memory sink and whose response is
# canned, so _request's request-assembly and >=400 handling can be driven
# without a daemon on the other end. Mirrors the Test::FakeTransport pattern
# in t/streaming_shape.t, plus capturing what got written to the "socket".
package Test::RoleHTTP::FakeTransport;
use Moo;
extends 'API::Docker';

has canned => (is => 'rw', default => sub { [200, 'OK', {}, ''] });
has _sink  => (is => 'rw');

sub _build__socket {
  my ($self) = @_;
  my $sink = '';
  $self->_sink(\$sink);
  open my $fh, '>', \$sink or die "open: $!";
  return $fh;
}

sub _read_response { return $_[0]->canned }

sub written { return ${ $_[0]->_sink } }

package main;

my $client = API::Docker->new(
  host        => 'unix:///nonexistent.sock',
  api_version => '1.41',
);

# ---------------------------------------------------------------------------
subtest '_read_response: status line parsing' => sub {
  open my $fh, '<', \"HTTP/1.1 204 No Content\r\n\r\n" or die $!;
  my $resp = $client->_read_response($fh);
  is $resp->[0], 204, 'status code';
  is $resp->[1], 'No Content', 'status text, including the embedded space';
};

subtest '_read_response: header collection' => sub {
  my $raw = "HTTP/1.1 200 OK\r\n"
    . "Content-Type: application/json\r\n"
    . "X-Mixed-CASE:   value with spaces  \r\n"
    . "Content-Length: 2\r\n"
    . "\r\n"
    . "{}";
  open my $fh, '<', \$raw or die $!;
  my $resp = $client->_read_response($fh);
  my $headers = $resp->[2];

  is $headers->{'content-type'}, 'application/json',
    'an already-lowercase key is kept';
  is $headers->{'x-mixed-case'}, 'value with spaces  ',
    'a mixed-case key is lowercased; leading space after the colon is '
    . 'trimmed, the rest of the value is kept verbatim (trailing spaces too)';
  is $headers->{'content-length'}, '2', 'colon splits key from value';
  is $resp->[3], '{}', 'body still decoded via content-length';
};

subtest '_read_response: chunked body' => sub {
  my $raw = "HTTP/1.1 200 OK\r\n"
    . "Transfer-Encoding: chunked\r\n"
    . "\r\n"
    . "5\r\nhello\r\n"
    . "6\r\n world\r\n"
    . "0\r\n\r\n";
  open my $fh, '<', \$raw or die $!;
  my $resp = $client->_read_response($fh);
  is $resp->[3], 'hello world', 'chunks concatenated, chunk framing stripped';
};

subtest '_read_response: content-length body' => sub {
  # Embedded CRLF and a NUL byte prove this is a byte-exact length read, not
  # a line-oriented one.
  my $body = "line1\r\nline2\x00tail";
  my $raw = 'HTTP/1.1 200 OK' . "\r\n"
    . 'Content-Length: ' . length($body) . "\r\n"
    . "\r\n"
    . $body;
  open my $fh, '<', \$raw or die $!;
  my $resp = $client->_read_response($fh);
  is $resp->[3], $body,
    'exactly content-length bytes read, embedded CRLF/NUL preserved';
};

subtest '_read_response: read-to-EOF fallback' => sub {
  # Neither Transfer-Encoding nor Content-Length -- the pre-HTTP/1.1-ish
  # case where the body is "whatever remains until the connection closes".
  my $raw = "HTTP/1.1 200 OK\r\n"
    . "Connection: close\r\n"
    . "\r\n"
    . "no length header, read until eof";
  open my $fh, '<', \$raw or die $!;
  my $resp = $client->_read_response($fh);
  is $resp->[3], 'no length header, read until eof',
    'falls back to slurping the rest of the socket';
};

# ---------------------------------------------------------------------------
subtest '_read_chunked: hex sizes, upper and lower case' => sub {
  # 'a' and 'A' are both 10 -- hex() is case-insensitive, and so must this be.
  my $raw = "a\r\n0123456789\r\nA\r\nABCDEFGHIJ\r\n0\r\n\r\n";
  open my $fh, '<', \$raw or die $!;
  is $client->_read_chunked($fh), '0123456789ABCDEFGHIJ',
    'lowercase and uppercase hex chunk sizes both read correctly';
};

subtest '_read_chunked: a single zero-size chunk terminates immediately' => sub {
  open my $fh, '<', \"0\r\n\r\n" or die $!;
  is $client->_read_chunked($fh), '', 'empty body, no chunks';
};

subtest '_read_chunked: a chunk arriving in several reads' => sub {
  my $data = "b\r\nhello world\r\n0\r\n\r\n"; # 'b' hex = 11 = length("hello world")
  tie *FH, 'Test::RoleHTTP::PartialReader', $data, 3; # 3 bytes per read() call
  my $body = $client->_read_chunked(\*FH);
  is $body, 'hello world',
    'chunk payload reassembled correctly across multiple short reads';
  untie *FH;
};

# ---------------------------------------------------------------------------
subtest '_uri_encode: what it escapes and what it leaves alone' => sub {
  # Called as a bare function everywhere in the module (see _request's
  # query-string assembly) -- not as a method. Calling it as $client->
  # _uri_encode(...) would silently shift $client into the $str slot, since
  # the sub only unpacks a single positional argument.
  my $encode = \&API::Docker::Role::HTTP::_uri_encode;

  is $encode->('alpine:latest'), 'alpine:latest',
    'colon is left raw -- image references keep their tag separator';
  is $encode->('myrepo/app:v1'), 'myrepo/app:v1',
    'slash is left raw too -- image references keep their path shape';
  is $encode->('abcXYZ019-_.~'), 'abcXYZ019-_.~',
    'unreserved characters (alnum - _ . ~) are never escaped';
  is $encode->('a b'), 'a%20b', 'space is percent-encoded';
  is $encode->('foo?bar=baz'), 'foo%3Fbar%3Dbaz',
    '? and = are percent-encoded';
  is $encode->('100%'), '100%25', 'a literal percent sign is escaped itself';
  is $encode->("a\nb"), 'a%0Ab', 'control characters are escaped, not passed through';
};

# ---------------------------------------------------------------------------
subtest '_request: assembles the request line, headers and body' => sub {
  my $t = Test::RoleHTTP::FakeTransport->new(
    host        => 'unix:///nonexistent.sock',
    api_version => '1.41',
  );

  subtest 'plain GET, no body' => sub {
    $t->_request('GET', '/containers/json');
    my $req = $t->written;
    like $req, qr{\AGET /v1\.41/containers/json HTTP/1\.1\r\n},
      'method, versioned path, and protocol on the request line';
    like $req, qr{Host: localhost\r\n}, 'Host header sent';
    like $req, qr{Connection: close\r\n}, 'Connection: close sent';
    like $req, qr{User-Agent: API-Docker\r\n}, 'User-Agent sent';
    unlike $req, qr{Content-Type}, 'no Content-Type without a body';
    unlike $req, qr{Content-Length}, 'no Content-Length without a body';
    like $req, qr{\r\n\r\n\z}, 'request ends on the blank line, empty body';
  };

  subtest 'POST with a JSON body' => sub {
    $t->_request('POST', '/containers/create', body => { Image => 'alpine:3' });
    my $req = $t->written;
    my $encoded = encode_json({ Image => 'alpine:3' });
    like $req, qr{\APOST /v1\.41/containers/create HTTP/1\.1\r\n},
      'request line for the POST';
    like $req, qr{Content-Type: application/json\r\n}, 'JSON content type';
    like $req, qr{Content-Length: @{[ length $encoded ]}\r\n},
      'content-length matches the encoded body';
    like $req, qr{\r\n\r\n\Q$encoded\E\z}, 'body follows the blank line verbatim';
  };

  subtest 'raw_body + content_type (tarball upload)' => sub {
    my $tar = "fake tar bytes\0\0\0";
    $t->_request('POST', '/build', raw_body => $tar, content_type => 'application/x-tar');
    my $req = $t->written;
    like $req, qr{Content-Type: application/x-tar\r\n},
      'content type overridden for a raw body, not left as application/json';
    like $req, qr{Content-Length: @{[ length $tar ]}\r\n},
      'content-length matches the raw body, not a JSON encoding of it';
    like $req, qr{\r\n\r\n\Q$tar\E\z}, 'raw bytes appended verbatim';
  };

  subtest 'params: sorted, hashref values JSON-encoded, then URI-encoded' => sub {
    $t->_request('GET', '/images/json',
      params => { all => 1, filters => { dangling => ['true'] } });
    my $req = $t->written;
    my ($request_line) = $req =~ /\A(GET [^\r\n]+)\r\n/;
    my $expected_filters = API::Docker::Role::HTTP::_uri_encode(
      encode_json({ dangling => ['true'] }));
    is $request_line,
      "GET /v1.41/images/json?all=1&filters=$expected_filters HTTP/1.1",
      'params sorted alphabetically by key; a hashref value is JSON-encoded '
      . 'then URI-encoded, not encoded twice by hand';
  };

  subtest 'extra headers: sanitised and appended' => sub {
    $t->_request('POST', '/images/x/push',
      headers => { 'X-Registry-Auth' => 'e30=' });
    my $req = $t->written;
    like $req, qr{X-Registry-Auth: e30=\r\n}, 'extra header present';
  };
};

# ---------------------------------------------------------------------------
subtest '_request: a CR/LF in a header value cannot inject a second header' => sub {
  my $t = Test::RoleHTTP::FakeTransport->new(
    host        => 'unix:///nonexistent.sock',
    api_version => '1.41',
  );

  $t->_request('POST', '/images/x/push',
    headers => { 'X-Registry-Auth' => "e30=\r\nX-Injected: evil" });
  my $req = $t->written;

  unlike $req, qr{\r\nX-Injected:},
    'no second header line -- "X-Injected" never starts its own line';
  like $req, qr{X-Registry-Auth: e30=X-Injected: evil\r\n},
    'the CRLF is stripped, not left as a line break -- the payload is '
    . 'flattened onto the one header line it belongs to';
};

# ---------------------------------------------------------------------------
# karr #11: the value above is sanitised, but the *name* used to go on the
# wire untouched, so a caller-supplied key could open a header line of its
# own. Names are rejected rather than stripped -- see the reasoning in
# API::Docker::Role::HTTP under "Header names are rejected, header values are
# stripped".
subtest '_request: an invalid header name is refused, not rewritten' => sub {
  my $t = Test::RoleHTTP::FakeTransport->new(
    host        => 'unix:///nonexistent.sock',
    api_version => '1.41',
  );

  subtest 'CRLF in the name croaks and sends nothing' => sub {
    eval {
      $t->_request('POST', '/images/x/push',
        headers => { "X-Registry-Auth\r\nX-Injected" => 'evil' });
    };
    like $@, qr/invalid header name/, 'croaked';
    like $@, qr/\QX-Registry-Auth\x0D\x0AX-Injected\E/,
      'the offending name is shown with its control bytes escaped, so the '
      . 'message stays on one line and names what was actually passed';
    my $message = "$@";
    unlike $message, qr/\r/, 'the croak itself carries no raw CR';
    $message =~ s/\n\z//;
    unlike $message, qr/\n/,
      'and no LF beyond the one Carp ends on -- the escaped name cannot open '
      . 'a line of its own in whatever logs the failure';
    is $t->_sink, undef,
      'no socket was even opened -- the name is checked while the request is '
      . 'assembled, so nothing reached the daemon';
  };

  subtest 'the separators that would corrupt the line, injection or not' => sub {
    my %bad = (
      'an embedded space'       => 'X Registry Auth',
      'a trailing colon'        => 'X-Registry-Auth:',
      'a bare LF'               => "tail\n",
      'a bare CR'               => "tail\r",
      'the empty string'        => '',
      'a non-ASCII byte'        => "X-Caf\xE9",
    );
    for my $why (sort keys %bad) {
      eval { $t->_request('GET', '/x', headers => { $bad{$why} => 'v' }) };
      like $@, qr/invalid header name/, "$why is rejected";
    }
  };

  subtest 'a name is refused even when its value would skip the header' => sub {
    # An undef value means the header is not sent, but the name is still a
    # caller bug and is still reported.
    eval { $t->_request('GET', '/x', headers => { "bad\r\nname" => undef }) };
    like $@, qr/invalid header name/,
      'validated before the defined-check on the value';
  };

  subtest 'every character an RFC 9110 token allows still passes' => sub {
    my $token = "Abc123-!#\$%&'*+.^_`|~";
    $t->_request('GET', '/x', headers => { $token => 'ok' });
    like $t->written, qr/\Q$token\E: ok\r\n/,
      'the full token charset is accepted, not just the alphanumerics';

    $t->_request('POST', '/images/x/push',
      headers => { 'X-Registry-Auth' => 'e30=' });
    like $t->written, qr/X-Registry-Auth: e30=\r\n/,
      'and the one name this distribution actually sends is unaffected';
  };
};

# ---------------------------------------------------------------------------
subtest '_request: >= 400 croaks' => sub {
  my $t = Test::RoleHTTP::FakeTransport->new(
    host        => 'unix:///nonexistent.sock',
    api_version => '1.41',
  );

  subtest 'a JSON error body croaks with its message, not the raw body' => sub {
    $t->canned([404, 'Not Found', {}, encode_json({ message => 'no such container: abc' })]);
    eval { $t->_request('GET', '/containers/abc/json') };
    like $@, qr/\ADocker API error \(404\): no such container: abc at /,
      'the decoded message is used, the JSON envelope is not';
  };

  subtest 'a non-JSON error body croaks with the raw body' => sub {
    $t->canned([500, 'Internal Server Error', {}, 'internal server meltdown']);
    eval { $t->_request('GET', '/containers/abc/json') };
    like $@, qr/\ADocker API error \(500\): internal server meltdown at /,
      'a body that does not look like JSON is never handed to decode_json';
  };

  subtest 'a body that looks like JSON but is not valid falls back to the raw body' => sub {
    $t->canned([400, 'Bad Request', {}, '{not actually json']);
    eval { $t->_request('POST', '/containers/create') };
    like $@, qr/\Q{not actually json\E/,
      'decode_json failing inside the eval leaves the raw body as the message';
  };

  subtest 'a JSON array error body (no .message key) falls back to the raw body' => sub {
    # decode_json succeeds here, but $data->{message} on an arrayref dies --
    # caught by the same eval, so the raw body still surfaces rather than an
    # unrelated "Not a HASH reference" replacing the real error.
    $t->canned([400, 'Bad Request', {}, '[1,2,3]']);
    eval { $t->_request('POST', '/containers/create') };
    like $@, qr/\ADocker API error \(400\): \[1,2,3\] at /,
      'array-shaped error body is used verbatim, not blamed for a deref error';
  };

  # karr #13: Podman answers a failed push with 500 and the stream-shaped
  # body {"errorDetail":{"message":...},"error":...} -- no `message` key at
  # all -- so the whole JSON object became the croak text.
  subtest 'a JSON error body with errorDetail but no message uses errorDetail.message' => sub {
    $t->canned([500, 'Internal Server Error', {}, encode_json({
      errorDetail => { message => 'denied: requested access to the resource is denied' },
      error       => 'denied: requested access to the resource is denied',
    })]);
    eval { $t->_request('POST', '/images/x/push') };
    like $@, qr/\ADocker API error \(500\): denied: requested access to the resource is denied at /,
      'errorDetail.message is the reason, not the raw JSON object';
  };

  subtest 'a JSON error body with only a flat error key uses that' => sub {
    $t->canned([500, 'Internal Server Error', {}, encode_json({ error => 'flat error text' })]);
    eval { $t->_request('POST', '/images/x/push') };
    like $@, qr/\ADocker API error \(500\): flat error text at /,
      'the flat error key is the last fallback before the raw body';
  };

  subtest 'message still wins when it is present beside errorDetail' => sub {
    $t->canned([500, 'Internal Server Error', {}, encode_json({
      message     => 'the message key',
      errorDetail => { message => 'the detail' },
    })]);
    eval { $t->_request('POST', '/images/x/push') };
    like $@, qr/\ADocker API error \(500\): the message key at /,
      'message is consulted first, errorDetail only fills its absence';
  };

  subtest '204 and other success codes still return undef/decode normally' => sub {
    $t->canned([204, 'No Content', {}, '']);
    is $t->_request('POST', '/containers/abc/start'), undef, '204 -> undef';

    $t->canned([200, 'OK', {}, '{"Id":"abc"}']);
    is_deeply $t->_request('GET', '/containers/abc/json'), { Id => 'abc' },
      'a 2xx JSON body still decodes';
  };
};

done_testing;
