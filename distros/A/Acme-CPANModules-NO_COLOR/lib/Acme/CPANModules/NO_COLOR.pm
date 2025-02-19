package Acme::CPANModules::NO_COLOR;

use strict;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-10-29'; # DATE
our $DIST = 'Acme-CPANModules-NO_COLOR'; # DIST
our $VERSION = '0.010'; # VERSION

our $LIST = {
    summary => "List of modules/scripts that follow the NO_COLOR convention",
    description => <<'_',

The NO_COLOR convention (see <https://no-color.org>) lets user disable color
output of console programs by defining an environment variable called NO_COLOR.
The existence of said environment variable, regardless of its value, signals
that programs should not use colored output.

If you know of other modules that should be listed here, please contact me.

_
    entries => [
        {module=>'App::ccdiff', script=>'ccdiff'},
        {module=>'App::Codeowners', script=>'git-codeowners'},
        {module=>'App::DiffTarballs', script=>'diff-tarballs'},
        {module=>'App::HL7::Dump', script=>'hl7dump'},
        {module=>'App::hr', script=>'hr'},
        {module=>'App::Licensecheck', script=>'licensecheck'},
        {module=>'App::riap', script=>'riap'},
        {module=>'App::rsynccolor', script=>'rsynccolor'},
        {module=>'Color::ANSI::Util'},
        # ColorThemeUtil::ANSI does not count
        {module=>'Data::Dump::Color'},
        {module=>'Debug::Print'},
        {module=>'Git::Deploy', script=>'git-deploy'},
        {module=>'Indent::Form'},
        {module=>'JSON::Color'},
        {module=>'Log::Any::Adapter::Screen'},
        {module=>'Log::ger::Output::Screen'},
        {module=>'Parse::Netstat::Colorizer', script=>'cnetstat'},
        {module=>'Proc::ProcessTable::ncps', script=>'ncps'},
        {module=>'Progress::Any::Output::TermProgressBar'},
        {module=>'Search::ESsearcher', script=>'essearcher'},
        {module=>'Spreadsheet::Read', script=>'xls2csv'},
        {module=>'String::Tagged::Terminal'},
        {module=>'Term::ANSIColor'},
        {module=>'Term::ANSIColor::Conditional'},
        {module=>'Term::ANSIColor::Patch::Conditional'},
        {module=>'Term::App::Roles'},
        {module=>'Term::App::Roles::Attrs'},
        {module=>'Term::App::Util::Color'},
        {module=>'Text::CSV_XS', script=>'csvdiff'},
        {module=>'Tree::Shell', script=>'treesh'},
    ],
    links => [
        {url=>'pm:Acme::CPANModules::COLOR'},
        {url=>'pm:Acme::CPANModules::ColorEnv'},
    ],
};

1;
# ABSTRACT: List of modules/scripts that follow the NO_COLOR convention

__END__

=pod

=encoding UTF-8

=head1 NAME

Acme::CPANModules::NO_COLOR - List of modules/scripts that follow the NO_COLOR convention

=head1 VERSION

This document describes version 0.010 of Acme::CPANModules::NO_COLOR (from Perl distribution Acme-CPANModules-NO_COLOR), released on 2023-10-29.

=head1 DESCRIPTION

The NO_COLOR convention (see L<https://no-color.org>) lets user disable color
output of console programs by defining an environment variable called NO_COLOR.
The existence of said environment variable, regardless of its value, signals
that programs should not use colored output.

If you know of other modules that should be listed here, please contact me.

=head1 ACME::CPANMODULES ENTRIES

=over

=item L<App::ccdiff>

Author: L<HMBRAND|https://metacpan.org/author/HMBRAND>

Script: L<ccdiff>

=item L<App::Codeowners>

Author: L<CCM|https://metacpan.org/author/CCM>

Script: L<git-codeowners>

=item L<App::DiffTarballs>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

Script: L<diff-tarballs>

=item L<App::HL7::Dump>

Author: L<SKIM|https://metacpan.org/author/SKIM>

Script: L<hl7dump>

=item L<App::hr>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

Script: L<hr>

=item L<App::Licensecheck>

Author: L<JONASS|https://metacpan.org/author/JONASS>

Script: L<licensecheck>

=item L<App::riap>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

Script: L<riap>

=item L<App::rsynccolor>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

Script: L<rsynccolor>

=item L<Color::ANSI::Util>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Data::Dump::Color>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Debug::Print>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Git::Deploy>

Author: L<AVAR|https://metacpan.org/author/AVAR>

Script: L<git-deploy>

=item L<Indent::Form>

Author: L<SKIM|https://metacpan.org/author/SKIM>

=item L<JSON::Color>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Log::Any::Adapter::Screen>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Log::ger::Output::Screen>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Parse::Netstat::Colorizer>

Author: L<VVELOX|https://metacpan.org/author/VVELOX>

Script: L<cnetstat>

=item L<Proc::ProcessTable::ncps>

Author: L<VVELOX|https://metacpan.org/author/VVELOX>

Script: L<ncps>

=item L<Progress::Any::Output::TermProgressBar>

=item L<Search::ESsearcher>

Author: L<VVELOX|https://metacpan.org/author/VVELOX>

Script: L<essearcher>

=item L<Spreadsheet::Read>

Author: L<HMBRAND|https://metacpan.org/author/HMBRAND>

Script: L<xls2csv>

=item L<String::Tagged::Terminal>

Author: L<PEVANS|https://metacpan.org/author/PEVANS>

=item L<Term::ANSIColor>

Author: L<RRA|https://metacpan.org/author/RRA>

=item L<Term::ANSIColor::Conditional>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Term::ANSIColor::Patch::Conditional>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Term::App::Roles>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Term::App::Roles::Attrs>

=item L<Term::App::Util::Color>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Text::CSV_XS>

Author: L<HMBRAND|https://metacpan.org/author/HMBRAND>

Script: L<csvdiff>

=item L<Tree::Shell>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

Script: L<treesh>

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

 % cpanm-cpanmodules -n NO_COLOR

Alternatively you can use the L<cpanmodules> CLI (from L<App::cpanmodules>
distribution):

    % cpanmodules ls-entries NO_COLOR | cpanm -n

or L<Acme::CM::Get>:

    % perl -MAcme::CM::Get=NO_COLOR -E'say $_->{module} for @{ $LIST->{entries} }' | cpanm -n

or directly:

    % perl -MAcme::CPANModules::NO_COLOR -E'say $_->{module} for @{ $Acme::CPANModules::NO_COLOR::LIST->{entries} }' | cpanm -n

This Acme::CPANModules module also helps L<lcpan> produce a more meaningful
result for C<lcpan related-mods> command when it comes to finding related
modules for the modules listed in this Acme::CPANModules module.
See L<App::lcpan::Cmd::related_mods> for more details on how "related modules"
are found.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Acme-CPANModules-NO_COLOR>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Acme-CPANModules-NO_COLOR>.

=head1 SEE ALSO

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

This software is copyright (c) 2023, 2021, 2020, 2018 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Acme-CPANModules-NO_COLOR>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
