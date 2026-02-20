package Langertha::Request::HTTP;
# ABSTRACT: A HTTP Request inside of Langertha
our $VERSION = '0.100';
use Moose;
use MooseX::NonMoose;

extends 'HTTP::Request';

has request_source => (
  is => 'ro',
  does => 'Langertha::Role::HTTP',
);

has response_call => (
  is => 'ro',
  isa => 'CodeRef',
);

sub FOREIGNBUILDARGS {
  my ( $class, %args ) = @_;
  return @{$args{http}};
}

sub BUILDARGS {
  my ( $class, %args ) = @_;
  delete $args{http};
  return { %args };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Request::HTTP - A HTTP Request inside of Langertha

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
