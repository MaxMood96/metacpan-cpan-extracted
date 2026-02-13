package WWW::Bund::HTTPResponse;
our $VERSION = '0.001';
# ABSTRACT: Transport-independent HTTP response object

use Moo;
use namespace::clean;


has status => (is => 'ro', required => 1);


has content => (is => 'ro', default => '');


has content_type => (is => 'ro', default => '');


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::HTTPResponse - Transport-independent HTTP response object

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use WWW::Bund::HTTPResponse;

    my $response = WWW::Bund::HTTPResponse->new(
        status       => 200,
        content      => $decoded_body,
        content_type => 'application/json',
    );

=head1 DESCRIPTION

Simple immutable HTTP response object returned by L<WWW::Bund::Role::IO>
implementations. Contains decoded content (not raw bytes).

=head2 status

HTTP status code (200, 404, etc.). Required.

=head2 content

Response body as Perl character string (already decoded). Defaults to empty string.

=head2 content_type

Content-Type header value. Defaults to empty string.

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
