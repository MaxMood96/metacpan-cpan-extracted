package WWW::Bund::HTTPRequest;
our $VERSION = '0.001';
# ABSTRACT: Transport-independent HTTP request object

use Moo;
use namespace::clean;


has method => (is => 'ro', required => 1);


has url => (is => 'ro', required => 1);


has headers => (is => 'ro', default => sub { {} });


has content => (is => 'ro', predicate => 1);


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::HTTPRequest - Transport-independent HTTP request object

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use WWW::Bund::HTTPRequest;

    my $req = WWW::Bund::HTTPRequest->new(
        method  => 'GET',
        url     => 'https://example.com/api',
        headers => { Authorization => 'Bearer TOKEN' },
        content => $json_body,  # optional
    );

=head1 DESCRIPTION

Simple immutable HTTP request object used as input to L<WWW::Bund::Role::IO>
implementations. Transport-independent representation of an HTTP request.

=head2 method

HTTP method (GET, POST, etc.). Required.

=head2 url

Full URL including scheme, host, path, and query string. Required.

=head2 headers

HashRef of HTTP headers. Defaults to empty HashRef.

=head2 content

Request body content (for POST, PUT, etc.). Optional.

Use C<has_content> predicate to check if content is set.

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-www-bund/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
