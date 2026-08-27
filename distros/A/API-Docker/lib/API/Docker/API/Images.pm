package API::Docker::API::Images;
# ABSTRACT: Docker Engine Images API
our $VERSION = '0.003';
use Moo;
use API::Docker::Image;
use Carp qw( croak );
use JSON::MaybeXS qw( encode_json );
use MIME::Base64 qw( encode_base64 );
use namespace::clean;


has client => (
  is       => 'ro',
  required => 1,
  weak_ref => 1,
);


sub _wrap {
  my ($self, $data) = @_;
  return API::Docker::Image->new(
    client => $self->client,
    %$data,
  );
}

sub _wrap_list {
  my ($self, $list) = @_;
  return [ map { $self->_wrap($_) } @$list ];
}

sub list {
  my ($self, %opts) = @_;
  my %params;
  $params{all}     = $opts{all} ? 1 : 0     if defined $opts{all};
  $params{digests} = $opts{digests} ? 1 : 0 if defined $opts{digests};
  $params{filters} = $opts{filters}          if defined $opts{filters};
  my $result = $self->client->get('/images/json', params => \%params);
  return $self->_wrap_list($result // []);
}


sub build {
  my ($self, %opts) = @_;
  my $context = delete $opts{context};
  croak "Build context required (tar archive as scalar ref or raw bytes)" unless defined $context;

  my %params;
  $params{dockerfile} = $opts{dockerfile} if defined $opts{dockerfile};
  $params{t}          = $opts{t}          if defined $opts{t};
  $params{q}          = $opts{q} ? 1 : 0  if defined $opts{q};
  $params{nocache}    = $opts{nocache} ? 1 : 0 if defined $opts{nocache};
  $params{pull}       = $opts{pull}       if defined $opts{pull};
  $params{rm}         = defined $opts{rm} ? ($opts{rm} ? 1 : 0) : 1;
  $params{forcerm}    = $opts{forcerm} ? 1 : 0 if defined $opts{forcerm};
  $params{memory}     = $opts{memory}     if defined $opts{memory};
  $params{memswap}    = $opts{memswap}    if defined $opts{memswap};
  $params{cpushares}  = $opts{cpushares}  if defined $opts{cpushares};
  $params{cpusetcpus} = $opts{cpusetcpus} if defined $opts{cpusetcpus};
  $params{cpuperiod}  = $opts{cpuperiod}  if defined $opts{cpuperiod};
  $params{cpuquota}   = $opts{cpuquota}   if defined $opts{cpuquota};
  $params{shmsize}    = $opts{shmsize}    if defined $opts{shmsize};
  $params{networkmode} = $opts{networkmode} if defined $opts{networkmode};
  $params{platform}   = $opts{platform}   if defined $opts{platform};
  $params{target}     = $opts{target}     if defined $opts{target};

  $params{buildargs} = encode_json($opts{buildargs}) if $opts{buildargs};
  $params{labels}    = encode_json($opts{labels})    if $opts{labels};

  my $raw = ref $context eq 'SCALAR' ? $$context : $context;

  return $self->client->_request('POST', '/build',
    raw_body     => $raw,
    content_type => 'application/x-tar',
    params       => \%params,
    ndjson       => 1,
  );
}


sub pull {
  my ($self, %opts) = @_;
  croak "fromImage required" unless $opts{fromImage};
  my %params;
  $params{fromImage} = $opts{fromImage};
  $params{tag}       = $opts{tag} // 'latest';
  return $self->client->post('/images/create', undef,
    params => \%params,
    ndjson => 1,
  );
}


sub inspect {
  my ($self, $name) = @_;
  croak "Image name required" unless $name;
  my $result = $self->client->get("/images/$name/json");
  return $self->_wrap($result);
}


sub history {
  my ($self, $name) = @_;
  croak "Image name required" unless $name;
  return $self->client->get("/images/$name/history");
}


sub push {
  my ($self, $name, %opts) = @_;
  croak "Image name required" unless $name;
  my %params;
  $params{tag} = $opts{tag} if defined $opts{tag};

  my $auth_header = _build_registry_auth_header($opts{auth});

  return $self->client->post(
    "/images/$name/push",
    undef,
    params  => \%params,
    headers => { 'X-Registry-Auth' => $auth_header },
    ndjson  => 1,
  );
}

sub _build_registry_auth_header {
  my ($auth) = @_;

  # The Docker Engine requires an X-Registry-Auth header on every push,
  # even for anonymous attempts. Encoding is base64url of a JSON object.
  my $payload;
  if (!defined $auth) {
    $payload = '{}';
  }
  elsif (ref $auth eq 'HASH') {
    $payload = encode_json($auth);
  }
  else {
    # Already pre-built JSON or pre-encoded string. If it looks base64-like
    # (no braces), pass through; otherwise encode as-is.
    return $auth if $auth =~ /^[A-Za-z0-9+\/=_\-]+$/;
    $payload = $auth;
  }

  # Padded base64url, and the padding is not optional: the engine decodes
  # this header with Go's base64.URLEncoding, which requires it. Stripping
  # the '=' made every push fail with a 400 -- 'failed to parse
  # "X-Registry-Auth" header: unexpected EOF' -- including anonymous ones,
  # where the payload is the three-character '{}' encoding that needs a pad.
  my $b64 = encode_base64($payload, '');
  $b64 =~ tr{+/}{-_};
  return $b64;
}


sub tag {
  my ($self, $name, %opts) = @_;
  croak "Image name required" unless $name;
  my %params;
  $params{repo} = $opts{repo} if defined $opts{repo};
  $params{tag}  = $opts{tag}  if defined $opts{tag};
  return $self->client->post("/images/$name/tag", undef, params => \%params);
}


sub remove {
  my ($self, $name, %opts) = @_;
  croak "Image name required" unless $name;
  my %params;
  $params{force}   = $opts{force} ? 1 : 0   if defined $opts{force};
  $params{noprune} = $opts{noprune} ? 1 : 0 if defined $opts{noprune};
  return $self->client->delete_request("/images/$name", params => \%params);
}


sub search {
  my ($self, $term, %opts) = @_;
  croak "Search term required" unless $term;
  my %params;
  $params{term}    = $term;
  $params{limit}   = $opts{limit}   if defined $opts{limit};
  $params{filters} = $opts{filters} if defined $opts{filters};
  return $self->client->get('/images/search', params => \%params);
}


sub prune {
  my ($self, %opts) = @_;
  my %params;
  $params{filters} = $opts{filters} if defined $opts{filters};
  return $self->client->post('/images/prune', undef, params => \%params);
}



1;

__END__

=pod

=encoding UTF-8

=head1 NAME

API::Docker::API::Images - Docker Engine Images API

=head1 VERSION

version 0.003

=head1 SYNOPSIS

    my $docker = API::Docker->new;

    # Build an image from a tar context
    use Path::Tiny;
    my $tar = path('context.tar')->slurp_raw;
    $docker->images->build(context => $tar, t => 'myapp:latest');

    # Pull an image
    $docker->images->pull(fromImage => 'nginx', tag => 'latest');

    # List images
    my $images = $docker->images->list;
    for my $image (@$images) {
        say $image->Id;
        say join ', ', @{$image->RepoTags};
    }

    # Inspect image details
    my $image = $docker->images->inspect('nginx:latest');

    # Tag and push
    $docker->images->tag('nginx:latest', repo => 'myrepo/nginx', tag => 'v1');
    $docker->images->push('myrepo/nginx', tag => 'v1');

    # Remove image
    $docker->images->remove('nginx:latest', force => 1);

=head1 DESCRIPTION

This module provides methods for managing Docker images including pulling,
listing, tagging, pushing to registries, and removal.

All C<list> and C<inspect> methods return L<API::Docker::Image> objects.

Accessed via C<< $docker->images >>.

=head2 client

Reference to L<API::Docker> client. Weak reference to avoid circular dependencies.

=head2 list

    my $images = $images->list(all => 1);

List images. Returns ArrayRef of L<API::Docker::Image> objects.

Options:

=over

=item * C<all> - Show all images (default hides intermediate images)

=item * C<digests> - Include digest information

=item * C<filters> - Hashref of filters

=back

=head2 build

    # Build from a tar archive
    my $tar_data = path('context.tar')->slurp_raw;
    my $events = $docker->images->build(
        context    => $tar_data,
        t          => 'myimage:latest',
        dockerfile => 'Dockerfile',
    );

    # Build with build args
    my $events = $docker->images->build(
        context   => $tar_data,
        t         => 'myapp:v1',
        buildargs => { APP_VERSION => '1.0' },
        nocache   => 1,
    );

Build an image from a tar archive containing a Dockerfile and build context.

The C<context> parameter is required and must contain the raw bytes of a tar
archive (or a scalar reference to one).

Returns an ArrayRef of build events, one per object in the engine's
newline-delimited JSON stream, even when the stream carried a single object
(C<< q => 1 >> produces exactly one). A successful build returns; a failed one
croaks.

    my $events = $images->build(context => $tar, t => 'myapp:latest');
    my ($aux) = grep { $_->{aux} } @$events;
    my $image_id = $aux->{aux}{ID};

The engine answers a failed build with HTTP 200 and reports the failure as an
C<errorDetail> object inside the stream, so nothing about the response status
says the build broke. This method used to return that stream like any other
and leave the scan to the caller, which meant a caller who did not know to
scan reported a broken build as a success. It now croaks with an
L<API::Docker::Error::Stream> instead:

    my $events = eval { $images->build(context => $tar, t => 'myapp:latest') };
    if (my $err = $@) {
        warn "$err";               # the reason, with Carp's location suffix
        for my $event (@{ $err->events }) {   # the build output up to the failure
            print $event->{stream} if defined $event->{stream};
        }
    }

The exception stringifies to what a plain C<croak> would have produced, so
existing C<eval>-and-inspect-C<$@> code needs no change.

Options:

=over

=item * C<context> - Tar archive bytes (required)

=item * C<dockerfile> - Path to Dockerfile within the archive (default: C<Dockerfile>)

=item * C<t> - Tag for the image (e.g. C<name:tag>)

=item * C<q> - Suppress verbose build output

=item * C<nocache> - Do not use cache when building

=item * C<pull> - Always pull base image

=item * C<rm> - Remove intermediate containers (default: true)

=item * C<forcerm> - Always remove intermediate containers

=item * C<buildargs> - HashRef of build-time variables

=item * C<labels> - HashRef of labels to set on the image

=item * C<memory> - Memory limit in bytes

=item * C<memswap> - Total memory (memory + swap), -1 to disable swap

=item * C<cpushares> - CPU shares (relative weight)

=item * C<cpusetcpus> - CPUs to use (e.g. C<0-3>, C<0,1>)

=item * C<cpuperiod> - CPU CFS period (microseconds)

=item * C<cpuquota> - CPU CFS quota (microseconds)

=item * C<shmsize> - Size of /dev/shm in bytes

=item * C<networkmode> - Network mode during build

=item * C<platform> - Platform (e.g. C<linux/amd64>)

=item * C<target> - Multi-stage build target

=back

=head2 pull

    my $events = $images->pull(fromImage => 'nginx', tag => 'latest');

Pull an image from a registry. C<tag> defaults to C<latest>.

Returns an ArrayRef of progress events, one per object in the engine's
newline-delimited JSON stream, even when the stream carried a single object.

A failed pull croaks either way, but which way depends on the engine, so do
not write code that expects one of them:

=over

=item * Docker reports it in the stream. The response is HTTP 200 and the
failure is an C<errorDetail> object among the progress events; this method
croaks with an L<API::Docker::Error::Stream>, whose C<< ->events >> holds the
progress that preceded the failure.

=item * Podman reports it in the status line. Measured against the rootless
socket (5.4.2, API 1.41): pulling a repository that does not exist answers
C<403 Forbidden> with C<< {"message":"denied: requested access to the resource
is denied"} >>, and an existing repository with a missing tag answers
C<404 Not Found> with C<< {"message":"manifest unknown: manifest unknown"} >>.
Neither reaches the stream at all -- the transport's own status handling
croaks with a plain string first.

=back

Catching L<API::Docker::Error::Stream> specifically is therefore not a
reliable way to catch a failed pull. C<eval> and inspect C<$@> as a string,
which both cases satisfy.

Options:

=over

=item * C<fromImage> - Image name to pull (required)

=item * C<tag> - Tag to pull (default C<latest>)

=back

=head2 inspect

    my $image = $images->inspect('nginx:latest');

Get detailed information about an image. Returns L<API::Docker::Image> object.

=head2 history

    my $history = $images->history('nginx:latest');

Get image history (layers). Returns ArrayRef of layer information.

=head2 push

    my $events = $images->push('myrepo/nginx', tag => 'v1');
    $images->push('myrepo/nginx', auth => {
        username      => 'me',
        password      => 'secret',
        serveraddress => 'https://index.docker.io/v1/',
    });

Push an image to a registry. Optionally specify C<tag>.

Returns an ArrayRef of progress events, one per object in the engine's
newline-delimited JSON stream, even when the stream carried a single object.

A failed push croaks, by one of two routes depending on the engine -- an
unauthorised push to a private registry is the common case, and it is exactly
the one that must not be reported as a success.

Docker reports it inside a 200 stream as an C<errorDetail> object, which
croaks with an L<API::Docker::Error::Stream> carrying the progress events.
Podman puts an C<errorDetail> body behind a real error status instead:
measured against the rootless socket (5.4.2, API 1.41), a push to an
unreachable registry answers C<500 Internal Server Error> with
C<< {"errorDetail":{"message":"... connection refused"},"error":"..."} >>, so
the transport's status handling croaks with a plain string before the stream
is ever decoded. That body carries no C<message> key, so the whole JSON
object ends up as the croak text.

Either way the failure is loud. Inspect C<$@> as a string rather than testing
for the exception class, which only the first route produces.

The Docker Engine requires an C<X-Registry-Auth> header on every push,
even for anonymous attempts; the header is always sent. Pass C<auth> as
a hashref of credentials (typical keys: C<username>, C<password>,
C<serveraddress>, or C<identitytoken>), or as a pre-encoded base64 string.
Without C<auth> the header carries an empty JSON object.

=head2 tag

    $images->tag('nginx:latest', repo => 'myrepo/nginx', tag => 'v1');

Tag an image with a new repository and/or tag name.

=head2 remove

    $images->remove('nginx:latest', force => 1);

Remove an image.

Options:

=over

=item * C<force> - Force removal

=item * C<noprune> - Do not delete untagged parents

=back

=head2 search

    my $results = $images->search('nginx', limit => 25);

Search Docker Hub for images. Returns ArrayRef of search results.

Options: C<limit>, C<filters>.

=head2 prune

    my $result = $images->prune(filters => { dangling => ['true'] });

Delete unused images. Returns hashref with C<ImagesDeleted> and C<SpaceReclaimed>.

=head1 SEE ALSO

=over

=item * L<API::Docker> - Main Docker client

=item * L<API::Docker::Image> - Image entity class

=item * L<API::Docker::Error::Stream> - Raised by C<build>, C<pull> and C<push>

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
