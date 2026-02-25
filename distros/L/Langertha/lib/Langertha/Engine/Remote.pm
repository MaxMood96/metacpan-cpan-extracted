package Langertha::Engine::Remote;
# ABSTRACT: Base class for all remote engines
our $VERSION = '0.202';
use Moose;

with 'Langertha::Role::'.$_ for (qw(
  JSON
  HTTP
));

has '+url' => (
  required => 1,
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Engine::Remote - Base class for all remote engines

=head1 VERSION

version 0.202

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
