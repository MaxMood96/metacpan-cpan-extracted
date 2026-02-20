package Langertha::Role::JSON;
# ABSTRACT: Role for JSON
our $VERSION = '0.100';
use Moose::Role;
use JSON::MaybeXS;

sub json { shift->_json }
has _json => (
  is => 'ro',
  lazy_build => 1,
);
sub _build__json { JSON::MaybeXS->new( utf8 => 1, canonical => 1 ) }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Role::JSON - Role for JSON

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
