package XML::RSS::Private::Output::V1_0;
$XML::RSS::Private::Output::V1_0::VERSION = '1.65';
use strict;
use warnings;

use vars (qw(@ISA));

use XML::RSS::Private::Output::Base                ();
use XML::RSS::Private::Output::Roles::ModulesElems ();

@ISA = (qw(XML::RSS::Private::Output::Roles::ModulesElems XML::RSS::Private::Output::Base));

sub _get_top_elem_about {
    my ($self, $tag, $about_sub) = @_;
    return ' rdf:about="' . $self->_encode($about_sub->()) . '"';
}

sub _out_textinput_rss_1_0_elems {
    my $self = shift;

    $self->_out_dc_elements($self->textinput());

    # Ad-hoc modules
    # TODO : Should this follow the %rdf_resources conventions of the items'
    # and channel's modules' support ?
    while (my ($url, $prefix) = each %{$self->_modules()}) {
        next if $prefix =~ /^(dc|syn|taxo)$/;
        while (my ($el, $value) = each %{$self->textinput($prefix) || {}}) {
            $self->_out_ns_tag($prefix, $el, $value);
        }
    }
}

sub _get_rdf_decl_open_tag {
    return "<rdf:RDF\n";
}

sub _calc_prefer_dc {
    return 1;
}

sub _get_first_rdf_decl_mappings {
    return (["rdf", "http://www.w3.org/1999/02/22-rdf-syntax-ns#"],
        [undef, "http://purl.org/rss/1.0/"]);
}

sub _out_image_dc_elements {
    my $self = shift;
    return $self->_out_dc_elements($self->image());
}

sub _out_item_1_0_tags {
    my ($self, $item) = @_;

    $self->_out_dc_elements($item);

    # Taxonomy module
    $self->_output_taxo_topics($item);
}

sub _output_rss_middle {
    my $self = shift;

    # PICS rating - Dublin Core has not decided how to incorporate PICS ratings yet
    #$$output .= '<rss091:rating>'.$self->{channel}->{rating}.'</rss091:rating>'."\n"
    #$if $self->{channel}->{rating};

    $self->_out_copyright();

    # publication date
    $self->_out_defined_tag("dc:date", $self->_calc_dc_date());

    # external CDF URL
    #$output .= '<rss091:docs>'.$self->{channel}->{docs}.'</rss091:docs>'."\n"
    #if $self->{channel}->{docs};

    $self->_out_editors;

    $self->_out_all_modules_elems;

    $self->_out_seq_items();

    if ($self->_is_image_defined()) {
        $self->_out('<image rdf:resource="' . $self->_encode($self->image('url')) . "\" />\n");
    }

    if (defined(my $textinput_link = $self->textinput('link'))) {
        $self->_out('<textinput rdf:resource="' . $self->_encode($textinput_link) . "\" />\n");
    }

    $self->_end_channel;

    $self->_output_main_elements;
}

sub _get_end_tag {
    return "rdf:RDF";
}

1;

__END__

=pod

=encoding UTF-8

=head1 VERSION

version 1.65

=for :stopwords cpan testmatrix url bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<https://metacpan.org/release/XML-RSS>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<https://rt.cpan.org/Public/Dist/Display.html?Name=XML-RSS>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.cpanauthors.org/dist/XML-RSS>

=item *

CPAN Testers

The CPAN Testers is a network of smoke testers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/X/XML-RSS>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=XML-RSS>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=XML::RSS>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-xml-rss at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/Public/Bug/Report.html?Queue=XML-RSS>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/shlomif/perl-XML-RSS>

  git clone git://github.com/shlomif/perl-XML-RSS.git

=head1 AUTHOR

Shlomi Fish <shlomif@cpan.org>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/shlomif/perl-XML-RSS/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2001 by Various.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
