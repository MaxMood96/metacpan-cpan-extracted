use Test2::V0;
use feature qw(signatures);
use Pod::DokuWiki;

{
    my ($input, $expected) = split /^-{40,}\n+/m, do { local $/; readline DATA }, 2;

    my $parser = Pod::DokuWiki->new;
    $parser->output_string(\my $got);
    $parser->parse_string_document($input);

    is $got, $expected;
}

{
    my $parser = Pod::DokuWiki->new(
        resolve_pod_link => sub ($module, $section) {
            !defined $module ? "pod:#$section" :
            !defined $section ? "pod://$module" :
            "pod://$module#$section"
        },
        resolve_man_link => sub ($n, $page, $section) {
            !defined $section ? "man://$page:$n" :
            "man://$page:$n#$section"
        },
    );

    $parser->output_string(\my $got);
    $parser->parse_string_document(<<~'_POD_');
        =pod

        A L<Foo::Bar> L<Foo::Bar/baz> L</intern> L<quux(5)> L<quux(7)/SYNOPSIS>.
        _POD_

    is $got, <<~'_DokuWiki_';
        %%A %%[[pod://Foo::Bar|Foo::Bar]]%% %%[[pod://Foo::Bar#baz|"baz" in Foo::Bar]]%% %%[[pod:#intern|"intern"]]%% %%[[man://quux:5|quux(5)]]%% %%[[man://quux:7#SYNOPSIS|"SYNOPSIS" in quux(7)]]%%.%%
        _DokuWiki_
}

done_testing;

__DATA__
Other stuff.

=head1 DokuWiki Test

=head2 Text Formatting

Rendered: B<bold>, I<italic>, U<underlined>, C<monospace>,
B<U<I<C<combined>>>>.

Unrendered: **bold**, //italic//, __underlined__, ''monospace'',
**__//''combined''//__**.

Funky: %%%%% <nowiki> </nowiki>.

=head2 Links

URLs: L<DokuWiki|https://www.dokuwiki.org/DokuWiki> (hyperlinked text),
L<https://www.dokuwiki.org/faq> (bare link), https://example.com (not a link).

Man page: L<man(1)>.

POD links: L<perlapi> (perl), L<perlapi/Debugging> (perl+section),
L<Scalar::Util> (module), L<Scalar::Util/OTHER FUNCTIONS> (module+section).

Internal: L</Links>.

=head2 Headings

=head3 Level 3 Heading

=head4 Level 4 Heading

=head5 Level 5 Heading

=head6 Level 6 Heading

=head2 Code Blocks

    code
    unspecified language
    %%C<'=>**

=for highlighter language=perl

 # perl code
 my $sneaky = '</code>';
 {
     # indented
     {
         # indented more
         ;
     }
 }

Done.

=head2 Lists

=head3 Unordered

=over

=item *

foo

=item *

bar

=item *

baz

=back

=head3 Ordered

=over

=item 1.

foo

=item 2.

bar

=item 3.

baz

=back

=head3 Definition

=over

=item TLA

three-letter acronym

=back

=head3 Nested

=over

=item 1.

alpha

=over

=item *

I

=item *

II

=back

=item 2.

beta

=over

=item *

III

=item *

IV

=back

=back

=head2 Inline DokuWiki Markup

=begin dokuwiki

{{mtfnpy.png?left|altitle}}
and <sub>any</sub> <sup>old</sup> <del>nonsense</del> features.

=end dokuwiki

=cut

-------------------------------------------------------------------------------

====== DokuWiki Test ======

===== Text Formatting =====

%%Rendered: %%**%%bold%%**%%, %%//%%italic%%//%%, %%__%%underlined%%__%%, %%''%%monospace%%''%%, %%**__//''%%combined%%''//__**%%.%%

%%Unrendered: **bold**, //italic//, __underlined__, ''monospace'', **__//''combined''//__**.%%

%%Funky: %%<nowiki>%%</nowiki><nowiki>%%</nowiki>%%% <nowiki> </nowiki>.%%

===== Links =====

%%URLs: %%[[https://www.dokuwiki.org/DokuWiki|DokuWiki]]%% (hyperlinked text), %%[[https://www.dokuwiki.org/faq|https://www.dokuwiki.org/faq]]%% (bare link), https://example.com (not a link).%%

%%Man page: %%[[https://www.man7.org/linux/man-pages/man1/man.1.html|man(1)]]%%.%%

%%POD links: %%[[https://perldoc.perl.org/perlapi|perlapi]]%% (perl), %%[[https://perldoc.perl.org/perlapi#Debugging|"Debugging" in perlapi]]%% (perl+section), %%[[https://metacpan.org/pod/Scalar%3A%3AUtil|Scalar::Util]]%% (module), %%[[https://metacpan.org/pod/Scalar%3A%3AUtil#OTHER-FUNCTIONS|"OTHER FUNCTIONS" in Scalar::Util]]%% (module+section).%%

%%Internal: %%[[#Links|"Links"]]%%.%%

===== Headings =====

==== Level 3 Heading ====

=== Level 4 Heading ===

== Level 5 Heading ==

//%%Level 6 Heading%%//

===== Code Blocks =====

<code>
code
unspecified language
%%C<'=>**
</code>

<file perl>
# perl code
my $sneaky = '</code>';
{
    # indented
    {
        # indented more
        ;
    }
}
</file>

%%Done.%%

===== Lists =====

==== Unordered ====
  * %%foo%%
  * %%bar%%
  * %%baz%%


==== Ordered ====
  - %%foo%%
  - %%bar%%
  - %%baz%%


==== Definition ====
  * //%%TLA%%// \\ %%three-letter acronym%%


==== Nested ====
  - %%alpha%%
    * %%I%%
    * %%II%%
  - %%beta%%
    * %%III%%
    * %%IV%%


===== Inline DokuWiki Markup =====

{{mtfnpy.png?left|altitle}}
and <sub>any</sub> <sup>old</sup> <del>nonsense</del> features.
