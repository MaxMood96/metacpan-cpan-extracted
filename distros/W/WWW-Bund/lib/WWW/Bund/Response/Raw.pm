package WWW::Bund::Response::Raw;
our $VERSION = '0.001';
# ABSTRACT: Raw response — returns content as-is

use Moo;
use namespace::clean;


sub data { $_[0]->content }


with 'WWW::Bund::Role::Response';

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::Response::Raw - Raw response — returns content as-is

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use WWW::Bund::Response::Raw;

    my $response = WWW::Bund::Response::Raw->new(
        content      => 'plain text response',
        content_type => 'text/plain',
    );

    my $data = $response->data;  # 'plain text response'

=head1 DESCRIPTION

Pass-through response parser for non-JSON, non-XML responses. Returns content
as-is without parsing.

Used as fallback when content type is not recognized.

=head2 data

Returns C<content> unchanged.

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
