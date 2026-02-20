package Langertha::Role::Models;
# ABSTRACT: Role for APIs with several models
our $VERSION = '0.100';
use Moose::Role;

requires qw(
  default_model
);

has models => (
  is => 'rw',
  isa => 'ArrayRef[Str]',
  lazy_build => 1,
);
sub _build_models {
  my ( $self ) = @_;
  # Prefer dynamic list_models() over static all_models()
  return $self->list_models() if $self->can('list_models');
  return [
    $self->can('all_models')
      ? $self->all_models
      : $self->model
  ];
}

has model => (
  is => 'ro',
  isa => 'Str',
  lazy_build => 1,
);
sub _build_model {
  my ( $self ) = @_;
  return $self->default_model;
}

# Cache configuration
has models_cache_ttl => (
  is => 'ro',
  isa => 'Int',
  default => sub { 3600 }, # 1 hour default
);

has _models_cache => (
  is => 'rw',
  isa => 'HashRef',
  default => sub { {} },
  traits => ['Hash'],
  handles => {
    _clear_models_cache => 'clear',
  },
);

# Public method to clear the cache
sub clear_models_cache {
  my ($self) = @_;
  $self->_clear_models_cache;
  return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Role::Models - Role for APIs with several models

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
