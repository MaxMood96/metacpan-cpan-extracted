package Langertha::Stream;
# ABSTRACT: Iterator for streaming responses
our $VERSION = '0.100';
use Moose;
use namespace::autoclean;
use Carp qw( croak );

has chunks => (
  is => 'ro',
  isa => 'ArrayRef[Langertha::Stream::Chunk]',
  required => 1,
);

has _position => (
  is => 'rw',
  isa => 'Int',
  default => 0,
);

sub next {
  my ($self) = @_;
  my $pos = $self->_position;
  return undef if $pos >= scalar @{$self->chunks};
  $self->_position($pos + 1);
  return $self->chunks->[$pos];
}

sub has_next {
  my ($self) = @_;
  return $self->_position < scalar @{$self->chunks};
}

sub collect {
  my ($self) = @_;
  my @remaining;
  while (my $chunk = $self->next) {
    push @remaining, $chunk;
  }
  return @remaining;
}

sub content {
  my ($self) = @_;
  return join('', map { $_->content } @{$self->chunks});
}

sub each {
  my ($self, $callback) = @_;
  croak "each() requires a callback" unless ref $callback eq 'CODE';
  while (my $chunk = $self->next) {
    $callback->($chunk);
  }
}

sub reset {
  my ($self) = @_;
  $self->_position(0);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Stream - Iterator for streaming responses

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
