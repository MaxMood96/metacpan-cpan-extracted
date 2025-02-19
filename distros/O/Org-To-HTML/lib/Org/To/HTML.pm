package Org::To::HTML;

use 5.010001;
use strict;
use vars qw($VERSION);
use warnings;
use Log::ger;

use Exporter 'import';
use File::Slurper qw(read_text write_text);
use HTML::Entities qw/encode_entities/;
use Org::Document;

use Moo;
with 'Org::To::Role';
extends 'Org::To::Base';

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-11-06'; # DATE
our $DIST = 'Org-To-HTML'; # DIST
our $VERSION = '0.236'; # VERSION

our @EXPORT_OK = qw(org_to_html);

has naked => (is => 'rw');
has html_title => (is => 'rw');
has css_url => (is => 'rw');
has inline_images => (is =>  'rw');

our %SPEC;
$SPEC{org_to_html} = {
    v => 1.1,
    summary => 'Export Org document to HTML',
    description => <<'_',

This is the non-OO interface. For more customization, consider subclassing
Org::To::HTML.

_
    args => {
        source_file => {
            summary => 'Source Org file to export',
            schema => ['str' => {}],
        },
        source_str => {
            summary => 'Alternatively you can specify Org string directly',
            schema => ['str' => {}],
        },
        target_file => {
            summary => 'HTML file to write to',
            schema => ['str' => {}],
            description => <<'_',

If not specified, HTML string will be returned.

_
        },
        include_tags => {
            summary => 'Include trees that carry one of these tags',
            schema => ['array' => {of => 'str*'}],
            description => <<'_',

Works like Org's 'org-export-select-tags' variable. If the whole document
doesn't have any of these tags, then the whole document will be exported.
Otherwise, trees that do not carry one of these tags will be excluded. If a
selected tree is a subtree, the heading hierarchy above it will also be selected
for export, but not the text below those headings.

_
        },
        exclude_tags => {
            summary => 'Exclude trees that carry one of these tags',
            schema => ['array' => {of => 'str*'}],
            description => <<'_',

If the whole document doesn't have any of these tags, then the whole document
will be exported. Otherwise, trees that do not carry one of these tags will be
excluded. If a selected tree is a subtree, the heading hierarchy above it will
also be selected for export, but not the text below those headings.

exclude_tags is evaluated after include_tags.

_
        },
        html_title => {
            summary => 'HTML document title, defaults to source_file',
            schema => ['str' => {}],
        },
        css_url => {
            summary => 'Add a link to CSS document',
            schema => ['str' => {}],
        },
        naked => {
            summary => 'Don\'t wrap exported HTML with HTML/HEAD/BODY elements',
            schema => ['bool' => {}],
        },
        ignore_unknown_settings => {
            schema => 'bool',
        },
        inline_images => {
            summary => 'If set to true, will make link to an image filename into an <img> element instead of <a>',
            schema => 'bool',
            default => 1,
        },
    },
};
sub org_to_html {
    my %args = @_;

    my $doc;
    if ($args{source_file}) {
        $doc = Org::Document->new(
            from_string => scalar read_text($args{source_file}),
            ignore_unknown_settings => $args{ignore_unknown_settings},
        );
    } elsif (defined($args{source_str})) {
        $doc = Org::Document->new(
            from_string => $args{source_str},
            ignore_unknown_settings => $args{ignore_unknown_settings},
        );
    } else {
        return [400, "Please specify source_file/source_str"];
    }

    my $obj = ($args{_class} // __PACKAGE__)->new(
        source_file   => $args{source_file} // '(source string)',
        include_tags  => $args{include_tags},
        exclude_tags  => $args{exclude_tags},
        css_url       => $args{css_url},
        naked         => $args{naked},
        html_title    => $args{html_title},
        inline_images => $args{inline_images} // 1,
    );

    my $html = $obj->export($doc);
    #$log->tracef("html = %s", $html);
    if ($args{target_file}) {
        write_text($args{target_file}, $html);
        return [200, "OK"];
    } else {
        return [200, "OK", $html];
    }
}

sub export_document {
    my ($self, $doc) = @_;

    $self->{_prev_elem_is_inline} = 0;

    my $html = [];
    unless ($self->naked) {
        push @$html, "<html>\n";
        push @$html, (
            "<!-- Generated by ".__PACKAGE__,
            " version ".($VERSION // "?"),
            " on ".scalar(localtime)." -->\n\n");

        push @$html, "<head>\n";

        {
            my @title_settings = $doc->settings('TITLE');
            my $title_from_setting;
            $title_from_setting = $title_settings[0]->raw_arg
                if @title_settings;
            push @$html, "<title>",
                ($self->html_title // $title_from_setting // $self->source_file // '(no title)'),
                "</title>\n";
        }

        if ($self->css_url) {
            push @$html, (
                "<link rel=\"stylesheet\" type=\"text/css\" href=\"",
                $self->css_url, "\" />\n"
            );
        }
        push @$html, "</head>\n\n";

        push @$html, "<body>\n";
    }
    push @$html, $self->export_elements(@{$doc->children});
    unless ($self->naked) {
        push @$html, "</body>\n\n";
        push @$html, "</html>\n";
    }

    join "", @$html;
}

sub before_export_element {
    my $self = shift;
    my %args = @_;

    $self->{_prev_elem_is_inline} =
        $args{elem}->can("is_inline") && $args{elem}->is_inline ? 1:0;
}

sub export_block {
    my ($self, $elem) = @_;
    # currently all assumed to be <PRE>
    join "", (
        "<pre class=\"block block_", lc($elem->name), "\">",
        encode_entities($elem->raw_content),
        "</pre>\n\n"
    );
}

sub export_fixed_width_section {
    my ($self, $elem) = @_;
    join "", (
        "<pre class=\"fixed_width_section\">",
        encode_entities($elem->text),
        "</pre>\n"
    );
}

sub export_comment {
    my ($self, $elem) = @_;
    join "", (
        "<!-- ",
        encode_entities($elem->_str),
        " -->\n"
    );
}

sub export_drawer {
    my ($self, $elem) = @_;
    # currently not exported
    '';
}

sub export_footnote {
    my ($self, $elem) = @_;
    # currently not exported
    '';
}

sub export_headline {
    my ($self, $elem) = @_;

    my @children = $self->_included_children($elem);

    join "", (
        "<h" , $elem->level, ">",
        $self->export_elements($elem->title),
        "</h", $elem->level, ">\n\n",
        $self->export_elements(@children)
    );
}

sub export_list {
    my ($self, $elem) = @_;
    my $tag;
    my $type = $elem->type;
    if    ($type eq 'D') { $tag = 'dl' }
    elsif ($type eq 'O') { $tag = 'ol' }
    elsif ($type eq 'U') { $tag = 'ul' }
    join "", (
        "<$tag>\n",
        $self->export_elements(@{$elem->children // []}),
        "</$tag>\n\n"
    );
}

sub export_list_item {
    my ($self, $elem) = @_;

    my $html = [];
    if ($elem->desc_term) {
        push @$html, "<dt>";
    } else {
        push @$html, "<li>";
    }

    if ($elem->check_state) {
        push @$html, "<strong>[", $elem->check_state, "]</strong>";
    }

    if ($elem->desc_term) {
        push @$html, $self->export_elements($elem->desc_term);
        push @$html, "</dt>";
        push @$html, "<dd>";
    }

    push @$html, $self->export_elements(@{$elem->children}) if $elem->children;

    if ($elem->desc_term) {
        push @$html, "</dd>\n";
    } else {
        push @$html, "</li>\n";
    }

    join "", @$html;
}

sub export_radio_target {
    my ($self, $elem) = @_;
    # currently not exported
    '';
}

sub export_setting {
    my ($self, $elem) = @_;
    # currently not exported
    '';
}

sub export_table {
    my ($self, $elem) = @_;
    join "", (
        "<table border>\n",
        $self->export_elements(@{$elem->children // []}),
        "</table>\n\n"
    );
}

sub export_table_row {
    my ($self, $elem) = @_;
    join "", (
        "<tr>",
        $self->export_elements(@{$elem->children // []}),
        "</tr>\n"
    );
}

sub export_table_cell {
    my ($self, $elem) = @_;

    join "", (
        "<td>",
            $self->export_elements(@{$elem->children // []}),
        "</td>"
    );
}

sub export_table_vline {
    my ($self, $elem) = @_;
    # currently not exported
    '';
}

sub __escape_target {
    my $target = shift;
    $target =~ s/[^\w]+/_/g;
    $target;
}

sub export_target {
    my ($self, $elem) = @_;
    # target
    join "", (
        "<a name=\"", __escape_target($elem->target), "\">"
    );
}

sub export_text {
    my ($self, $elem) = @_;

    my $style = $elem->style;
    my $tag;
    if    ($style eq 'B') { $tag = 'b' }
    elsif ($style eq 'I') { $tag = 'i' }
    elsif ($style eq 'U') { $tag = 'u' }
    elsif ($style eq 'S') { $tag = 'strike' }
    elsif ($style eq 'C') { $tag = 'code' }
    elsif ($style eq 'V') { $tag = 'tt' }

    my $html = [];

    push @$html, "<$tag>" if $tag;
    my $text = encode_entities($elem->text);
    $text =~ s/\R\R+/\n\n<p>/g;
    if ($self->{_prev_elem_is_inline}) {
        $text =~ s/\A\R/ /;
    }
    $text =~ s/(?<=.)\R/ /g;
    push @$html, $text;
    push @$html, $self->export_elements(@{$elem->children}) if $elem->children;
    push @$html, "</$tag>" if $tag;

    join "", @$html;
}

sub export_time_range {
    my ($self, $elem) = @_;

    encode_entities($elem->as_string);
}

sub export_timestamp {
    my ($self, $elem) = @_;

    encode_entities($elem->as_string);
}

sub export_link {
    require Filename::Image;
    require URI;

    my ($self, $elem) = @_;

    my $html = [];
    my $link = $elem->link;
    my $looks_like_image = Filename::Image::check_image_filename(filename => $link);
    my $inline_images = $self->inline_images;

    if ($inline_images && $looks_like_image) {
        # TODO: extract to method e.g. settings
        my $elem_settings;
        my $s = $elem;
        while (1) {
            $s = $s->prev_sibling;
            last unless $s && $s->isa("Org::Element::Setting");
            $elem_settings->{ $s->name } = $s->raw_arg;
        }
        #use DD; dd $settings;
        my $caption = $elem_settings->{CAPTION};

        # TODO: extract to method e.g. settings of Org::Document
        my $doc_settings;
        $s = $elem->document->children->[0];
        while (1) {
            $s = $s->next_sibling;
            last unless $s && $s->isa("Org::Element::Setting");
            $doc_settings->{ $s->name } = $s->raw_arg;
        }
        #use DD; dd $settings;
        my $img_base = $doc_settings->{IMAGE_BASE};

        my $url = defined($img_base) ? URI->new($link)->abs(URI->new($img_base)) : $link;

        push @$html, "<figure>" if defined $caption;
        push @$html, "<img src=\"";
        push @$html, "$url";
        push @$html, "\" />";
        push @$html, "<figcaption>", encode_entities($caption), "</figcaption>";
        push @$html, "</figure>" if defined $caption;
    } else {
        push @$html, "<a href=\"";
        push @$html, $link;
        push @$html, "\">";
        if ($elem->description) {
            push @$html, $self->export_elements($elem->description);
        } else {
            push @$html, $link;
        }
        push @$html, "</a>";
    }

    join "", @$html;
}

1;
# ABSTRACT: Export Org document to HTML

__END__

=pod

=encoding UTF-8

=head1 NAME

Org::To::HTML - Export Org document to HTML

=head1 VERSION

This document describes version 0.236 of Org::To::HTML (from Perl distribution Org-To-HTML), released on 2023-11-06.

=head1 SYNOPSIS

 use Org::To::HTML qw(org_to_html);

 # non-OO interface
 my $res = org_to_html(
     source_file   => 'todo.org', # or source_str
     #target_file  => 'todo.html', # defaults return the HTML in $res->[2]
     #html_title   => 'My Todo List', # defaults to file name
     #include_tags => [...], # default exports all tags.
     #exclude_tags => [...], # behavior mimics emacs's include/exclude rule
     #css_url      => '/path/to/my/style.css', # default none
     #naked        => 0, # if set to 1, no HTML/HEAD/BODY will be output.
 );
 die "Failed" unless $res->[0] == 200;

 # OO interface
 my $oeh = Org::To::HTML->new();
 my $html = $oeh->export($doc); # $doc is Org::Document object

=head1 DESCRIPTION

Export Org format to HTML. To customize, you can subclass this module.

A command-line utility L<org-to-html> is available in the distribution
L<App::OrgUtils>.

Note that this module is just a simple exporter, for "serious" work you'll
probably want to use the exporting features or L<org-mode|http://orgmode.org>.

=for Pod::Coverage ^(export_.+|before_.+|after_.+)$

=head1 ATTRIBUTES

=head2 naked => BOOL

If set to true, export_document() will not output HTML/HEAD/BODY wrapping
element. Default is false.

=head2 html_title => STR

Title to use in TITLE HTML element, to override C<#+TITLE> setting in the Org
document. If unset and document does not have C<#+TITLE> setting, will default
to the name of the source file, or C<(source string)>.

=head2 css_url => STR

If set, export_document() will output a LINK element pointing to this CSS.

=head2 inline_images => BOOL

=head1 METHODS

=head2 new(%args)

=head2 $exp->export_document($doc) => HTML

Export document to HTML.

=head2 org_to_html

=head1 FAQ

=head2 Why would one want to use this instead of org-mode's built-in exporting features?

This module might come in handy if you want to customize the Org-to-HTML
translation with Perl, for example when you want to customize the default HTML
title when there's no C<#+TITLE> setting, change translation of table element to
an ASCII table, etc.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Org-To-HTML>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Org-To-HTML>.

=head1 SEE ALSO

For more information about Org document format, visit http://orgmode.org/

L<Org::Parser>

L<org-to-html>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTORS

=for stopwords Harald Jörg Steven Haryanto

=over 4

=item *

Harald Jörg <Harald.Joerg@arcor.de>

=item *

Steven Haryanto <stevenharyanto@gmail.com>

=back

=head1 CONTRIBUTING


To contribute, you can send patches by email/via RT, or send pull requests on
GitHub.

Most of the time, you don't need to build the distribution yourself. You can
simply modify the code, then test via:

 % prove -l

If you want to build the distribution (e.g. to try to install it locally on your
system), you can install L<Dist::Zilla>,
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>,
L<Pod::Weaver::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla- and/or Pod::Weaver plugins. Any additional steps required beyond
that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2023, 2022, 2020, 2018, 2017, 2016, 2015, 2014, 2013, 2012, 2011 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Org-To-HTML>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
