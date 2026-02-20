package WWW::Bund::Response::JSON;
our $VERSION = '0.002';
# ABSTRACT: JSON response — parses content to Perl data structure

use Moo;
use JSON::MaybeXS qw(decode_json);
use namespace::clean;


has data => (is => 'lazy');


sub _build_data {
    my ($self) = @_;
    return undef unless defined $self->content && length $self->content;
    return decode_json($self->content);
}

with 'WWW::Bund::Role::Response';

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::Response::JSON - JSON response — parses content to Perl data structure

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use WWW::Bund::Response::JSON;

    my $response = WWW::Bund::Response::JSON->new(
        content      => '{"result": "ok"}',
        content_type => 'application/json',
    );

    my $data = $response->data;  # { result => 'ok' }

=head1 DESCRIPTION

Parses JSON response content into Perl data structures (HashRef or ArrayRef).

Uses L<JSON::MaybeXS> for parsing, which selects the fastest available JSON
module (Cpanel::JSON::XS, JSON::XS, or JSON::PP).

Returns C<undef> if content is empty.

=head2 data

Parsed JSON data (HashRef, ArrayRef, or undef). Lazy-built from C<content>.

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
