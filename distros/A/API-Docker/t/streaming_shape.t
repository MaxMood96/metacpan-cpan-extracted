#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::API::Docker::Mock;
use JSON::MaybeXS;
use API::Docker;

# Regression coverage for karr k3: _request tried decode_json on the whole
# body first and only fell back to line-by-line parsing, so a stream carrying
# exactly one JSON object came back as a HashRef while a multi-event stream
# came back as an ArrayRef. Every .ndjson fixture below is a stream captured
# from the rootless Podman socket (5.4.2, API 1.41).

check_live_access();

# A client whose socket is an in-memory handle and whose response is canned,
# so _request's own decode branches can be exercised without a daemon. The
# mock harness replaces _request wholesale and cannot reach them.
{
  package Test::FakeTransport;
  use Moo;
  extends 'API::Docker';
  has canned => ( is => 'rw' );
  sub _build__socket { open my $fh, '>', \my $sink or die $!; return $fh }
  sub _read_response { return $_[0]->canned }
}

my $client = API::Docker->new(
  host        => 'unix:///var/run/docker.sock',
  api_version => '1.41',
);

subtest 'a single-object stream is still an ArrayRef' => sub {
  # POST /build?q=1 emits exactly one object. Under the old logic
  # decode_json() on the whole body succeeded and returned a HashRef.
  my $body = load_fixture_raw('images_build_quiet_stream.ndjson');
  my @lines = split /\n/, $body;
  is scalar @lines, 1, 'the fixture really is a one-line stream';

  my $events = $client->_decode_stream($body);
  is ref $events, 'ARRAY', 'ArrayRef, not HashRef';
  is scalar @$events, 1, 'one event';
  like $events->[0]{stream}, qr/^[0-9a-f]{64}\n$/,
    'the event is the built image id';
};

subtest 'a multi-object stream is an ArrayRef of every event' => sub {
  my $events = $client->_decode_stream(
    load_fixture_raw('images_build_stream.ndjson'));
  is ref $events, 'ARRAY', 'ArrayRef';
  is scalar @$events, 10, 'all ten build events';
  is $events->[0]{stream}, "STEP 1/2: FROM alpine:3\n", 'first event';

  my ($aux) = grep { $_->{aux} } @$events;
  ok $aux, 'the aux event survives';
  like $aux->{aux}{ID}, qr/^sha256:[0-9a-f]{64}$/, 'aux carries the image id';

  my $pull = $client->_decode_stream(
    load_fixture_raw('images_pull_stream.ndjson'));
  is scalar @$pull, 4, 'all four pull events';
  is $pull->[0]{status}, 'Already exists', 'first pull event';
};

subtest 'the /events stream decodes to an ArrayRef' => sub {
  # Captured from Podman 5.4.2 (API 1.41) for one container
  # create/init/start/died/remove cycle. karr k62 re-measured the identical
  # flow live on 5.8.4 (API 1.44) and found a sixth action, "cleanup",
  # between die and remove -- this fixture predates that and is not
  # recaptured for it: the point of this subtest is that a multi-line body
  # decodes to one ArrayRef entry per line, which five lines demonstrate as
  # well as six would. The whole body is not valid JSON on its own -- only
  # line by line.
  my $body = load_fixture_raw('system_events_stream.ndjson');
  is eval { JSON::MaybeXS::decode_json($body) }, undef,
    'the body does not decode as a single JSON document';

  my $events = $client->_decode_stream($body);
  is ref $events, 'ARRAY', 'ArrayRef';
  is scalar @$events, 5, 'all five events';
  is $events->[0]{Action}, 'create', 'first event is the container create';
  is $events->[0]{Type}, 'container', 'and it is a container event';
};

subtest 'a failed build is HTTP 200 with errorDetail in the stream' => sub {
  # Measured: podman answered 200 for a Dockerfile whose RUN exits 7.
  #
  # Decoding stays decoding: _decode_stream turns the body into events and
  # judges none of them. Acting on the errorDetail is _request's job, and
  # t/stream_error.t covers that -- build, pull and push croak on it, so what
  # reaches a caller through those methods is never this ArrayRef.
  my $events = $client->_decode_stream(
    load_fixture_raw('images_build_error_stream.ndjson'));
  is ref $events, 'ARRAY', 'ArrayRef';
  my ($err) = grep { $_->{errorDetail} } @$events;
  ok $err, 'the errorDetail event survives decoding';
  like $err->{errorDetail}{message}, qr/exit status 7/, 'and carries the cause';
};

subtest '_request routes each body to the right decoder' => sub {
  my $t = Test::FakeTransport->new(
    host        => 'unix:///nonexistent.sock',
    api_version => '1.41',
  );

  $t->canned([ 200, 'OK', {}, load_fixture_raw('images_build_quiet_stream.ndjson') ]);
  my $events = $t->_request('POST', '/build', ndjson => 1);
  is ref $events, 'ARRAY', 'ndjson => 1 on a one-object body gives an ArrayRef';
  is scalar @$events, 1, 'holding the single event';

  $t->canned([ 200, 'OK', {}, load_fixture_raw('containers_logs_tty_json.bin') ]);
  is $t->_request('GET', '/containers/x/logs', raw => 1),
    qq[{"msg":"hi"}\r\n],
    'raw => 1 returns the bytes even when they parse as JSON';

  $t->canned([ 200, 'OK', {}, '{"ApiVersion":"1.41"}' ]);
  is_deeply $t->_request('GET', '/containers/x/json'), { ApiVersion => '1.41' },
    'an ordinary endpoint still decodes to a HashRef';

  $t->canned([ 204, 'No Content', {}, '' ]);
  is $t->_request('POST', '/containers/x/start'), undef, '204 is still undef';
};

subtest 'a stream with no newline framing is not dropped' => sub {
  my $events = $client->_decode_stream(qq[{\n  "stream": "hi"\n}\n]);
  is_deeply $events, [ { stream => 'hi' } ],
    'a pretty-printed single object falls back to a whole-body decode';

  is_deeply $client->_decode_stream('not json at all'), [],
    'an undecodable body is an empty ArrayRef, never a bare string';
};

SKIP: {
  skip 'mock routes are bypassed in live mode', 2 if is_live();

  subtest 'the streaming endpoints ask for stream decoding' => sub {
    my %saw;
    my $docker = test_docker(
      'POST /build'                  => sub { $saw{build} = { @_[2 .. $#_] }; [] },
      'POST /images/create'          => sub { $saw{pull}  = { @_[2 .. $#_] }; [] },
      'POST /images/nginx/push'      => sub { $saw{push}  = { @_[2 .. $#_] }; [] },
      'POST /images/nginx/tag'       => sub { $saw{tag}   = { @_[2 .. $#_] }; undef },
      'GET /images/nginx/json'       => sub { $saw{inspect} = { @_[2 .. $#_] }; {} },
      'GET /events'                  => sub { $saw{events} = { @_[2 .. $#_] }; [] },
      'GET /containers/deadbeef/stats' => sub { $saw{stats} = { @_[2 .. $#_] }; {} },
    );

    $docker->images->build(context => 'tar-bytes', t => 'x:1');
    $docker->images->pull(fromImage => 'nginx');
    $docker->images->push('nginx');
    $docker->images->tag('nginx', repo => 'other');
    $docker->images->inspect('nginx');
    $docker->system->events(since => 1, until => 2);
    $docker->containers->stats('deadbeef');

    ok $saw{build}{ndjson},  'build passes ndjson => 1';
    ok $saw{pull}{ndjson},   'pull passes ndjson => 1';
    ok $saw{push}{ndjson},   'push passes ndjson => 1';
    # /events was already newline-delimited and used to reach an ArrayRef
    # through _request's implicit fallback; that fallback is gone, so the
    # endpoint has to ask for stream decoding explicitly or it regresses
    # to a raw string.
    ok $saw{events}{ndjson}, 'events passes ndjson => 1';

    # The ordinary single-JSON-object endpoints must keep their HashRef
    # contract, so they must never take the stream path.
    ok !$saw{tag}{ndjson},     'tag does not';
    ok !$saw{inspect}{ndjson}, 'inspect does not';
    ok !$saw{stats}{ndjson},   'stats does not';
    # stats sends Docker's own stream=0 query parameter; that must not be
    # confused with the transport's ndjson option.
    is $saw{stats}{params}{stream}, 0, 'stats still sends stream=0 as a query param';
  };

  subtest 'the single-object endpoints still return a HashRef' => sub {
    # images_list (karr k101): a real Podman 5.8.4 (API 1.44) capture, see
    # t/images.t. container_inspect (karr k101 follow-up): a real Docker
    # 29.7.2 (API 1.55) capture, see t/containers.t. Neither fact matters
    # here: this subtest only checks the returned class, not fixture
    # content -- the route key 'deadbeef' need not match the fixture's own
    # (real) container id for that.
    my $docker = test_docker(
      'GET /images/nginx/json' => load_fixture('images_list')->[0],
      'GET /containers/deadbeef/json' => load_fixture('container_inspect'),
    );
    isa_ok $docker->images->inspect('nginx'),
      'API::Docker::Type::ImageInspect';
    isa_ok $docker->containers->inspect('deadbeef'),
      'API::Docker::Type::ContainerInspectResponse';
    is ref $docker->system->version, 'HASH', 'version is a HashRef';
  };
}

SKIP: {
  skip 'live write tests disabled (API_DOCKER_TEST_WRITE=1 to enable)', 1
    unless can_write();

  subtest 'live: pull returns an ArrayRef of events' => sub {
    my $docker = API::Docker->new(host => $ENV{API_DOCKER_TEST_HOST});
    my $events = $docker->images->pull(fromImage => 'alpine', tag => '3');
    is ref $events, 'ARRAY', 'ArrayRef off a real engine';
    ok scalar(@$events) >= 1, 'at least one event';
    ok !(grep { ref $_ ne 'HASH' } @$events), 'every element is an event HashRef';
  };
}

done_testing;
