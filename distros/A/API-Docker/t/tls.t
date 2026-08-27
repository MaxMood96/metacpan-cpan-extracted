#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use API::Docker;

# Regression coverage for karr #6: tls and cert_path were attributes nothing
# read. API::Docker::Role::HTTP builds a plain IO::Socket::INET and speaks
# HTTP over it, so a tcp:// daemon was addressed in cleartext whatever tls
# said -- a caller who asked for TLS got an unencrypted connection and no
# indication of it. tls => 1 now croaks; TLS is still not implemented.
#
# Nothing here connects: every construction below either dies during BUILD or
# never issues a request.

subtest 'tls => 1 croaks at construction' => sub {
  my $docker = eval { API::Docker->new(host => 'tcp://remote:2376', tls => 1) };

  ok !$docker, 'no object is handed back';
  ok $@, 'it croaked';
  like $@, qr/not implemented/,
    'the message says so, rather than reporting some downstream symptom';
  like $@, qr/plaintext/,
    'and says what actually happens on the wire';
  like $@, qr/stunnel|socat|ssh/,
    'and what to do instead -- terminate TLS in front of the daemon';
  like $@, qr/ at \S+ line \d+/,
    'croaked, so the caller\'s own line is named';
};

subtest 'it fails before anything can be sent' => sub {
  # The point of croaking at construction rather than at connect time: the
  # caller cannot get as far as handing over credentials.
  my $reached_socket = 0;
  {
    no warnings 'redefine', 'once';
    local *API::Docker::Role::HTTP::_build__socket = sub { $reached_socket++; die 'connected' };
    eval { API::Docker->new(host => 'tcp://remote:2376', tls => 1) };
  }
  ok $@, 'still croaked';
  is $reached_socket, 0, 'the socket builder was never reached';
};

subtest 'every falsy form of tls is accepted' => sub {
  # tls => 0 is the documented default and must keep working, including the
  # explicit form somebody may have written to be clear about it.
  for my $off (0, undef, '') {
    my $docker = eval {
      API::Docker->new(host => 'tcp://remote:2375', api_version => '1.41', tls => $off)
    };
    is $@, '', 'tls => ' . (defined $off ? "'$off'" : 'undef') . ' constructs';
    ok $docker, 'and returns a client';
  }

  my $default = API::Docker->new(host => 'tcp://remote:2375', api_version => '1.41');
  is $default->tls, 0, 'the default is still 0, and the attribute still reads';
};

subtest 'cert_path alone stays inert' => sub {
  # Deliberately not the same treatment. It defaults from DOCKER_CERT_PATH,
  # which is exported on plenty of machines that run the docker CLI, so
  # croaking on it would fail constructions over a value the caller never
  # passed -- and on its own it transmits nothing and claims nothing.
  my $docker = eval {
    API::Docker->new(
      host        => 'tcp://remote:2375',
      api_version => '1.41',
      cert_path   => '/etc/docker/certs',
    );
  };
  is $@, '', 'no croak';
  is $docker->cert_path, '/etc/docker/certs', 'the value is kept, just unused';

  {
    local $ENV{DOCKER_CERT_PATH} = '/from/env';
    my $from_env = eval { API::Docker->new(api_version => '1.41') };
    is $@, '', 'and a machine with DOCKER_CERT_PATH set still constructs';
    is $from_env->cert_path, '/from/env', 'defaulted from the environment';
  }

  # The combination is what croaks, and it croaks for the tls half.
  eval {
    API::Docker->new(host => 'tcp://remote:2376', tls => 1, cert_path => '/certs');
  };
  like $@, qr/not implemented/, 'cert_path does not rescue tls => 1';
};

subtest 'nothing in the transport reads either attribute' => sub {
  # If this ever fails, TLS has been implemented and this whole file is the
  # wrong test.
  my $source = do {
    local $/;
    open my $fh, '<', $INC{'API/Docker/Role/HTTP.pm'} or die $!;
    <$fh>;
  };
  ok length($source) > 1000, 'the transport source was actually read';
  unlike $source, qr/\$self->(?:tls|cert_path)\b/,
    'API::Docker::Role::HTTP still never consults tls or cert_path -- the '
    . 'plaintext connection it builds is unconditional';
  like $source, qr/IO::Socket::INET->new/,
    'and the tcp:// branch is still a plain socket';
};

done_testing;
