#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::API::Docker::Mock;
use API::Docker;

# karr k20 -- the image tar roundtrip: GET /images/{name}/get,
# GET /images/get?names= and POST /images/load. The air-gapped path: export
# here, carry the tar over, load there.
#
# t/fixtures/images_get.tar is a real export from the rootless Podman socket
# (5.4.2, API 1.41) -- a one-layer image imported through
# /images/create?fromSrc=- for the purpose, exported, then deleted again.
# t/fixtures/images_load_stream.ndjson is the body loading it back produced.
# Both are byte-exact captures, which is the whole point of the ticket: the
# export is raw tar and nothing in the client may touch it.

check_live_access();

my $TAR    = load_fixture_raw('images_get.tar');
my $STREAM = load_fixture_raw('images_load_stream.ndjson');

# ---------------------------------------------------------------------------
# A client whose socket is a captured in-memory sink and whose response is
# canned, so the real _request -- and therefore `raw => 1` and the ndjson
# decode -- runs without a daemon. Mirrors the FakeTransport pattern in
# t/streaming_shape.t and t/role_http.t; the mock harness replaces _request
# wholesale and cannot reach any of it.
package Test::ImagesTar::FakeTransport;
use Moo;
extends 'API::Docker';

has canned => (is => 'rw', default => sub { [200, 'OK', {}, ''] });
has _sink  => (is => 'rw');

sub _build__socket {
  my ($self) = @_;
  my $sink = '';
  $self->_sink(\$sink);
  open my $fh, '>', \$sink or die "open: $!";
  binmode $fh;
  return $fh;
}

sub _read_response { return $_[0]->canned }

sub written { return ${ $_[0]->_sink } }

package main;

sub fake_client {
  return Test::ImagesTar::FakeTransport->new(
    host        => 'unix:///nonexistent.sock',
    api_version => '1.41',
  );
}

# ---------------------------------------------------------------------------
subtest 'the fixture really is a tar, so byte-exactness means something' => sub {
  cmp_ok length($TAR), '>', 512, 'more than one tar block';
  is length($TAR) % 512, 0, 'a whole number of 512-byte blocks';
  is substr($TAR, 257, 5), 'ustar', 'ustar magic in the first header block';
  like $TAR, qr/manifest\.json/, 'carries a manifest member';
  like $TAR, qr/\0/, 'carries NUL bytes -- it is not text';
};

# ---------------------------------------------------------------------------
subtest 'get: asks for the export path and does not decode the answer' => sub {
  plan skip_all => 'route assertions are fixture-only' if is_live();

  my %seen;
  my $docker = test_docker(
    'GET /images/alpine:3/get' => sub {
      my ($method, $path, %opts) = @_;
      %seen = %opts;
      return $TAR;
    },
  );

  my $out = $docker->images->get('alpine:3');

  ok $seen{raw}, 'the request asked the transport for raw bytes';
  ok !$seen{ndjson}, 'and not for a decoded event stream';
  is $out, $TAR, 'the daemon bytes come back verbatim';
  is length($out), length($TAR), 'no truncation';

  my $err = do { local $@; eval { $docker->images->get }; $@ };
  like $err, qr/Image name required/, 'a missing name croaks';
};

# ---------------------------------------------------------------------------
subtest 'get: raw bytes survive the real _request' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', { 'content-type' => 'application/octet' }, $TAR]);

  my $out = $t->images->get('alpine:3');

  is $out, $TAR, 'byte-exact through _request';
  like $t->written, qr{\AGET /v1\.41/images/alpine:3/get HTTP/1\.1\r\n},
    'the request line keeps the colon in the image reference';
};

subtest 'get: a body that looks like JSON is still not decoded' => sub {
  # The transport tries decode_json on any body starting with { or [ unless
  # raw is set. A tar cannot start that way, but the guarantee under test is
  # "never decoded", not "never decodable" -- so assert it directly.
  my $t = fake_client();
  $t->canned([200, 'OK', {}, '{"Id":"not really a tar"}']);

  is ref $t->images->get('alpine:3'), '',
    'a JSON-shaped body comes back as a plain string, not a HashRef';
};

# ---------------------------------------------------------------------------
subtest 'get_all: names is a repeated query parameter' => sub {
  # Measured against Podman 5.4.2: the comma-joined spelling answers 500,
  # 'parsing reference "alpine:3,registry:2": invalid reference format'.
  # Docker reads r.Form["names"]. Only the repeated form works on either.
  my $t = fake_client();
  $t->canned([200, 'OK', {}, $TAR]);

  my $out = $t->images->get_all('alpine:3', 'registry:2');
  is $out, $TAR, 'raw bytes come back';

  my ($line) = $t->written =~ /\A(GET [^\r\n]+)\r\n/;
  is $line, 'GET /v1.41/images/get?names=alpine:3&names=registry:2 HTTP/1.1',
    'one names= pair per image, comma never used as a separator';

  $t->images->get_all([ 'alpine:3', 'registry:2' ]);
  my ($aref_line) = $t->written =~ /\A(GET [^\r\n]+)\r\n/;
  is $aref_line, $line, 'a single ArrayRef argument encodes identically';
};

subtest 'get_all: the escaping keeps an image reference intact' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, $TAR]);

  $t->images->get_all('registry.example.com:5000/team/app:v1',
    'app@sha256:0123456789abcdef', 'has space');

  my ($line) = $t->written =~ /\A(GET [^\r\n]+)\r\n/;
  like $line, qr{names=registry\.example\.com:5000/team/app:v1},
    'host port, path slashes and tag colon all stay raw';
  like $line, qr{names=app%40sha256:0123456789abcdef},
    'the digest @ is percent-encoded, the colon after sha256 is not';
  like $line, qr{names=has%20space}, 'a space is encoded';

  my $err = do { local $@; eval { $t->images->get_all }; $@ };
  like $err, qr/At least one image name required/, 'no names croaks';
};

# ---------------------------------------------------------------------------
subtest 'load: sends the tar as the body and decodes the progress stream' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', { 'content-type' => 'application/json' }, $STREAM]);

  my $events = $t->images->load($TAR);

  is ref $events, 'ARRAY', 'an ArrayRef of events, as for build and pull';
  is scalar @$events, 1, 'the captured stream carried one object';
  like $events->[0]{stream}, qr/^Loaded image: /, 'and it names what was loaded';

  my $req = $t->written;
  like $req, qr{\APOST /v1\.41/images/load HTTP/1\.1\r\n},
    'no query string when quiet was not asked for';
  like $req, qr{Content-Type: application/x-tar\r\n}, 'sent as a tar';
  like $req, qr{Content-Length: @{[ length $TAR ]}\r\n}, 'the whole archive';

  my ($body) = $req =~ /\r\n\r\n(.*)\z/s;
  is $body, $TAR, 'the request body is the archive byte for byte';
};

subtest 'load: takes a scalar ref too, the way build takes its context' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, $STREAM]);

  $t->images->load(\$TAR);
  my ($body) = $t->written =~ /\r\n\r\n(.*)\z/s;
  is $body, $TAR, 'dereferenced, not stringified';

  my $err = do { local $@; eval { $t->images->load }; $@ };
  like $err, qr/Tar archive required/, 'a missing archive croaks';
};

subtest 'load: quiet is a query parameter, not a change of return shape' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, $STREAM]);

  my $events = $t->images->load($TAR, quiet => 1);
  like $t->written, qr{\APOST /v1\.41/images/load\?quiet=1 HTTP/1\.1\r\n},
    'quiet=1 on the wire';
  is ref $events, 'ARRAY', 'still an ArrayRef';

  $t->images->load($TAR, quiet => 0);
  like $t->written, qr{\APOST /v1\.41/images/load\?quiet=0 HTTP/1\.1\r\n},
    'a false quiet is sent as 0, not dropped';
};

subtest 'load: a failure reported inside the 200 stream croaks' => sub {
  # Docker's route. Podman puts the failure in the status line instead --
  # measured 5.4.2, a non-archive body answers 500 with
  # {"message":"failed to load image: payload does not match any of the
  # supported image formats: ..."} -- covered by the next subtest.
  my $t = fake_client();
  $t->canned([200, 'OK', {},
    qq({"errorDetail":{"message":"invalid tar header"},"error":"invalid tar header"}\n)]);

  my $err = do { local $@; eval { $t->images->load($TAR) }; $@ };
  ok $err, 'it croaks rather than returning the failure as events';
  isa_ok $err, 'API::Docker::Error::Stream';
  like "$err", qr/invalid tar header/, 'the reason survives stringification';
};

subtest 'load: a failure reported in the status line croaks before the stream' => sub {
  my $t = fake_client();
  $t->canned([500, 'Internal Server Error', {},
    '{"cause":"payload does not match any of the supported image formats",'
    . '"message":"failed to load image: payload does not match any of the '
    . 'supported image formats","response":500}']);

  my $err = do { local $@; eval { $t->images->load('not a tar') }; $@ };
  like $err, qr/Docker API error \(500\)/, 'the status handling croaks first';
  like $err, qr/failed to load image/, 'with the message key, not the whole body';
  # The claim here is which of the two croak paths won, not what type the
  # winner is. Since karr k50 a >= 400 status raises Error::HTTP rather than
  # a bare string -- stringifying to the very text the two matches above
  # still find -- so the type is what tells the paths apart now.
  isa_ok $err, 'API::Docker::Error::HTTP';
  ok !$err->isa('API::Docker::Error::Stream'),
    'the status handling won: the 200-stream path was never reached';
};

# ---------------------------------------------------------------------------
subtest 'live: exporting a real image gives a real tar' => sub {
  plan skip_all => 'live only' unless is_live();

  my $docker = test_docker();
  my ($smallest) = sort { ($a->size // 0) <=> ($b->size // 0) }
    grep { $_->repo_tags && @{ $_->repo_tags } } @{ $docker->images->list };
  plan skip_all => 'no tagged image on the daemon' unless $smallest;

  my $name = $smallest->repo_tags->[0];
  my $tar  = $docker->images->get($name);

  ok defined $tar && length $tar, "exported $name";
  is length($tar) % 512, 0, 'a whole number of tar blocks';
  is substr($tar, 257, 5), 'ustar', 'ustar magic';
  like $tar, qr/manifest\.json/, 'carries a manifest member';
};

done_testing;
