#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::API::Docker::Mock;
use API::Docker;

# karr k25 -- images->build_prune, POST /build/prune. Clears the BuildKit
# build cache, which is a different store from the dangling images
# images->prune deletes.
#
# The parameter that needs watching is keep-storage: the engine spells it
# with a hyphen, and the transport's _uri_encode must leave that alone rather
# than percent-encoding it into keep%2Dstorage. An unquoted
# `keep-storage => $n` is not even valid Perl -- the fat comma only quotes a
# bareword identifier -- so keep_storage is the documented spelling and the
# wire name is accepted beside it.
#
# Measured against the rootless Podman socket (5.4.2, API 1.41): Podman does
# not implement the endpoint at all. POST /build/prune answers 404 Not Found
# with a text/plain body of "Not Found" -- not the JSON {"message":...} shape
# its other errors use -- at /build/prune, /v1.41/build/prune,
# /v1.47/build/prune and /v4.0.0/libpod/build/prune alike.

check_live_access();

# See t/images_tar.t for why this exists.
package Test::BuildPrune::FakeTransport;
use Moo;
extends 'API::Docker';

has canned => (is => 'rw', default => sub {
  [200, 'OK', {}, '{"CachesDeleted":["abc"],"SpaceReclaimed":1024}'] });
has _sink => (is => 'rw');

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
  return Test::BuildPrune::FakeTransport->new(
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
subtest 'build_prune is a different endpoint from prune' => sub {
  plan skip_all => 'route assertions are fixture-only' if is_live();

  my @paths;
  my $docker = test_docker(
    'POST /build/prune'  => sub { push @paths, $_[1]; { CachesDeleted => ['abc'], SpaceReclaimed => 1024 } },
    'POST /images/prune' => sub { push @paths, $_[1]; { ImagesDeleted  => [],      SpaceReclaimed => 7 } },
  );

  my $cache = $docker->images->build_prune;
  my $dangling = $docker->images->prune;

  is_deeply \@paths, [ '/build/prune', '/images/prune' ],
    'build_prune hits /build/prune and prune still hits /images/prune';
  is $cache->{SpaceReclaimed}, 1024, 'the build cache result comes back raw';
  is_deeply $cache->{CachesDeleted}, ['abc'], 'including CachesDeleted';
  is $dangling->{SpaceReclaimed}, 7, 'and prune is untouched by any of it';
};

# ---------------------------------------------------------------------------
subtest 'keep-storage keeps its hyphen on the wire' => sub {
  my $t = fake_client();

  $t->images->build_prune(keep_storage => 5368709120);
  is request_line($t), 'POST /v1.41/build/prune?keep-storage=5368709120',
    'keep_storage is sent under the hyphenated name the engine expects';
  unlike request_line($t), qr/keep%2Dstorage/i,
    'the query encoder did not percent-encode the hyphen';
  unlike request_line($t), qr/keep_storage/,
    'and the underscore spelling never reaches the daemon';

  $t->images->build_prune('keep-storage' => 42);
  is request_line($t), 'POST /v1.41/build/prune?keep-storage=42',
    'the wire name is accepted as the option name too';
};

subtest 'all and filters' => sub {
  my $t = fake_client();

  $t->images->build_prune(all => 1);
  is request_line($t), 'POST /v1.41/build/prune?all=1',
    'a true all is sent as 1';

  $t->images->build_prune(all => 0);
  is request_line($t), 'POST /v1.41/build/prune?all=0',
    'a false all is sent as 0 rather than dropped';

  $t->images->build_prune;
  is request_line($t), 'POST /v1.41/build/prune',
    'and an unset all leaves the query string empty';

  # A HashRef params value is JSON-encoded by the transport, so the filter
  # must be handed over unencoded -- encoding it here would double-encode it.
  # The colon comes back raw because _uri_encode deliberately spares `:` and
  # `/` so an image reference survives in a path, and the JSON separator is
  # caught by the same exemption. RFC 3986 allows a bare `:` in a query, and
  # both spellings return the same list -- measured on Podman 5.4.2 against
  # GET /images/json?filters={"dangling":["true"]}.
  $t->images->build_prune(filters => { until => ['24h'] });
  is request_line($t),
    'POST /v1.41/build/prune?filters=%7B%22until%22:%5B%2224h%22%5D%7D',
    'filters is JSON-encoded exactly once, values as an ArrayRef of strings';
};

subtest 'every option together, in the transport\'s sort order' => sub {
  my $t = fake_client();
  $t->images->build_prune(all => 1, keep_storage => 1024, filters => { until => ['24h'] });

  is request_line($t),
    'POST /v1.41/build/prune?all=1&filters=%7B%22until%22:%5B%2224h%22%5D%7D'
    . '&keep-storage=1024',
    'all three parameters present, sorted by key';
};

# ---------------------------------------------------------------------------
subtest 'the Podman 404 croaks with the plain-text body' => sub {
  # Podman 5.4.2 does not implement /build/prune and answers text/plain,
  # so there is no {"message":...} for the transport to unwrap. A caller that
  # must work on both engines reads this as "no build cache here".
  my $t = fake_client();
  $t->canned([404, 'Not Found',
    { 'content-type' => 'text/plain; charset=utf-8' }, "Not Found\n"]);

  my $err = do { local $@; eval { $t->images->build_prune(all => 1) }; $@ };
  like $err, qr/Docker API error \(404\)/, 'it croaks rather than returning undef';
  like $err, qr/Not Found/, 'with the plain body, since it is not JSON to unwrap';
};

done_testing;
