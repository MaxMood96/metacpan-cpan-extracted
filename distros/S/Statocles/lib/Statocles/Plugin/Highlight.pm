package Statocles::Plugin::Highlight;
our $VERSION = '0.098';
# ABSTRACT: Highlight code and configuration syntax

#pod =head1 SYNOPSIS
#pod
#pod     # --- Configuration
#pod     # site.yml
#pod     ---
#pod     site:
#pod         class: Statocles::Site
#pod         args:
#pod             plugins:
#pod                 highlight:
#pod                     $class: Statocles::Plugin::Highlight
#pod                     $args:
#pod                         style: default
#pod
#pod     # --- Usage
#pod     <%= highlight perl => begin %>
#pod     print "Hello, World!\n";
#pod     <% end %>
#pod
#pod =head1 DESCRIPTION
#pod
#pod This plugin adds the C<highlight> helper function to all templates and
#pod content documents, allowing for syntax highlighting of source code and
#pod configuration blocks.
#pod
#pod =cut

use Statocles::Base 'Class';
with 'Statocles::Plugin';
BEGIN {
    eval { require Syntax::Highlight::Engine::Kate; 1 }
        or die "Error loading Statocles::Plugin::Highlight. To use this plugin, install Syntax::Highlight::Engine::Kate";
};

#pod =attr style
#pod
#pod The style to use, which corresponds to a stylesheet file in your theme's
#pod C</plugin/highlight> directory without the trailing C<.css>. Defaults to
#pod C<"default">, which refers to the C<default.css> file.
#pod
#pod The styles included by default are:
#pod
#pod =over 4
#pod
#pod =item *
#pod
#pod default
#pod
#pod =item *
#pod
#pod solarized-light
#pod
#pod =item *
#pod
#pod solarized-dark
#pod
#pod =back
#pod
#pod =cut

has style => (
    is => 'ro',
    isa => Str,
    default => "default",
);

#pod =method highlight
#pod
#pod     %= highlight $type => $content
#pod
#pod Highlight the given C<$content> using the given C<$type> syntax.
#pod
#pod The list of supported syntaxes are in the L<SUPPORTED SYNTAX|/SUPPORTED
#pod SYNTAX> section, below.
#pod
#pod To highlight a block of code, use C<begin>/C<end>:
#pod
#pod     %= highlight Perl => begin
#pod     use strict;
#pod     use warnings;
#pod     print "Hello, World!\n";
#pod     % end
#pod
#pod To highlight an included file, use the L<include helper|Statocles::Template/include>:
#pod
#pod     %= highlight Perl => include 'test.pl'
#pod
#pod The highlight function adds both C<pre> and C<code> tags.
#pod
#pod     <p>This example Perl code prints the string "Hello, World" to the screen:</p>
#pod     %= highlight Perl => 'print "Hello, World\n"'
#pod
#pod We can override the style we want by passing in a C<-style> option:
#pod
#pod     %= highlight -style => 'solarized-dark', Perl => begin
#pod     print "Hello, World!\n";
#pod     % end
#pod
#pod =cut

my $hl = Syntax::Highlight::Engine::Kate->new(
    substitutions => {
        "<"  => "&lt;",
        ">"  => "&gt;",
        "&"  => "&amp;",
    },
    format_table => {
        Alert        => [ '', '' ],
        BaseN        => [ '<span class="hljs-number">', '</span>' ],
        BString      => [ '', '' ],
        Char         => [ '<span class="hljs-string">', '</span>' ],
        Comment      => [ '<span class="hljs-comment">', '</span>' ],
        DataType     => [ '<span class="hljs-type">', '</span>' ],
        DecVal       => [ '<span class="hljs-number">', '</span>' ],
        Error        => [ '', '' ],
        Float        => [ '<span class="hljs-number">', '</span>' ],
        Function     => [ '<span class="hljs-function">', '</span>' ],
        IString      => [ '', '' ],
        Keyword      => [ '<span class="hljs-keyword">', '</span>' ],
        Normal       => [ '', '' ],
        Operator     => [ '', '' ],
        Others       => [ '', '' ],
        RegionMarker => [ '', '' ],
        Reserved     => [ '<span class="hljs-built-in">', '</span>' ],
        String       => [ '<span class="hljs-string">', '</span>' ],
        Variable     => [ '<span class="hljs-variable">', '</span>' ],
        Warning      => [ '', '' ],
    },
);

sub highlight {
    my ( $self, $args, @args ) = @_;

    # Last two args are always type and text and are required
    my ( $text, $type ) = ( pop @args, pop @args );

    # Other args are options
    my %opt = @args;

    my $style = $opt{ -style } || $self->style;

    # Handle Mojolicious begin/end
    if ( ref $text eq 'CODE' ) {
        $text = $text->();
        # begin/end starts with a newline, so remove it to prevent too
        # much top space
        $text =~ s/^\n//;
    }

    # XXX We need to normalize this so that the current page is always
    # `$args->{page}`
    my $page = $args->{page} || $args->{self};
    if ( $page ) {
        # Add the appropriate stylesheet to the page
        my $style_url = $page->site->theme->url( '/plugin/highlight/' . $style . '.css' );
        if ( !grep { $_->href eq $style_url } $page->links( 'stylesheet' ) ) {
            $page->links( stylesheet => $style_url );
        }
    }

    # Find the right language
    # We can't use languagePlug for this because it will always write
    # a warning to the screen.
    # See https://rt.cpan.org/Ticket/Display.html?id=110836
    my $found_lang;
    for my $lang ( $hl->languageList ) {
        if ( lc $lang eq lc $type ) {
            $found_lang = $lang;
            last;
        }
    }
    if ( !$found_lang ) {
        die sprintf qq{Could not find language "%s"\n}, $type;
    }

    $hl->language( $found_lang );

    # Wrap the output in <pre> and <code> to ensure the right background is set
    my $wrap_start = '<pre><code class="hljs">';
    my $wrap_end = '</code></pre>';
    my $output = $wrap_start . $hl->highlightText( $text ) . $wrap_end;

    return $output;
}

#pod =method register
#pod
#pod Register this plugin with the site. Called automatically.
#pod
#pod =cut

sub register {
    my ( $self, $site ) = @_;
    $site->theme->helper( highlight => sub { $self->highlight( @_ ) } );
}

1;

=pod

=encoding UTF-8

=head1 NAME

Statocles::Plugin::Highlight - Highlight code and configuration syntax

=head1 VERSION

version 0.098

=head1 SYNOPSIS

    # --- Configuration
    # site.yml
    ---
    site:
        class: Statocles::Site
        args:
            plugins:
                highlight:
                    $class: Statocles::Plugin::Highlight
                    $args:
                        style: default

    # --- Usage
    <%= highlight perl => begin %>
    print "Hello, World!\n";
    <% end %>

=head1 DESCRIPTION

This plugin adds the C<highlight> helper function to all templates and
content documents, allowing for syntax highlighting of source code and
configuration blocks.

=head1 ATTRIBUTES

=head2 style

The style to use, which corresponds to a stylesheet file in your theme's
C</plugin/highlight> directory without the trailing C<.css>. Defaults to
C<"default">, which refers to the C<default.css> file.

The styles included by default are:

=over 4

=item *

default

=item *

solarized-light

=item *

solarized-dark

=back

=head1 METHODS

=head2 highlight

    %= highlight $type => $content

Highlight the given C<$content> using the given C<$type> syntax.

The list of supported syntaxes are in the L<SUPPORTED SYNTAX|/SUPPORTED
SYNTAX> section, below.

To highlight a block of code, use C<begin>/C<end>:

    %= highlight Perl => begin
    use strict;
    use warnings;
    print "Hello, World!\n";
    % end

To highlight an included file, use the L<include helper|Statocles::Template/include>:

    %= highlight Perl => include 'test.pl'

The highlight function adds both C<pre> and C<code> tags.

    <p>This example Perl code prints the string "Hello, World" to the screen:</p>
    %= highlight Perl => 'print "Hello, World\n"'

We can override the style we want by passing in a C<-style> option:

    %= highlight -style => 'solarized-dark', Perl => begin
    print "Hello, World!\n";
    % end

=head2 register

Register this plugin with the site. Called automatically.

=head1 SUPPORTED SYNTAX

All of the syntax types supported by the L<Syntax::Highlight::Engine::Kate> Perl module
are supported by this module:

    .desktop                ferite                  PHP/PHP
    4GL                     Fortran                 PicAsm
    4GL-PER                 FreeBASIC               Pike
    ABC                     GDL                     PostScript
    Ada                     GLSL                    POV-Ray
    AHDL                    GNU Assembler           progress
    Alerts                  GNU Gettext             Prolog
    ANSI C89                Haskell                 PureBasic
    Ansys                   HTML                    Python
    Apache Configuration    IDL                     Quake Script
    Asm6502                 ILERPG                  R Script
    ASP                     Inform                  RenderMan RIB
    AVR Assembler           INI Files               REXX
    AWK                     Intel x86 (NASM)        RPM Spec
    BaseTest                Java                    RSI IDL
    BaseTestchild           Javadoc                 Ruby
    Bash                    JavaScript              Sather
    BibTeX                  JavaScript/PHP          Scheme
    C                       JSP                     scilab
    C#                      Kate File Template      SGML
    C++                     KBasic                  Sieve
    Cg                      LaTeX                   SML
    CGiS                    LDIF                    Spice
    ChangeLog               Lex/Flex                SQL
    Cisco                   LilyPond                SQL (MySQL)
    Clipper                 Literate Haskell        SQL (PostgreSQL)
    CMake                   Logtalk                 Stata
    ColdFusion              LPC                     TaskJuggler
    Common Lisp             Lua                     Tcl/Tk
    Component-Pascal        M3U                     TI Basic
    CSS                     MAB-DB                  txt2tags
    CSS/PHP                 Makefile                UnrealScript
    CUE Sheet               Mason                   Velocity
    D                       Matlab                  Verilog
    Debian Changelog        MIPS Assembler          VHDL
    Debian Control          Modula-2                VRML
    de_DE                   Music Publisher         Wikimedia
    Diff                    nl                      WINE Config
    Doxygen                 Objective Caml          x.org Configuration
    E Language              Objective-C             xHarbour
    Eiffel                  Octave                  XML
    Email                   Pascal                  xslt
    en_US                   Perl                    yacas
    Euphoria                PHP (HTML)              Yacc/Bison

=head1 ATTRIBUTION

The C<default>, C<solarized-light>, and C<solarized-dark> styles are taken from
the L<Highlight.js project|https://highlightjs.org>, and are licensed under the
BSD license.

=head1 SEE ALSO

=over 4

=item L<Syntax::Highlight::Engine::Kate>

The underlying syntax highlighter powering this plugin

=back

=head1 AUTHOR

Doug Bell <preaction@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Doug Bell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__END__

# Generate the list of languages supported with:
# perl -MSyntax::Highlight::Engine::Kate -E'say for Syntax::Highlight::Engine::Kate->new->languageList' | fmtcol -w72
# fmtcol comes from Term::FormatColumns


