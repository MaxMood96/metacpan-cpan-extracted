package Acme::CPANModules::MatchingString;

use strict;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-01-10'; # DATE
our $DIST = 'Acme-CPANModules-MatchingString'; # DIST
our $VERSION = '0.001'; # VERSION

our $LIST = {
    summary => "List of modules related to matching string",
    entries => [
        {
            module => 'String::FlexMatch',
            description => <<'MARKDOWN',

An object that can be instructed to match a string with another string, a regex,
or a coderef. The object overloads the `eq` operator so you can abstract the
actual matching mechanism and still use `eq` in your code. Does not yet provide
case-insensitive string vs string matching.

MARKDOWN
        },
        {
            module => 'String::Util::Match',
            description => <<'MARKDOWN',

Provide some routines related to matching string.

MARKDOWN
        },
        {
            module => 'match::simple',
            description => <<'MARKDOWN',

A smart-match implementation.

MARKDOWN
        },
        {
            module => 'match::smart',
            description => <<'MARKDOWN',

A smart-match implementation.

MARKDOWN
        },
    ],
};

1;
# ABSTRACT: List of modules related to matching string

__END__

=pod

=encoding UTF-8

=head1 NAME

Acme::CPANModules::MatchingString - List of modules related to matching string

=head1 VERSION

This document describes version 0.001 of Acme::CPANModules::MatchingString (from Perl distribution Acme-CPANModules-MatchingString), released on 2024-01-10.

=head1 DESCRIPTION

=head1 ACME::CPANMODULES ENTRIES

=over

=item L<String::FlexMatch>

Author: L<MARCEL|https://metacpan.org/author/MARCEL>

An object that can be instructed to match a string with another string, a regex,
or a coderef. The object overloads the C<eq> operator so you can abstract the
actual matching mechanism and still use C<eq> in your code. Does not yet provide
case-insensitive string vs string matching.


=item L<String::Util::Match>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

Provide some routines related to matching string.


=item L<match::simple>

Author: L<TOBYINK|https://metacpan.org/author/TOBYINK>

A smart-match implementation.


=item L<match::smart>

Author: L<TOBYINK|https://metacpan.org/author/TOBYINK>

A smart-match implementation.


=back

=head1 FAQ

=head2 What is an Acme::CPANModules::* module?

An Acme::CPANModules::* module, like this module, contains just a list of module
names that share a common characteristics. It is a way to categorize modules and
document CPAN. See L<Acme::CPANModules> for more details.

=head2 What are ways to use this Acme::CPANModules module?

Aside from reading this Acme::CPANModules module's POD documentation, you can
install all the listed modules (entries) using L<cpanm-cpanmodules> script (from
L<App::cpanm::cpanmodules> distribution):

 % cpanm-cpanmodules -n MatchingString

Alternatively you can use the L<cpanmodules> CLI (from L<App::cpanmodules>
distribution):

    % cpanmodules ls-entries MatchingString | cpanm -n

or L<Acme::CM::Get>:

    % perl -MAcme::CM::Get=MatchingString -E'say $_->{module} for @{ $LIST->{entries} }' | cpanm -n

or directly:

    % perl -MAcme::CPANModules::MatchingString -E'say $_->{module} for @{ $Acme::CPANModules::MatchingString::LIST->{entries} }' | cpanm -n

This Acme::CPANModules module also helps L<lcpan> produce a more meaningful
result for C<lcpan related-mods> command when it comes to finding related
modules for the modules listed in this Acme::CPANModules module.
See L<App::lcpan::Cmd::related_mods> for more details on how "related modules"
are found.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Acme-CPANModules-MatchingString>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Acme-CPANModules-MatchingString>.

=head1 SEE ALSO

L<Acme::CPANModules::SmartMatch>

L<Acme::CPANModules> - about the Acme::CPANModules namespace

L<cpanmodules> - CLI tool to let you browse/view the lists

=head1 AUTHOR

perlancar <perlancar@cpan.org>

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

This software is copyright (c) 2024 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Acme-CPANModules-MatchingString>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
