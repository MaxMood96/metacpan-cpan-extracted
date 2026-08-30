#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::API::Docker::Mock;
use JSON::MaybeXS qw( encode_json );
use MIME::Base64 qw( encode_base64 );
use API::Docker;

# The container endpoints this client did not expose:
#
#   karr k18  GET/PUT/HEAD /containers/{id}/archive  -- what docker cp is
#   karr k19  POST /containers/{id}/attach           -- the one-way variant
#   karr k23  changes, export, resize
#
# Measured against the rootless Podman socket (5.4.2, API 1.41): all five
# routes are served there. A nonexistent container answers 404 on archive,
# export, resize and attach -- and 500 with "layer not known" on changes,
# which is why changes documents that difference.
#
# karr k36 closed the remaining gap: the bytes of a real archive, a real
# attach stream, and the X-Docker-Container-Path-Stat header are now captured
# from apidocker-fixture-* containers on that same socket rather than assumed.
# See the fixture-loading comments below for what each measurement found.

check_live_access();

# GET /containers/{id}/archive?path=/etc/hostname, captured from a running
# apidocker-fixture-archive container on Podman 5.4.2 (API 1.41) -- karr k36
# replaced the hand-built ustar that stood in here before. Measured
# differences from the hand-built version: uname/gname were populated
# ('root'/'root', not empty) on that 5.4.2 socket, devmajor/devminor are the
# ASCII string '0000000' rather than left as raw NUL bytes, and mode reflects
# the file's real permissions (0644, not the guessed 0664). Block size (512),
# the two trailing all-zero blocks that end the archive, the ustar
# magic/version, and the empty prefix field were already right in the
# hand-built one.
#
# karr k62 re-measured the same archive live on Podman 5.8.4 (API 1.44):
# uname/gname now come back NUL rather than 'root', byte-identical to a
# Docker 29.7.2 capture of the same file -- Podman changed to match Docker
# here, so this is no longer a difference between the two engines. The
# fixture below is kept as the 5.4.2 capture rather than recaptured: nothing
# in this file asserts uname/gname (only length, the ustar magic, the member
# name and byte-exact roundtrip through the transport are checked), so the
# 5.4.2 bytes still exercise exactly what this file tests.
my $TAR = load_fixture_raw('containers_archive.tar');

# The one-way attach stream is byte-identical to the logs stream, which is the
# whole claim of karr k19 -- and now measured, not just documented: karr k36
# attached live to an apidocker-fixture-attach-live container across its run
# (POST .../attach?stream=1&stdout=1&stderr=1, connected before the container
# started so the daemon had output to send) and diffed the bytes against
# GET .../logs?stdout=1&stderr=1 on an equivalent run; both came back as this
# same 24-byte frame pair, byte for byte. This is the captured logs fixture
# rather than a second file holding the same bytes: it is real engine output,
# and a copy made by hand would only look like one.
#
# A related hazard the measurement also turned up: attaching with stream=1 to
# a container that has *already* exited still sends the same 24 bytes, but
# Podman never closes the connection afterward -- no Content-Length, no
# chunked encoding, and no close even when the client sends Connection: close
# itself, which _request always does. Reading blocks until EOF, so that call
# hangs forever.
#
# karr k52 narrowed that down: it is stream=1 that hangs, not attach as such.
# Re-measured on Podman 5.4.2 (API 1.41) against one exited container:
# ?logs=1&stdout=1&stderr=1&stream=0 answers 200, sends the 24 bytes and
# closes after 13ms; the same request with stream=1 sends the identical bytes
# and hangs; with Upgrade: tcp it answers 101 UPGRADED and hangs the same
# way; and stream=1 against a container still *running*, which exits three
# seconds later, closes cleanly after 3s. The spec explains it -- stream is
# "from the time the request was made onwards" and its only terminator is the
# container ending, which for a stopped container already happened. So this
# client now follows the engine's own default of stream=0 and defaults logs=1
# instead. Docker was unverified when this was written; it has since been
# measured (29.7.2, API 1.55) and hangs identically, so the hang is not a
# Podman quirk but behaviour the reference leaves unspecified for both.
#
# The live subtests below still never call attach: the transport buffers, and
# an explicit stream => 1 is still a hang waiting to happen.
my $FRAMES = load_fixture_raw('containers_logs_multiplexed.bin');

# X-Docker-Container-Path-Stat for /etc/hostname, decoded from a real header
# captured alongside the archive above (karr k36) -- against the Podman
# socket, so this models Podman's shape specifically, not "the" shape. A
# later side-by-side against a real Docker daemon (29.7.2, API 1.55) on the
# same file confirmed what had only been a guess here: Podman's key names
# match the Docker Engine API reference for five of them (name, size, mode,
# mtime, linkTarget); the sixth, isDir, is Podman's own addition -- Docker
# never sends it, not even for a directory. Two more measured differences
# from Docker: linkTarget is populated here even for a plain regular file
# (Podman echoes the resolved path rather than leaving it empty, which is
# what Docker does), and mode is Go's os.FileMode, not a POSIX stat.st_mode
# word -- for this regular file the two are numerically identical (0644, no
# type bits), but they diverge for a directory. See the live subtest below
# for the Docker-side numbers next to these, and for the case that tells
# FileMode and st_mode apart.
my %STAT = (
  # Podman's answer for /etc/hostname. Docker's answer for the same file
  # omits isDir and reports linkTarget as '' rather than the resolved path;
  # see the live subtest below.
  name       => 'hostname',
  size       => 13,
  mode       => 420,
  mtime      => '2026-08-27T15:36:51.589296398Z',
  linkTarget => '/etc/hostname',
);
my $STAT_HEADER = encode_base64(encode_json(\%STAT), '');

# ---------------------------------------------------------------------------
# A client whose socket is an in-memory sink and whose response is canned, so
# the real _request runs -- and with it raw => 1, raw_body, the query string
# and the verb. Same pattern as t/images_tar.t and t/streaming_shape.t; the
# mock harness replaces _request wholesale and can reach none of it.
package Test::ContainersEndpoints::FakeTransport;
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

sub request_line {
  my ($line) = $_[0]->written =~ /\A([^\r\n]+)\r\n/;
  return $line;
}

sub request_body {
  my ($body) = $_[0]->written =~ /\r\n\r\n(.*)\z/s;
  return $body;
}

package main;

sub fake_client {
  return Test::ContainersEndpoints::FakeTransport->new(
    host        => 'unix:///nonexistent.sock',
    api_version => '1.41',
  );
}

# ---------------------------------------------------------------------------
subtest 'the tar fixture really is a tar, so byte-exactness means something' => sub {
  is length($TAR) % 512, 0, 'a whole number of 512-byte blocks';
  is substr($TAR, 257, 5), 'ustar', 'ustar magic in the header block';
  is unpack('Z100', $TAR), 'hostname', 'one member, named after the basename';
  like $TAR, qr/\0/, 'carries NUL bytes -- it is not text';
};

# ===========================================================================
# karr k18 -- the archive endpoints
# ===========================================================================

subtest 'get_archive: asks for raw bytes and hands them back untouched' => sub {
  plan skip_all => 'route assertions are fixture-only' if is_live();

  my %seen;
  my $docker = test_docker(
    'GET /containers/deadbeef/archive' => sub {
      my ($method, $path, %opts) = @_;
      %seen = %opts;
      return $TAR;
    },
  );

  my $out = $docker->containers->get_archive('deadbeef', path => '/etc/hostname');

  ok $seen{raw}, 'the request asked the transport for raw bytes';
  ok !$seen{ndjson}, 'and not for a decoded event stream';
  is_deeply $seen{params}, { path => '/etc/hostname' },
    'path is the only query parameter';
  is $out, $TAR, 'the daemon bytes come back verbatim';
  is length($out), length($TAR), 'no truncation';
};

subtest 'get_archive: raw bytes survive the real _request' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', { 'content-type' => 'application/x-tar' }, $TAR]);

  my $out = $t->containers->get_archive('deadbeef', path => '/var/log/app.log');

  is $out, $TAR, 'byte-exact through _request';
  is $t->request_line,
    'GET /v1.41/containers/deadbeef/archive?path=/var/log/app.log HTTP/1.1',
    'GET on the versioned path, the path parameter keeping its slashes';
};

subtest 'get_archive: a body that looks like JSON is still not decoded' => sub {
  # The transport tries decode_json on any body starting with { or [ unless
  # raw is set. A tar cannot start that way, but the guarantee is "never
  # decoded", not "never decodable" -- so assert it directly.
  my $t = fake_client();
  $t->canned([200, 'OK', {}, '{"name":"not really a tar"}']);

  is ref $t->containers->get_archive('deadbeef', path => '/x'), '',
    'a JSON-shaped body comes back as a plain string, not a HashRef';
};

subtest 'get_archive: the stat out-parameter decodes the header' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK',
    { 'x-docker-container-path-stat' => $STAT_HEADER }, $TAR]);

  my %stat;
  my $out = $t->containers->get_archive('deadbeef',
    path => '/etc/hostname', stat => \%stat);

  is $out, $TAR, 'the return value is still the archive, not the stat';
  is_deeply \%stat, \%STAT,
    'the base64 JSON header is decoded, not handed over as base64';

  # The engine sends the header on this response too, so a caller wanting
  # both does not have to pay for the HEAD as well.
  my $t2 = fake_client();
  $t2->canned([200, 'OK', {}, $TAR]);
  my %empty = ( leftover => 1 );
  $t2->containers->get_archive('deadbeef', path => '/x', stat => \%empty);
  is_deeply \%empty, {}, 'emptied when the engine sent no such header';

  my $err = do { local $@; eval {
    $t->containers->get_archive('deadbeef', path => '/x', stat => 'nope') }; $@ };
  like $err, qr/stat option must be a HashRef/, 'a non-HashRef stat croaks';
};

subtest 'get_archive: the required arguments are required' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, $TAR]);

  my $no_id = do { local $@; eval { $t->containers->get_archive }; $@ };
  like $no_id, qr/Container ID required/, 'a missing id croaks';

  my $no_path = do { local $@; eval {
    $t->containers->get_archive('deadbeef') }; $@ };
  like $no_path, qr/Path required/, 'a missing path croaks';

  my $empty = do { local $@; eval {
    $t->containers->get_archive('deadbeef', path => '') }; $@ };
  like $empty, qr/Path required/, 'an empty path croaks rather than reaching the daemon';
};

subtest 'put_archive: the tar is the request body, the options are the query' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, '']);

  my $out = $t->containers->put_archive('deadbeef', $TAR, path => '/opt/app');

  is $out, undef, 'a success carries no body, so there is nothing to return';
  is $t->request_line, 'PUT /v1.41/containers/deadbeef/archive?path=/opt/app HTTP/1.1',
    'PUT on the archive path';
  like $t->written, qr{Content-Type: application/x-tar\r\n}, 'sent as a tar';
  like $t->written, qr{Content-Length: @{[ length $TAR ]}\r\n}, 'the whole archive';
  is $t->request_body, $TAR, 'the request body is the archive byte for byte';
};

subtest 'put_archive: noOverwriteDirNonDir and copyUIDGID' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, '']);

  $t->containers->put_archive('deadbeef', $TAR,
    path => '/opt/app', noOverwriteDirNonDir => 1, copyUIDGID => 1);
  is $t->request_line,
    'PUT /v1.41/containers/deadbeef/archive?copyUIDGID=1&noOverwriteDirNonDir=1&path=/opt/app HTTP/1.1',
    'both flags on the wire as 1';

  $t->containers->put_archive('deadbeef', $TAR,
    path => '/opt/app', noOverwriteDirNonDir => 0, copyUIDGID => 0);
  is $t->request_line,
    'PUT /v1.41/containers/deadbeef/archive?copyUIDGID=0&noOverwriteDirNonDir=0&path=/opt/app HTTP/1.1',
    'a false flag is sent as 0, not dropped -- the engine reads absence as false too, '
    . 'but a caller that passed it explicitly gets it sent';

  $t->containers->put_archive('deadbeef', $TAR, path => '/opt/app');
  is $t->request_line, 'PUT /v1.41/containers/deadbeef/archive?path=/opt/app HTTP/1.1',
    'neither appears when neither was asked for';
};

subtest 'put_archive: takes a scalar ref, and requires what it requires' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, '']);

  $t->containers->put_archive('deadbeef', \$TAR, path => '/opt/app');
  is $t->request_body, $TAR, 'dereferenced, not stringified';

  my $no_tar = do { local $@; eval {
    $t->containers->put_archive('deadbeef', undef, path => '/opt/app') }; $@ };
  like $no_tar, qr/Tar archive required/, 'a missing archive croaks';

  my $no_path = do { local $@; eval {
    $t->containers->put_archive('deadbeef', $TAR) }; $@ };
  like $no_path, qr/Path required/, 'a missing path croaks';

  my $no_id = do { local $@; eval { $t->containers->put_archive }; $@ };
  like $no_id, qr/Container ID required/, 'a missing id croaks';
};

subtest 'stat_archive: HEAD, and the payload comes out of the header' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', { 'x-docker-container-path-stat' => $STAT_HEADER }, '']);

  my $stat = $t->containers->stat_archive('deadbeef', path => '/etc/hostname');

  is $t->request_line,
    'HEAD /v1.41/containers/deadbeef/archive?path=/etc/hostname HTTP/1.1',
    'the verb is HEAD, not GET';
  is_deeply $stat, \%STAT, 'the header is decoded into a HashRef';
  is $stat->{mode} & 0777, 0644, 'the permission bits are the low nine of mode';
};

subtest 'stat_archive: the base64 alphabet is read tolerantly' => sub {
  # Docker encodes this header with Go's base64.StdEncoding. Decoding is done
  # with the URL-safe characters translated back first, so an engine that
  # reached for the other alphabet is still read rather than croaking.
  my $payload   = encode_json({ name => 'a+b/c', size => 1 });
  my $url_safe  = encode_base64($payload, '');
  $url_safe =~ tr{+/}{-_};

  my $t = fake_client();
  $t->canned([200, 'OK', { 'x-docker-container-path-stat' => $url_safe }, '']);

  is_deeply $t->containers->stat_archive('deadbeef', path => '/x'),
    { name => 'a+b/c', size => 1 },
    'a URL-safe encoding decodes to the same JSON';
};

subtest 'stat_archive: nothing to decode, and something undecodable' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, '']);
  is $t->containers->stat_archive('deadbeef', path => '/x'), undef,
    'undef when the engine sent no stat header at all';

  $t->canned([200, 'OK', { 'x-docker-container-path-stat' => '' }, '']);
  is $t->containers->stat_archive('deadbeef', path => '/x'), undef,
    'undef for an empty header, not a croak';

  $t->canned([200, 'OK',
    { 'x-docker-container-path-stat' => 'bm90IEpTT04=' }, '']);
  my $err = do { local $@; eval {
    $t->containers->stat_archive('deadbeef', path => '/x') }; $@ };
  like $err, qr/Cannot decode X-Docker-Container-Path-Stat/,
    'base64 that is not JSON croaks and names the header';

  my $no_path = do { local $@; eval {
    $t->containers->stat_archive('deadbeef') }; $@ };
  like $no_path, qr/Path required/, 'a missing path croaks';
};

subtest 'stat_archive: a missing path is a croak, not an undef' => sub {
  # The transport croaks on >= 400 before anything here can look at headers,
  # so "no such file" and "no stat header" are different outcomes and a caller
  # testing for undef will not silently swallow the first.
  my $t = fake_client();
  $t->canned([404, 'Not Found', {},
    '{"cause":"no such file or directory","message":"Could not find the file /nope in container deadbeef","response":404}']);

  my $err = do { local $@; eval {
    $t->containers->stat_archive('deadbeef', path => '/nope') }; $@ };
  like $err, qr/Docker API error \(404\)/, 'the status handling croaks first';
  like $err, qr/Could not find the file/, 'with the message key';
};

# ===========================================================================
# karr k19 -- the one-way attach
# ===========================================================================

subtest 'attach: demultiplexes exactly as logs does' => sub {
  plan skip_all => 'route assertions are fixture-only' if is_live();

  # The inspect route is what attach's running-container check asks for; a
  # running container lets the call through, which is the path this subtest
  # is about. The check itself is covered further down.
  my $docker = test_docker(
    'POST /containers/deadbeef/attach' => sub { $FRAMES },
    'GET /containers/deadbeef/logs'    => sub { $FRAMES },
    'GET /containers/deadbeef/json'    => { State => { Running => 1 } },
  );

  my $attached = $docker->containers->attach('deadbeef');
  is_deeply $attached, [
    { stream => 'stdout', data => "OUT\n" },
    { stream => 'stderr', data => "ERR\n" },
  ], 'two frames, headers stripped';

  is_deeply $attached, $docker->containers->logs('deadbeef'),
    'the same bytes give the same frames through either method';

  is join('', map { $_->{data} } @$attached), "OUT\nERR\n",
    'joining the payloads gives the plain text';
};

subtest 'attach: the query parameters, and the defaults that differ from the engine' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, $FRAMES]);

  # The default that matters: stream=0, the engine's own default, plus logs=1
  # so the call still has something to return. Measured on Podman 5.4.2 (API
  # 1.41) against one exited container: ?logs=1&stdout=1&stderr=1&stream=0
  # answers 200 and closes after 13ms, while the same request with stream=1
  # sends the identical 24 bytes and then never closes -- attach hijacks the
  # connection, so there is no Content-Length and no chunked terminator, and
  # stream's only terminator (the container ending) is already in the past.
  # Turning stream back on by default puts every attach() on a stopped
  # container back into that hang, which is what this assertion guards.
  # require_running => 0 throughout: this subtest is about the query string,
  # and the running-container check would otherwise put a GET .../json between
  # the call and the request line being asserted. That it does not appear here
  # is itself the point -- opting out skips the round trip rather than making
  # it and ignoring the answer.
  $t->containers->attach('deadbeef', require_running => 0);
  is $t->request_line,
    'POST /v1.41/containers/deadbeef/attach?logs=1&stderr=1&stdout=1&stream=0 HTTP/1.1',
    'stream defaults OFF as the engine does, logs defaults ON so the call replays';

  $t->containers->attach('deadbeef', require_running => 0,
    stream => 1, stdout => 0, stderr => 0, stdin => 1, logs => 0);
  is $t->request_line,
    'POST /v1.41/containers/deadbeef/attach?logs=0&stderr=0&stdin=1&stdout=0&stream=1 HTTP/1.1',
    'every one of the five is sent as asked, false as 0';

  $t->containers->attach('deadbeef', stdin => 0, require_running => 0);
  is $t->request_line,
    'POST /v1.41/containers/deadbeef/attach?logs=1&stderr=1&stdin=0&stdout=1&stream=0 HTTP/1.1',
    'stdin appears only when named; a false one is still sent';

  # logs => 0 alone leaves both flags off, which the engine refuses outright:
  # Podman answers 400 "at least one of Logs or Stream must be set". The
  # client passes it through rather than second-guessing it.
  $t->containers->attach('deadbeef', logs => 0, require_running => 0);
  is $t->request_line,
    'POST /v1.41/containers/deadbeef/attach?logs=0&stderr=1&stdout=1&stream=0 HTTP/1.1',
    'logs => 0 alone is sent as asked -- the both-off 400 is the engine\'s call';

  # require_running is a client-side option and must not reach the engine as
  # one: the engine has no such query parameter and would ignore it silently.
  unlike $t->request_line, qr/require_running/,
    'require_running is consumed here, never sent as a query parameter';

  my $err = do { local $@; eval { $t->containers->attach }; $@ };
  like $err, qr/Container ID required/, 'a missing id croaks';
};

subtest 'attach: it is a POST with no body, not a GET' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, $FRAMES]);
  $t->containers->attach('deadbeef', require_running => 0);

  like $t->written, qr{\APOST /v1\.41/containers/deadbeef/attach\?},
    'POST, as the engine requires for this endpoint';
  is $t->request_body, '', 'and no request body -- every option is in the query';
  unlike $t->written, qr/Upgrade:/i,
    'no Upgrade header: this is the 200 one-way variant, not the 101 upgraded one';
};

subtest 'attach: tty skips demultiplexing' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, "OUT\r\nERR\r\n"]);

  is_deeply $t->containers->attach('deadbeef', tty => 1, require_running => 0),
    [ { stream => 'raw', data => "OUT\r\nERR\r\n" } ],
    'a TTY attach comes back as one raw frame';

  # And the framing is detected from the bytes when tty was not declared,
  # so the common case needs no flag.
  is_deeply $t->containers->attach('deadbeef', require_running => 0),
    [ { stream => 'raw', data => "OUT\r\nERR\r\n" } ],
    'unframed bytes are reported raw without being told';

  $t->canned([200, 'OK', {}, $FRAMES]);
  is_deeply $t->containers->attach('deadbeef', tty => 1, require_running => 0),
    [ { stream => 'raw', data => $FRAMES } ],
    'tty => 1 suppresses the walk even on bytes that would have framed';
};

# ===========================================================================
# karr k53 -- attach refuses a container that is not running
#
# Measured on Podman 5.4.2 (API 1.41) and Docker 29.7.2 (API 1.55), one
# container per row, each exiting with status 4:
#
#   attach to an ALREADY-EXITED container       Podman: status destroyed
#   attach while RUNNING, exits under the call  Podman: status intact (4)
#   either of those                             Docker: status intact (4)
#
# On Podman the exited container drops back to Status: created with ExitCode
# 0, and a later wait answers {"StatusCode":-1} inside a 200. Nothing reports
# it and the engine keeps no copy, so the caller cannot recover the value --
# which is why this one is guarded and stats (karr k54) is not: there the
# caller can always ask again afterwards.
# ===========================================================================

subtest 'attach: refuses a container that is not running, before sending anything' => sub {
  plan skip_all => 'route assertions are fixture-only' if is_live();

  my %called;
  my $docker = test_docker(
    'GET /containers/deadbeef/json' => sub {
      $called{inspect}++;
      return { State => { Running => 0, Status => 'exited', ExitCode => 4 } };
    },
    'POST /containers/deadbeef/attach' => sub { $called{attach}++; return $FRAMES },
  );

  my $err = do { local $@; eval { $docker->containers->attach('deadbeef') }; $@ };

  like $err, qr/attach refused/, 'attaching to a stopped container croaks';
  like $err, qr/\bexited\b/, 'and names the state the engine reported';
  like $err, qr/destroys its exit status on Podman/,
    'and says what the refusal is protecting';
  like $err, qr/logs\(\)/, 'and points at the method that reads it safely';
  like $err, qr/require_running => 0/, 'and names the way past it';

  is $called{inspect}, 1, 'the check cost exactly one inspect';

  # The whole point of the check being pre-flight: the attach request is
  # itself what destroys the exit status, so a check that let it go out and
  # complained afterwards would report the loss rather than prevent it.
  ok !$called{attach}, 'and the attach request was never sent';
};

subtest 'attach: require_running => 0 attaches anyway, and skips the round trip' => sub {
  plan skip_all => 'route assertions are fixture-only' if is_live();

  my %called;
  my $docker = test_docker(
    'GET /containers/deadbeef/json' => sub {
      $called{inspect}++;
      return { State => { Running => 0, Status => 'exited' } };
    },
    'POST /containers/deadbeef/attach' => sub { $called{attach}++; return $FRAMES },
  );

  is_deeply $docker->containers->attach('deadbeef', require_running => 0), [
    { stream => 'stdout', data => "OUT\n" },
    { stream => 'stderr', data => "ERR\n" },
  ], 'the frames come back from a stopped container when the check is off';

  is $called{attach}, 1, 'the attach request went out';
  ok !$called{inspect},
    'and no inspect was made -- opting out skips the check, not just its verdict';
};

subtest 'attach: the check reads State.Running, and fails open when it cannot' => sub {
  plan skip_all => 'route assertions are fixture-only' if is_live();

  my %called;
  my $running = test_docker(
    'GET /containers/deadbeef/json' =>
      { State => { Running => 1, Status => 'running' } },
    'POST /containers/deadbeef/attach' => sub { $called{attach}++; return $FRAMES },
  );

  is scalar @{ $running->containers->attach('deadbeef') }, 2,
    'a running container attaches normally -- the check does not stand in the way';
  is $called{attach}, 1, 'and the attach request did go out';

  # Anything the check cannot read is not evidence that the container is
  # stopped. A guard that is unsure must not be the thing that breaks a
  # working call, so each of these proceeds instead of croaking.
  for my $case (
    [ 'no State at all'          => {} ],
    [ 'a State without Running'  => { State => { Status => 'exited' } } ],
    [ 'a State that is a string' => { State => 'exited' } ],
  ) {
    my ($name, $body) = @$case;
    my $t = test_docker(
      'GET /containers/deadbeef/json'    => $body,
      'POST /containers/deadbeef/attach' => sub { $FRAMES },
    );
    my $out = do { local $@; eval { $t->containers->attach('deadbeef') } };
    is ref $out, 'ARRAY', "$name: the check fails open and the attach proceeds";
  }

  # The third case above used to be carried by an eval inside
  # _assert_container_running, which swallowed the Error::TypeTiny a typed
  # class threw on a State the swagger does not allow. The model keeps such a
  # value now instead of croaking (karr k83), so the inspect itself is what
  # holds the case up -- the same claim, resting on the model rather than on
  # the workaround.
  my $t = test_docker('GET /containers/deadbeef/json' => { Id => 'deadbeef',
    Name => '/keep', State => 'exited' });
  my $inspected = $t->containers->inspect('deadbeef');
  isa_ok $inspected, 'API::Docker::Type::ContainerInspectResponse';
  is $inspected->name, '/keep',
    'a State the swagger does not allow no longer costs the whole inspect';
  is $inspected->state, undef, 'the field it could not use is unset';
  is_deeply $inspected->rejected_fields, { State => 'state' },
    'and is reported as sent-but-refused rather than as absent';
  is $inspected->TO_JSON->{State}, 'exited',
    'while the raw value still reaches TO_JSON unchanged';
};

subtest 'attach: an empty stream is an empty ArrayRef' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, '']);
  is_deeply $t->containers->attach('deadbeef', require_running => 0), [],
    'a container that wrote nothing gives no frames, not undef';
};

# ===========================================================================
# karr k23 -- changes, export, resize
# ===========================================================================

subtest 'changes: the diff, and what the Kind numbers are' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', { 'content-type' => 'application/json' },
    '[{"Path":"/etc/hostname","Kind":0},{"Path":"/tmp/new","Kind":1},'
    . '{"Path":"/etc/gone","Kind":2}]']);

  my $changes = $t->containers->changes('deadbeef');

  is $t->request_line, 'GET /v1.41/containers/deadbeef/changes HTTP/1.1',
    'GET on the changes path, no query parameters';
  is ref $changes, 'ARRAY', 'an ArrayRef';
  is scalar @$changes, 3, 'one entry per changed path';
  is_deeply $changes->[0], { Path => '/etc/hostname', Kind => 0 }, '0 is modified';
  is_deeply $changes->[1], { Path => '/tmp/new',      Kind => 1 }, '1 is added';
  is_deeply $changes->[2], { Path => '/etc/gone',     Kind => 2 }, '2 is deleted';

  my $err = do { local $@; eval { $t->containers->changes }; $@ };
  like $err, qr/Container ID required/, 'a missing id croaks';
};

subtest 'changes: a container with nothing changed is an empty ArrayRef' => sub {
  # The engine answers that case with a JSON null. The transport decodes any
  # JSON body, scalars included (karr k30), so a null body reaches this
  # method as undef -- which a caller iterating the result would dereference
  # and die on just the same.
  my $t = fake_client();
  $t->canned([200, 'OK', { 'content-type' => 'application/json' }, 'null']);

  is_deeply $t->containers->changes('deadbeef'), [],
    'a null body is normalised to an empty ArrayRef, not left as undef';

  $t->canned([204, 'No Content', {}, '']);
  is_deeply $t->containers->changes('deadbeef'), [],
    'and so is an empty body';
};

subtest 'export: raw tar bytes, never decoded' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', { 'content-type' => 'application/x-tar' }, $TAR]);

  my $out = $t->containers->export('deadbeef');

  is $t->request_line, 'GET /v1.41/containers/deadbeef/export HTTP/1.1',
    'GET on the export path';
  is $out, $TAR, 'byte-exact';
  is length($out), length($TAR), 'no truncation';

  $t->canned([200, 'OK', {}, '{"Id":"not really a tar"}']);
  is ref $t->containers->export('deadbeef'), '',
    'a JSON-shaped body is not decoded either';

  my $err = do { local $@; eval { $t->containers->export }; $@ };
  like $err, qr/Container ID required/, 'a missing id croaks';
};

subtest 'resize: form-identical to the one Exec already had' => sub {
  my $t = fake_client();
  $t->canned([200, 'OK', {}, '']);

  $t->containers->resize('deadbeef', h => 40, w => 120);
  is $t->request_line, 'POST /v1.41/containers/deadbeef/resize?h=40&w=120 HTTP/1.1',
    'w and h as query parameters on a POST with no body';
  is $t->request_body, '', 'no request body';

  $t->exec->resize('deadbeef', h => 40, w => 120);
  is $t->request_line, 'POST /v1.41/exec/deadbeef/resize?h=40&w=120 HTTP/1.1',
    'the exec one spells the query identically -- the two classes no longer '
    . 'disagree about the same capability';

  $t->containers->resize('deadbeef', w => 80);
  is $t->request_line, 'POST /v1.41/containers/deadbeef/resize?w=80 HTTP/1.1',
    'an option that was not given is not sent, as in Exec::resize';

  my $err = do { local $@; eval { $t->containers->resize }; $@ };
  like $err, qr/Container ID required/, 'a missing id croaks';
};

# ===========================================================================
# The entity forwards
# ===========================================================================

subtest 'the container entity forwards all six' => sub {
  plan skip_all => 'route assertions are fixture-only' if is_live();

  my %seen;
  my $docker = test_docker(
    'GET /containers/json' => [ { Id => 'deadbeef', Names => ['/c'] } ],
    'GET /containers/deadbeef/archive'  => sub { $seen{get_archive}++;  $TAR },
    'PUT /containers/deadbeef/archive'  => sub { $seen{put_archive}++;  undef },
    'HEAD /containers/deadbeef/archive' => sub {
      $seen{stat_archive}++;
      mock_response(headers => { 'X-Docker-Container-Path-Stat' => $STAT_HEADER });
    },
    'POST /containers/deadbeef/attach'  => sub { $seen{attach}++; $FRAMES },
    # The entity forwards %opts to the API class, so it inherits attach's
    # running-container check along with everything else -- which is why a
    # forwarding test needs the endpoint that check asks for.
    'GET /containers/deadbeef/json'     => { State => { Running => 1 } },
    'GET /containers/deadbeef/changes'  => sub { $seen{changes}++; [] },
    'GET /containers/deadbeef/export'   => sub { $seen{export}++;  $TAR },
    'POST /containers/deadbeef/resize'  => sub { $seen{resize}++;  undef },
  );

  # The client must stay in a live variable: entities hold it as a weak_ref.
  my ($container) = @{ $docker->containers->list };
  isa_ok $container, 'API::Docker::Type::ContainerSummary';

  is $container->get_archive(path => '/etc/hostname'), $TAR, 'get_archive';
  is $container->put_archive($TAR, path => '/opt'), undef, 'put_archive';
  is_deeply $container->stat_archive(path => '/etc/hostname'), \%STAT, 'stat_archive';
  is scalar @{ $container->attach }, 2, 'attach';
  is_deeply $container->changes, [], 'changes';
  is $container->export, $TAR, 'export';
  is $container->resize(h => 40, w => 120), undef, 'resize';

  is_deeply \%seen, {
    get_archive => 1, put_archive => 1, stat_archive => 1,
    attach => 1, changes => 1, export => 1, resize => 1,
  }, 'each forward reached its own endpoint exactly once';
};

# ===========================================================================
# Live, read-only. These need a container that already exists on the daemon;
# creating one is a write and out of scope for the work that added them.
#
# attach is deliberately not here: the transport buffers, so attaching to a
# container that keeps running never returns. export is not here either -- it
# would buffer the whole filesystem in RAM.
# ===========================================================================

sub live_container {
  my $docker = shift;
  my ($c) = grep { $_->id } @{ $docker->containers->list(all => 1) };
  return $c;
}

subtest 'live: changes and the archive endpoints against a real container' => sub {
  plan skip_all => 'live only' unless is_live();

  my $docker = test_docker();
  my $container = live_container($docker);
  plan skip_all => 'no container on the daemon to read from' unless $container;

  my $changes = $docker->containers->changes($container->id);
  is ref $changes, 'ARRAY', 'changes returns an ArrayRef';
  for my $change (@$changes) {
    ok defined $change->{Path}, 'each entry has a Path';
    like $change->{Kind}, qr/\A[012]\z/, 'and a Kind of 0, 1 or 2';
  }

  my $engine = live_engine();

  my $stat = $docker->containers->stat_archive($container->id,
    path => '/etc/hostname');
  ok defined $stat, 'stat_archive found /etc/hostname';
  is ref $stat, 'HASH', 'and decoded the header into a HashRef';

  # What both engines agree on for a plain regular file: name is the
  # basename and the low nine bits of mode are the POSIX permission bits.
  is $stat->{name}, 'hostname', 'name is the basename, not the full path';
  is $stat->{mode} & 0777, 0644, 'the permission bits are the low nine of mode';

  # The key set and isDir/linkTarget do not: side-by-side measurement against
  # both engines (karr k36, later re-verified against a real Docker daemon --
  # 29.7.2, API 1.55 -- next to Podman 5.4.2, API 1.41, same container, same
  # file) found isDir is Podman's own addition, confirmed rather than
  # guessed: Docker never sends it, not even for a directory. linkTarget
  # differs too -- Docker leaves it empty for a plain file, matching the
  # Docker Engine API reference; Podman echoes the resolved path instead.
  if ($engine eq 'podman') {
    is_deeply [ sort keys %$stat ], [qw( isDir linkTarget mode mtime name size )],
      'Podman: six keys, isDir alongside the five the reference documents';
    is $stat->{linkTarget}, '/etc/hostname',
      'Podman: linkTarget is populated even for a plain regular file -- it '
      . 'echoes the resolved path here rather than leaving it empty';
    ok !$stat->{isDir}, 'Podman: /etc/hostname is not a directory';
  }
  else {
    is_deeply [ sort keys %$stat ], [qw( linkTarget mode mtime name size )],
      'Docker: exactly the five keys the Engine API reference documents, no isDir';
    is $stat->{linkTarget}, '',
      'Docker: linkTarget is left empty for a plain regular file';
    ok !exists $stat->{isDir}, 'Docker: isDir is absent, not merely false';
  }

  # mode itself is Go's os.FileMode, not a POSIX stat.st_mode word -- for a
  # regular file the two coincide (no type bits set), so the check above does
  # not by itself tell them apart. A directory does, on both engines: Go sets
  # os.ModeDir (1<<31) above the permission bits, where POSIX would set
  # S_IFDIR (0040000) at an entirely different position.
  my $dir_stat = $docker->containers->stat_archive($container->id, path => '/etc');
  ok $dir_stat->{mode} & (1 << 31),
    'mode carries Go os.ModeDir above the permission bits -- proof this is '
    . 'FileMode, not raw POSIX stat.st_mode, which never sets that bit';

  if ($engine eq 'podman') {
    ok $dir_stat->{isDir}, 'Podman: /etc is a directory';
  }
  else {
    ok !exists $dir_stat->{isDir}, 'Docker: isDir is absent for a directory too';
  }

  my $tar = $docker->containers->get_archive($container->id,
    path => '/etc/hostname');
  ok defined $tar && length $tar, 'get_archive returned bytes';
  is length($tar) % 512, 0, 'a whole number of tar blocks';
  is substr($tar, 257, 5), 'ustar', 'ustar magic';
  is unpack('Z100', $tar), 'hostname', 'the member is the basename';
};

subtest 'live write: stat_archive on a symlink diverges by engine (karr k36)' => sub {
  plan skip_all => 'live only'       unless is_live();
  plan skip_all => 'write tests off' unless can_write();

  my $docker = test_docker();
  my ($base) = grep { $_->repo_tags && @{ $_->repo_tags } } @{ $docker->images->list };
  plan skip_all => 'no tagged image to base a container on' unless $base;

  # A container of our own: the read-only subtest above cannot pick a symlink
  # off whatever container happens to already exist, so this one creates it,
  # names it apidocker-stat- as agreed, and removes it again below.
  my $created = $docker->containers->create(
    Image => $base->repo_tags->[0],
    Cmd   => [ '/bin/sh', '-c', 'ln -s /etc/hostname /tmp/hnlink' ],
    name  => 'apidocker-stat-symlink-' . $$,
  );
  my $id = $created->{Id};
  register_cleanup(sub { eval { $docker->containers->remove($id, force => 1) } });

  $docker->containers->start($id);
  $docker->containers->wait($id);

  my $stat = $docker->containers->stat_archive($id, path => '/tmp/hnlink');
  ok defined $stat, 'stat_archive found the symlink';

  # Measured for /tmp/hnlink -> /etc/hostname: both engines agree on
  # linkTarget (the resolved target path) and on mode (Go's ModeSymlink,
  # 1<<27, plus the symlink's own 0777) -- but not on name. Docker reports
  # the link itself; Podman resolves through it and reports the target's
  # basename instead.
  is $stat->{linkTarget}, '/etc/hostname',
    'both engines resolve linkTarget to the symlink\'s destination';
  ok $stat->{mode} & (1 << 27),
    'mode carries Go ModeSymlink above the permission bits on both engines';
  is $stat->{mode} & 0777, 0777, 'a symlink\'s own permission bits are 0777 on both';

  my $engine = live_engine();
  if ($engine eq 'podman') {
    is $stat->{name}, 'hostname',
      'Podman fully resolves the symlink -- name is the target\'s basename, not the link\'s';
  }
  else {
    is $stat->{name}, 'hnlink',
      'Docker reports the link itself -- name is the symlink\'s own basename';
  }
};

done_testing;
