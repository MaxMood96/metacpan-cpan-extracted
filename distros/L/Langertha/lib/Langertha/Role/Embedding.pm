package Langertha::Role::Embedding;
# ABSTRACT: Role for APIs with embedding functionality
our $VERSION = '0.100';
use Moose::Role;
use Carp qw( croak );

requires qw(
  embedding_request
  embedding_response
);

has embedding_model => (
  is => 'ro',
  isa => 'Str',
  lazy_build => 1,
);
sub _build_embedding_model {
  my ( $self ) = @_;
  croak "".(ref $self)." can't handle models!" unless $self->does('Langertha::Role::Models');
  return $self->default_embedding_model if $self->can('default_embedding_model');
  return $self->model;
}

sub embedding {
  my ( $self, $text ) = @_;
  return $self->embedding_request($text);
}

sub simple_embedding {
  my ( $self, $text ) = @_;
  my $request = $self->embedding($text);
  my $response = $self->user_agent->request($request);
  return $request->response_call->($response);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Role::Embedding - Role for APIs with embedding functionality

=head1 VERSION

version 0.100

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
