#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::API::Docker::Mock;
use JSON::MaybeXS qw( encode_json );
use API::Docker;
use API::Docker::Error::Stream;

# Regression coverage for karr #4: build, pull and push returned the event
# list and left failure detection to the caller, while the daemon had already
# answered HTTP 200 -- so a broken build was indistinguishable from a good one
# unless the caller knew to scan for errorDetail. They now croak with an
# API::Docker::Error::Stream carrying the whole stream.
#
# Nothing here opens a socket: the ndjson path is driven through a subclass
# that fakes the transport, so this file is safe with no engine present. The
# .ndjson fixtures are streams captured from the rootless Podman socket
# (5.4.2, API 1.41).

check_live_access();

{
  package Test::StreamError::FakeTransport;
  use Moo;
  extends 'API::Docker';
  has canned => ( is => 'rw' );
  sub _build__socket { open my $fh, '>', \my $sink or die $!; return $fh }
  sub _read_response { return $_[0]->canned }
}

sub transport {
  my ($body) = @_;
  return Test::StreamError::FakeTransport->new(
    host        => 'unix:///nonexistent.sock',
    api_version => '1.41',
    canned      => [ 200, 'OK', {}, $body ],
  );
}

# ---------------------------------------------------------------------------
subtest 'a build whose stream carries errorDetail croaks' => sub {
  my $t = transport(load_fixture_raw('images_build_error_stream.ndjson'));

  my $events = eval { $t->images->build(context => 'tar-bytes', t => 'app:v1') };
  my $err = $@;

  ok !defined $events, 'nothing is returned -- the failure is not a value';
  ok $err, 'it croaked';
  isa_ok $err, 'API::Docker::Error::Stream';
  like "$err", qr/exit status 7/,
    'the engine\'s own reason is in the message, not a generic "build failed"';
  like "$err", qr{\QPOST /v1.41/build\E},
    'and the request it belongs to';
};

subtest 'the exception carries the whole stream, not just the error' => sub {
  my $t = transport(load_fixture_raw('images_build_error_stream.ndjson'));
  eval { $t->images->build(context => 'tar-bytes') };
  my $err = $@;

  is ref $err->events, 'ARRAY', 'events is an ArrayRef';
  is scalar @{ $err->events }, 3,
    'all three events, the two progress lines included -- the build output '
    . 'is not lost with the return value';
  is $err->events->[0]{stream}, "STEP 1/2: FROM alpine:3\n",
    'in stream order, starting at the first step';
  ok $err->events->[2]{errorDetail}, 'the error event is in there too';

  # The message is trimmed for the exception text; the events must be the
  # stream as the engine sent it, not a copy edited on the way past.
  like $err->events->[2]{errorDetail}{message}, qr/\n\z/,
    'the carried event keeps the trailing newline the engine sent';
  unlike $err->message, qr/\n\z/, 'while the exception message is trimmed';
};

# ---------------------------------------------------------------------------
subtest 'a successful stream must not croak' => sub {
  for my $fixture (qw(
    images_build_stream.ndjson
    images_build_quiet_stream.ndjson
    images_pull_stream.ndjson
  )) {
    my $t = transport(load_fixture_raw($fixture));
    my $events = eval { $t->_request('POST', '/build', ndjson => 1) };
    is $@, '', "$fixture does not croak";
    is ref $events, 'ARRAY', "$fixture still returns an ArrayRef";
  }
};

subtest 'the word "error" in ordinary payload data is not a failure' => sub {
  # A build that prints the word to stdout, and a pull whose status mentions
  # it: the trigger is the errorDetail key, never the text.
  my $body = encode_json({ stream => "npm ERR! errorDetail: nope\n" }) . "\n"
    . encode_json({ status => 'error recovering, retrying' }) . "\n";
  my $events = eval { transport($body)->_request('POST', '/build', ndjson => 1) };
  is $@, '', 'no croak';
  is scalar @$events, 2, 'both events returned';
};

subtest 'system->events never croaks on its own data' => sub {
  # The /events feed opts out: an object in it records something that
  # happened on the engine, so it is data even shaped like a failure.
  my $t = transport(load_fixture_raw('system_events_stream.ndjson'));
  my $events = eval { $t->system->events(since => 1, until => 2) };
  is $@, '', 'a captured podman event stream does not croak';
  is scalar @$events, 5, 'all five events';

  my $hostile = encode_json({ Type => 'container', Action => 'die' }) . "\n"
    . encode_json({ errorDetail => { message => 'this is event data' } }) . "\n";
  $t = transport($hostile);
  $events = eval { $t->system->events(since => 1, until => 2) };
  is $@, '', 'and neither does one that literally carries errorDetail';
  is scalar @$events, 2, 'the event is handed over as data';
};

# ---------------------------------------------------------------------------
subtest 'the stringification contract' => sub {
  my $t = transport(load_fixture_raw('images_build_error_stream.ndjson'));
  eval { $t->images->build(context => 'tar-bytes') };
  my $err = $@;

  # Everything else in this distribution croaks strings and consumers rely on
  # it -- ../p5-dist-zilla-plugin-docker-api strips Carp's location tail off
  # $@ with a substitution. All of this has to keep working unchanged.
  like "$err", qr/ at \S+ line \d+\.?/,
    'carries Carp\'s location suffix, exactly as the plain croak it replaces';
  like $err, qr/exit status 7/, 'matches a regex without an explicit stringify';
  ok $err, 'boolean-true, so if ($@) still detects it';
  is $err . '', "$err", 'concatenation goes through the overload';
  is sprintf('%s', $err), "$err", 'so does sprintf %s';
  ok $err eq "$err", 'and string comparison';

  is $err->message . $err->location, "$err",
    'message and location are separable, and together they are the string';
  unlike $err->message, qr/ at \S+ line \d+/,
    'message on its own is the bare reason, no location';

  # The consumer's exact treatment, from Dist::Zilla::Plugin::Docker::API.
  my $copy = $err;
  $copy =~ s/\s+at\s+\S+\s+line\s+\d+\.?//g;
  $copy =~ s/\s+/ /g;
  $copy =~ s/^\s+|\s+$//g;
  is ref \$copy, 'SCALAR', 's/// on the exception yields a plain string';
  like $copy, qr/exit status 7\z/,
    'the location is stripped and the reason survives';
  isa_ok $err, 'API::Docker::Error::Stream',
    'the original is untouched by the copy\'s substitution';
};

subtest 'a message that ends in a newline still gets a location' => sub {
  # Engine messages end in "\n" and Carp appends no location to a message
  # that already does, so the trailing whitespace has to come off first.
  my $body = encode_json({ errorDetail => { message => "boom\n" } }) . "\n";
  eval { transport($body)->_request('POST', '/build', ndjson => 1) };
  like "$@", qr/boom at \S+ line \d+\./,
    'the trailing newline is trimmed and the suffix lands';
};

subtest 'errorDetail without a usable message falls back' => sub {
  my $body = encode_json({ errorDetail => {}, error => 'flat error text' }) . "\n";
  eval { transport($body)->_request('POST', '/build', ndjson => 1) };
  like "$@", qr/flat error text/,
    'the flat error key is the fallback when errorDetail has no message';

  $body = encode_json({ errorDetail => {} }) . "\n";
  eval { transport($body)->_request('POST', '/build', ndjson => 1) };
  like "$@", qr/no message given/, 'and there is a last resort';
  isa_ok $@, 'API::Docker::Error::Stream', 'still the exception class';
};

subtest 'the query string stays out of the message' => sub {
  # /build carries buildargs in the query string, which can hold credentials.
  my $body = encode_json({ errorDetail => { message => 'nope' } }) . "\n";
  eval {
    transport($body)->_request('POST', '/build',
      ndjson => 1,
      params => { t => 'app:v1', buildargs => { NPM_TOKEN => 'sekrit' } },
    );
  };
  like "$@", qr{\QPOST /v1.41/build\E}, 'the endpoint is named';
  unlike "$@", qr/sekrit/, 'the build args are not';
};

# ---------------------------------------------------------------------------
SKIP: {
  skip 'mock routes are bypassed in live mode', 1 if is_live();

  subtest 'which endpoints opt out of the check' => sub {
    my %saw;
    my $docker = test_docker(
      'POST /build'             => sub { $saw{build} = { @_[2 .. $#_] }; [] },
      'POST /images/create'     => sub { $saw{pull}  = { @_[2 .. $#_] }; [] },
      'POST /images/nginx/push' => sub { $saw{push}  = { @_[2 .. $#_] }; [] },
      'GET /events'             => sub { $saw{events} = { @_[2 .. $#_] }; [] },
    );

    $docker->images->build(context => 'tar-bytes', t => 'x:1');
    $docker->images->pull(fromImage => 'nginx');
    $docker->images->push('nginx');
    $docker->system->events(since => 1, until => 2);

    # The check defaults on, so an operation endpoint says nothing at all --
    # a new streaming endpoint gets the loud behaviour without being told.
    ok !exists $saw{$_}{croak_on_error}, "$_ leaves the check at its default"
      for qw( build pull push );
    is $saw{events}{croak_on_error}, 0, 'events is the one endpoint opting out';
  };
}

SKIP: {
  skip 'live write tests disabled (API_DOCKER_TEST_WRITE=1 to enable)', 1
    unless can_write();

  subtest 'live: a build that fails croaks against a real engine' => sub {
    # Measured, not assumed: the engine answers 200 and reports the failure
    # inside the stream. Nothing is left behind -- the build never commits an
    # image, and rm=1 (the default) drops the intermediate container.
    my $docker = API::Docker->new(host => $ENV{API_DOCKER_TEST_HOST});

    my $dockerfile = "FROM alpine:3\nRUN exit 7\n";
    my $tar = _tar_context($dockerfile);

    my $events = eval {
      $docker->images->build(context => $tar, t => 'apidocker-stream-error:test')
    };
    my $err = $@;

    ok !defined $events, 'no return value from the failed build';
    isa_ok $err, 'API::Docker::Error::Stream';
    like "$err", qr/exit status 7/, 'the engine reported the RUN exit status';
    ok scalar @{ $err->events } > 1, 'the build output came with it';

    my $tagged = eval { $docker->images->inspect('apidocker-stream-error:test') };
    ok !$tagged, 'the failed build left no tagged image behind';
  };
}

# A minimal ustar archive holding one file, so the live build needs no
# Archive::Tar.
sub _tar_context {
  my ($content) = @_;
  my $name = 'Dockerfile';
  my $header = pack 'a100 a8 a8 a8 a12 a12 A8 a1 a100 a255',
    $name, '0000644', '0000000', '0000000',
    sprintf('%011o', length $content), sprintf('%011o', time),
    '', '0', '', '';
  my $checksum = 0;
  $checksum += $_ for unpack 'C*', $header;
  substr($header, 148, 8) = sprintf('%06o', $checksum) . "\0 ";
  my $body = $content . "\0" x ((512 - length($content) % 512) % 512);
  return $header . $body . "\0" x 1024;
}

done_testing;
