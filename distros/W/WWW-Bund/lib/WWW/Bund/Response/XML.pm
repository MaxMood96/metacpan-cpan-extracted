package WWW::Bund::Response::XML;
our $VERSION = '0.001';
# ABSTRACT: XML response — parses content to Perl data structure via XML::Twig

use Moo;
use XML::Twig;
use Encode qw(encode_utf8);
use namespace::clean;


has data => (is => 'lazy');


sub _build_data {
    my ($self) = @_;
    return undef unless defined $self->content && length $self->content;
    my $twig = XML::Twig->new();
    # XML::Parser expects bytes, not Perl character strings
    my $bytes = utf8::is_utf8($self->content)
        ? encode_utf8($self->content)
        : $self->content;
    $twig->parse($bytes);
    return _element_to_hash($twig->root);
}

sub _element_to_hash {
    my ($el) = @_;
    my %hash;

    # Attributes
    my %atts = %{$el->atts || {}};
    for my $k (keys %atts) {
        $hash{$k} = $atts{$k};
    }

    # Collect element children (skip text/CDATA nodes)
    my @element_children;
    for my $child ($el->children) {
        my $tag = $child->tag;
        next if $tag eq '#PCDATA' || $tag eq '#CDATA';
        push @element_children, $child;
    }

    if (!@element_children) {
        # Leaf element: only text/CDATA content
        my $text = $el->text_only // '';
        if (%hash) {
            # Has attributes — merge text as _text
            $hash{'_text'} = $text if length $text;
            return \%hash;
        }
        return $text;
    }

    # Track child tag names to detect repeated elements
    my %child_count;
    for my $child (@element_children) {
        $child_count{$child->tag}++;
    }

    for my $child (@element_children) {
        my $tag = $child->tag;
        my $value = _element_to_hash($child);

        if ($child_count{$tag} > 1) {
            # Repeated tag → array
            $hash{$tag} //= [];
            push @{$hash{$tag}}, $value;
        } else {
            $hash{$tag} = $value;
        }
    }

    return \%hash;
}

with 'WWW::Bund::Role::Response';

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::Response::XML - XML response — parses content to Perl data structure via XML::Twig

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use WWW::Bund::Response::XML;

    my $response = WWW::Bund::Response::XML->new(
        content      => '<root><item>value</item></root>',
        content_type => 'application/xml',
    );

    my $data = $response->data;  # { item => 'value' }

=head1 DESCRIPTION

Parses XML response content into Perl HashRef using L<XML::Twig>.

XML elements are converted to HashRef with the following rules:

=over

=item * Element attributes become hash keys

=item * Repeated child elements become ArrayRef

=item * Unique child elements become hash keys

=item * Leaf elements with only text become scalar values

=item * Leaf elements with both attributes and text store text as C<_text>

=back

Handles UTF-8 encoding correctly: if content is a Perl character string, it
is encoded to bytes before parsing (XML::Parser requires bytes).

Used by Bundestag and Bundesrat APIs which return XML instead of JSON.

=head2 data

Parsed XML as HashRef. Lazy-built from C<content>.

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
