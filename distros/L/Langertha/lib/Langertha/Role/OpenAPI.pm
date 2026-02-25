package Langertha::Role::OpenAPI;
# ABSTRACT: Role for APIs with OpenAPI definition
our $VERSION = '0.202';
use Moose::Role;

use Carp qw( croak );
use JSON::MaybeXS ();
use JSON::PP ();
use OpenAPI::Modern;
use Path::Tiny;
use URI;
use YAML::PP;

requires qw(
  openapi_file
  generate_http_request
  url
  json
);

has openapi => (
  is => 'ro',
  lazy_build => 1,
);
sub _build_openapi {
  my ( $self ) = @_;
  my ( $format, $file ) = $self->openapi_file;
  croak "".(ref $self)." can only do format yaml for the OpenAPI spec currently" unless $format eq 'yaml';
  my $yaml = $file;
  return OpenAPI::Modern->new(
    openapi_uri => $yaml,
    openapi_schema => YAML::PP->new(boolean => 'JSON::PP')->load_string(path($yaml)->slurp_utf8),
  );
}


has supported_operations => (
  is => 'ro',
  isa => 'ArrayRef[Str]',
  lazy_build => 1,
);
sub _build_supported_operations {
  my ( $self ) = @_;
  return [];
}


sub can_operation {
  my ( $self, $operationId ) = @_;
  return 1 unless scalar @{$self->supported_operations} > 0;
  my %so = map { $_, 1 } @{$self->supported_operations};
  return $so{$operationId};
}


sub get_operation {
  my ( $self, $operationId ) = @_;
  croak "".(ref $self)." runs in compatibility mode and is unable to perform this OpenAPI operation"
    unless ($self->can_operation($operationId));
  my $jpath = $self->openapi->openapi_document->get_operationId_path($operationId);
  my $operation = $self->openapi->openapi_document->get($jpath);
  my $content_type = ( $operation->{requestBody} && $operation->{requestBody}->{content} )
    ? $operation->{requestBody}->{content}->{'application/json'} ? 'application/json'
      : $operation->{requestBody}->{content}->{'multipart/form-data'} ? 'multipart/form-data'
        : undef
    : undef;
  my ( undef, $paths, $path, $method ) = split('/', $jpath);
  return unless $paths eq 'paths';
  $path =~ s/~1/\//g;
  my $url = $self->url || $self->openapi->openapi_document->get('/servers/0/url');
  return ( uc($method), $url.$path, $content_type );
}


sub generate_request {
  my ( $self, $operationId, $response_call, %args ) = @_;
  my ( $method, $url, $content_type ) = $self->get_operation($operationId);
  $args{content_type} = $content_type if defined $content_type;
  return $self->generate_http_request( $method, $url, $response_call, %args );
}



1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Role::OpenAPI - Role for APIs with OpenAPI definition

=head1 VERSION

version 0.202

=head2 openapi

The L<OpenAPI::Modern> instance loaded from the engine's C<openapi_file>. Built
lazily on first use. Only YAML format OpenAPI specs are currently supported.

=head2 supported_operations

ArrayRef of C<operationId> strings that this engine instance supports. When
non-empty, only listed operations are permitted; all others croak. Defaults to
an empty ArrayRef (all operations allowed). Used to restrict engines that run in
a limited compatibility mode.

=head2 can_operation

    if ($engine->can_operation('createChatCompletion')) { ... }

Returns true if the given C<$operationId> is supported by this engine. Always
returns true when C<supported_operations> is empty (unrestricted mode).

=head2 get_operation

    my ($method, $url, $content_type) = $engine->get_operation($operationId);

Looks up an operation by C<$operationId> in the OpenAPI spec and returns the
HTTP method, full URL, and content type as a three-element list. Croaks if the
operation is not in C<supported_operations>.

=head2 generate_request

    my $request = $engine->generate_request($operationId, $response_call, %args);

Generates an HTTP request for the named OpenAPI C<$operationId>. Resolves the
method, URL, and content type from the spec, then delegates to
L<Langertha::Role::HTTP/generate_http_request>.

=head1 SEE ALSO

=over

=item * L<Langertha::Role::HTTP> - HTTP request building (required by this role)

=item * L<Langertha::Role::Models> - Model management (typically composed alongside this role)

=item * L<OpenAPI::Modern> - OpenAPI spec handling

=back

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/langertha/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de> L<https://raudss.us/>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
