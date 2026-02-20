package Langertha::Stream::Chunk;
# ABSTRACT: Represents a single chunk from a streaming response
our $VERSION = '0.100';
use Moose;
use namespace::autoclean;

has content => (
  is => 'ro',
  isa => 'Str',
  required => 1,
);

has raw => (
  is => 'ro',
  isa => 'HashRef',
  predicate => 'has_raw',
);

has is_final => (
  is => 'ro',
  isa => 'Bool',
  default => 0,
);

has model => (
  is => 'ro',
  isa => 'Str',
  predicate => 'has_model',
);

has finish_reason => (
  is => 'ro',
  isa => 'Maybe[Str]',
  predicate => 'has_finish_reason',
);

has usage => (
  is => 'ro',
  isa => 'Maybe[HashRef]',
  predicate => 'has_usage',
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Stream::Chunk - Represents a single chunk from a streaming response

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
