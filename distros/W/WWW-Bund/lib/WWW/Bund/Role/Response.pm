package WWW::Bund::Role::Response;
our $VERSION = '0.002';
# ABSTRACT: Role for typed API response objects

use Moo::Role;


has content => (is => 'ro', default => '');


has content_type => (is => 'ro', default => '');


requires 'data';


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::Role::Response - Role for typed API response objects

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    package WWW::Bund::Response::MyFormat;
    use Moo;
    with 'WWW::Bund::Role::Response';

    has data => (is => 'lazy');

    sub _build_data {
        my ($self) = @_;
        # Parse $self->content
        return $parsed_data;
    }

=head1 DESCRIPTION

Role for response parser classes. Consumes raw HTTP response content and
provides parsed C<data>.

Implementations:

=over

=item * L<WWW::Bund::Response::JSON> - Parses JSON to Perl data structures

=item * L<WWW::Bund::Response::XML> - Parses XML to HashRef via XML::Twig

=item * L<WWW::Bund::Response::Raw> - Returns content as-is

=back

=head2 content

Raw response content (character string). Defaults to empty string.

=head2 content_type

Content-Type header value. Defaults to empty string.

=head1 REQUIRED ATTRIBUTES

=head2 data

Parsed response data. Must be implemented by consuming classes.

Typically lazy-built from C<content>.

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
