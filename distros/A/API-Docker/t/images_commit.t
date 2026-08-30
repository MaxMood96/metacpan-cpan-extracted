#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::API::Docker::Mock;
use JSON::MaybeXS qw( decode_json );
use API::Docker;

# karr k22 -- images->commit, POST /commit. Turns a container into an image:
# the one image-producing path that does not go through a build context.
#
# Everything asserted about the engine here was measured against the rootless
# Podman socket (5.4.2, API 1.41): 201 Created with {"Id":"<64 hex>"} and no
# sha256: prefix, `changes` accepted both newline-joined and as repeated
# query pairs with the same result, and a ContainerConfig body whose Labels
# and Cmd replace the container's while Env is merged onto the inherited one.

check_live_access();

# ---------------------------------------------------------------------------
# See t/images_tar.t for why this exists: the mock harness replaces _request
# wholesale, so the request line and body it assembles are only reachable
# through a client whose socket is an in-memory sink.
package Test::ImagesCommit::FakeTransport;
use Moo;
extends 'API::Docker';

has canned => (is => 'rw', default => sub { [201, 'Created', {}, '{"Id":"deadbeef"}'] });
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

sub fake_client {
  return Test::ImagesCommit::FakeTransport->new(
    host        => 'unix:///nonexistent.sock',
    api_version => '1.41',
  );
}

sub request_line {
  my ($t) = @_;
  my ($line) = $t->written =~ /\A(\S+ [^\r\n]+) HTTP\/1\.1\r\n/;
  return $line;
}

# ---------------------------------------------------------------------------
subtest 'commit: returns the daemon response and requires a container' => sub {
  plan skip_all => 'route assertions are fixture-only' if is_live();

  my %seen;
  my $docker = test_docker(
    'POST /commit' => sub {
      my ($method, $path, %opts) = @_;
      %seen = %opts;
      return { Id => 'ae3996fdfd897ec18aa3eaa07e095418dda8f19902e43a2761373399f13132b3' };
    },
  );

  my $result = $docker->images->commit(
    container => 'c0ffee',
    repo      => 'myapp',
    tag       => 'snapshot',
    comment   => 'after the migration ran',
    author    => 'Jane <jane@example.com>',
  );

  is ref $result, 'HASH', 'the raw daemon response, not an entity object';
  like $result->{Id}, qr/^[0-9a-f]{64}$/,
    'Podman answers a bare hex digest with no sha256: prefix';

  is_deeply $seen{params}, {
    container => 'c0ffee',
    repo      => 'myapp',
    tag       => 'snapshot',
    comment   => 'after the migration ran',
    author    => 'Jane <jane@example.com>',
  }, 'every option went to the query string';
  ok !exists $seen{body}, 'and no body was sent without a config';

  my $err = do { local $@; eval { $docker->images->commit(repo => 'myapp') }; $@ };
  like $err, qr/container required/, 'a missing container croaks';
};

# ---------------------------------------------------------------------------
subtest 'commit: the options ride in the query string' => sub {
  my $t = fake_client();
  $t->images->commit(container => 'c0ffee', repo => 'myapp', tag => 'v2');

  is request_line($t),
    'POST /v1.41/commit?container=c0ffee&repo=myapp&tag=v2',
    'container, repo and tag on the wire, sorted by the transport';
};

subtest 'commit: pause is normalised to 1/0, not passed through' => sub {
  my $t = fake_client();

  $t->images->commit(container => 'c0ffee', pause => 'yes please');
  like request_line($t), qr/[?&]pause=1(&|$)/,
    'a true pause is sent as 1 -- the query string takes strings, not JSON';

  $t->images->commit(container => 'c0ffee', pause => 0);
  like request_line($t), qr/[?&]pause=0(&|$)/,
    'a false pause is sent as 0 rather than dropped';

  $t->images->commit(container => 'c0ffee');
  unlike request_line($t), qr/pause/,
    'an unset pause is left out so the engine default applies';
};

subtest 'commit: changes takes a string or an ArrayRef' => sub {
  # Measured: `changes` is a repeated query parameter on the wire, but the
  # engine parses each value as a Dockerfile snippet and a snippet may span
  # lines. changes=LABEL%20a%3Db%0AEXPOSE%208080 and two separate changes=
  # pairs produced the same image on Podman 5.4.2, so the joined form -- the
  # one the transport's params encoder can express -- is what is sent.
  my $t = fake_client();

  $t->images->commit(
    container => 'c0ffee',
    changes   => [ 'EXPOSE 8080', 'LABEL stage=release' ],
  );
  like request_line($t), qr/[?&]changes=EXPOSE%208080%0ALABEL%20stage%3Drelease(&|$)/,
    'an ArrayRef is joined with a newline into one changes= pair';

  $t->images->commit(container => 'c0ffee', changes => "EXPOSE 8080");
  like request_line($t), qr/[?&]changes=EXPOSE%208080(&|$)/,
    'a plain string is sent as it stands';
};

subtest 'commit: config becomes the JSON request body' => sub {
  my $t = fake_client();
  $t->images->commit(
    container => 'c0ffee',
    repo      => 'myapp',
    config    => { Cmd => [ '/bin/sh' ], Labels => { built => 'here' } },
  );

  my $req = $t->written;
  like $req, qr{Content-Type: application/json\r\n}, 'sent as JSON';

  my ($body) = $req =~ /\r\n\r\n(.*)\z/s;
  is_deeply decode_json($body),
    { Cmd => [ '/bin/sh' ], Labels => { built => 'here' } },
    'the ContainerConfig arrives unchanged';

  unlike request_line($t), qr/config/,
    'and it does not leak into the query string as well';
};

# ---------------------------------------------------------------------------
subtest 'live: commit a real container into a real image' => sub {
  plan skip_all => 'live only'          unless is_live();
  plan skip_all => 'write tests off'    unless can_write();

  my $docker = test_docker();
  my ($base) = grep { $_->repo_tags && @{ $_->repo_tags } } @{ $docker->images->list };
  plan skip_all => 'no tagged image to base a container on' unless $base;

  my $created = $docker->containers->create(
    Image => $base->repo_tags->[0],
    Cmd   => [ '/bin/sh', '-c', 'true' ],
  );
  my $id = $created->{Id};
  register_cleanup(sub { eval { $docker->containers->remove($id, force => 1) } });

  my $result = $docker->images->commit(
    container => $id,
    repo      => 'apidocker-test-commit',
    tag       => 'live',
    comment   => 'API::Docker live test',
  );
  register_cleanup(sub {
    eval { $docker->images->remove('apidocker-test-commit:live', force => 1) };
  });

  ok $result->{Id}, 'the daemon answered with an image id';
  my $image = $docker->images->inspect('apidocker-test-commit:live');
  isa_ok $image, 'API::Docker::Type::ImageInspect';
};

done_testing;
