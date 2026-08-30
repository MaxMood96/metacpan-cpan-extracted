#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::API::Docker::Mock;
use JSON::MaybeXS;
use API::Docker;

# Regression coverage for karr k7: containers->logs and exec->start used to
# hand the caller the raw Docker stream, so the 8-byte frame headers ended up
# inside the log text. Every fixture below is bytes captured from the rootless
# Podman socket (5.4.2, API 1.41) with a container running
# "echo OUT; echo ERR 1>&2".

check_live_access();

# The demultiplexer is a method on the transport role; the client needs no
# connection to exercise it, the socket attribute is lazy.
my $client = API::Docker->new(
  host        => 'unix:///var/run/docker.sock',
  api_version => '1.41',
);

my $MULTIPLEXED = load_fixture_raw('containers_logs_multiplexed.bin');
my $TTY         = load_fixture_raw('containers_logs_tty.bin');
my $TTY_JSON    = load_fixture_raw('containers_logs_tty_json.bin');
my $EXEC        = load_fixture_raw('exec_start_multiplexed.bin');

subtest 'the captured fixtures are the bytes the engine produced' => sub {
  is length $MULTIPLEXED, 24, 'multiplexed log fixture is 24 bytes';
  is unpack('H*', $MULTIPLEXED),
    '0100000000000004' . '4f55540a' . '0200000000000004' . '4552520a',
    'multiplexed log fixture: 01 header + "OUT\n", 02 header + "ERR\n"';
  is $TTY, "OUT\r\nERR\r\n", 'tty log fixture has no headers and CRLF endings';
  is $EXEC, $MULTIPLEXED, 'exec/start frames are byte-identical to logs frames';
};

subtest 'demultiplexing a framed stream' => sub {
  my $frames = $client->_demux_frames($MULTIPLEXED);
  is_deeply $frames, [
    { stream => 'stdout', data => "OUT\n" },
    { stream => 'stderr', data => "ERR\n" },
  ], 'two frames, stdout then stderr, headers stripped';

  is join('', map { $_->{data} } @$frames), "OUT\nERR\n",
    'joining the payloads gives the plain text';
};

subtest 'raw (TTY) output is not mistaken for frames' => sub {
  is $client->_demux_frames($TTY), undef,
    'text pty output does not walk as frames';
  is $client->_demux_frames($TTY_JSON), undef,
    'JSON pty output does not walk as frames';
};

subtest 'the framing walk rejects what it cannot consume exactly' => sub {
  is $client->_demux_frames(''), undef, 'empty body';
  is $client->_demux_frames("\x01\x00\x00\x00"), undef, 'short header';
  is $client->_demux_frames("\x01\x00\x00\x00\x00\x00\x00\x04OU"), undef,
    'truncated payload';
  is $client->_demux_frames("\x01\x00\x00\x00\x00\x00\x00\x04OUT\nX"), undef,
    'trailing byte after a complete frame';
  is $client->_demux_frames("\x03\x00\x00\x00\x00\x00\x00\x01A"), undef,
    'stream type above 2';
  is $client->_demux_frames("\x01\x00\x00\x01\x00\x00\x00\x01A"), undef,
    'non-zero padding byte';

  is_deeply $client->_demux_frames("\x00\x00\x00\x00\x00\x00\x00\x01A"),
    [ { stream => 'stdin', data => 'A' } ], 'stream type 0 is stdin';
};

SKIP: {
  skip 'mock routes are bypassed in live mode', 3 if is_live();

  subtest 'containers->logs demultiplexes' => sub {
    my $docker = test_docker(
      'GET /containers/deadbeef/logs' => sub { $MULTIPLEXED },
    );
    my $frames = $docker->containers->logs('deadbeef');
    is_deeply $frames, [
      { stream => 'stdout', data => "OUT\n" },
      { stream => 'stderr', data => "ERR\n" },
    ], 'frames, not header bytes';
  };

  subtest 'containers->logs on a TTY container' => sub {
    my $docker = test_docker(
      'GET /containers/deadbeef/logs' => sub { $TTY },
    );
    my $frames = $docker->containers->logs('deadbeef');
    is_deeply $frames, [ { stream => 'raw', data => "OUT\r\nERR\r\n" } ],
      'one raw frame; stream is a plain string, never undef';
    ok defined $frames->[0]{stream}, 'no caller needs a defined-check';

    my $json = test_docker(
      'GET /containers/deadbeef/logs' => sub { $TTY_JSON },
    );
    is_deeply $json->containers->logs('deadbeef'),
      [ { stream => 'raw', data => qq[{"msg":"hi"}\r\n] } ],
      'a container printing JSON is returned verbatim, not decoded';

    my $forced = test_docker(
      'GET /containers/deadbeef/logs' => sub { $MULTIPLEXED },
    );
    is_deeply $forced->containers->logs('deadbeef', tty => 1),
      [ { stream => 'raw', data => $MULTIPLEXED } ],
      'tty => 1 suppresses demultiplexing';
  };

  subtest 'exec->start demultiplexes' => sub {
    my $docker = test_docker(
      'POST /exec/abc123/start' => sub { $EXEC },
    );
    is_deeply $docker->exec->start('abc123', Detach => 0), [
      { stream => 'stdout', data => "OUT\n" },
      { stream => 'stderr', data => "ERR\n" },
    ], 'same frame shape as logs';

    my $empty = test_docker(
      'POST /exec/abc123/start' => sub { undef },
    );
    is_deeply $empty->exec->start('abc123', Detach => 1), [],
      'a detached start produces no frames';
  };
}

SKIP: {
  skip 'live write tests disabled (API_DOCKER_TEST_WRITE=1 to enable)', 1
    unless can_write();

  subtest 'live: frames off a real engine' => sub {
    my $docker = API::Docker->new(host => $ENV{API_DOCKER_TEST_HOST});
    my $name = 'apidocker-t-frames-' . $$;

    my $created = $docker->containers->create(
      Image => 'alpine:3',
      Cmd   => [ 'sh', '-c', 'echo OUT; echo ERR 1>&2' ],
      Tty   => JSON->false,
      name  => $name,
    );
    my $id = $created->{Id};
    register_cleanup(sub {
      eval { $docker->containers->remove($id, force => 1) };
    });

    $docker->containers->start($id);
    $docker->containers->wait($id);

    my $frames = $docker->containers->logs($id);
    is ref $frames, 'ARRAY', 'logs returns an ArrayRef';
    ok scalar(@$frames) >= 1, 'at least one frame';
    my %seen = map { $_->{stream} => 1 } @$frames;
    ok $seen{stdout}, 'stdout frame present';
    ok $seen{stderr}, 'stderr frame present';
    like join('', map { $_->{data} } @$frames), qr/OUT/,
      'payload carries the text';
    unlike join('', map { $_->{data} } @$frames), qr/\x00\x00\x00/,
      'no frame header bytes leaked into the payload';
  };
}

done_testing;
