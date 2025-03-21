package Acme::CPANModules::ArrayData;

use strict;
use warnings;

use Acme::CPANModulesUtil::Misc;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-01-22'; # DATE
our $DIST = 'Acme-CPANModules-ArrayData'; # DIST
our $VERSION = '0.001'; # VERSION

my $text = <<'MARKDOWN';

<pm:ArrayData> is a way to package 1-dimensional array data as a Perl/CPAN
module. It also provides a standard interface to access the data, including
iterating the data rows, getting the column names, and so on.


**The data**

All Perl modules under `ArrayData::*` namespace are modules that contain array
data data. Examples include: `ArrayData::Sample::DeNiro`,
`ArrayData::Lingua::Word::EN::Enable`.


**CLIs**

<prog:arraydata> (from <pm:App::arraydata>) is the official CLI for `ArrayData`.


**Sah schemas**

<pm:Sah::Schemas::ArrayData>


**Tie**

<pm:Tie::Array::ArrayData> if you are more comfortable in accessing an ArrayData
as a regular (tied) Perl array.


MARKDOWN

our $LIST = {
    summary => 'List of modules related to ArrayData',
    description => $text,
    tags => ['task'],
};

Acme::CPANModulesUtil::Misc::populate_entries_from_module_links_in_description;

1;
# ABSTRACT: List of modules related to ArrayData

__END__

=pod

=encoding UTF-8

=head1 NAME

Acme::CPANModules::ArrayData - List of modules related to ArrayData

=head1 VERSION

This document describes version 0.001 of Acme::CPANModules::ArrayData (from Perl distribution Acme-CPANModules-ArrayData), released on 2024-01-22.

=head1 DESCRIPTION

L<ArrayData> is a way to package 1-dimensional array data as a Perl/CPAN
module. It also provides a standard interface to access the data, including
iterating the data rows, getting the column names, and so on.

B<The data>

All Perl modules under C<ArrayData::*> namespace are modules that contain array
data data. Examples include: C<ArrayData::Sample::DeNiro>,
C<ArrayData::Lingua::Word::EN::Enable>.

B<CLIs>

L<arraydata> (from L<App::arraydata>) is the official CLI for C<ArrayData>.

B<Sah schemas>

L<Sah::Schemas::ArrayData>

B<Tie>

L<Tie::Array::ArrayData> if you are more comfortable in accessing an ArrayData
as a regular (tied) Perl array.

=head1 ACME::CPANMODULES ENTRIES

=over

=item L<ArrayData>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<App::arraydata>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Sah::Schemas::ArrayData>

Author: L<PERLANCAR|https://metacpan.org/author/PERLANCAR>

=item L<Tie::Array::ArrayData>

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

 % cpanm-cpanmodules -n ArrayData

Alternatively you can use the L<cpanmodules> CLI (from L<App::cpanmodules>
distribution):

    % cpanmodules ls-entries ArrayData | cpanm -n

or L<Acme::CM::Get>:

    % perl -MAcme::CM::Get=ArrayData -E'say $_->{module} for @{ $LIST->{entries} }' | cpanm -n

or directly:

    % perl -MAcme::CPANModules::ArrayData -E'say $_->{module} for @{ $Acme::CPANModules::ArrayData::LIST->{entries} }' | cpanm -n

This Acme::CPANModules module also helps L<lcpan> produce a more meaningful
result for C<lcpan related-mods> command when it comes to finding related
modules for the modules listed in this Acme::CPANModules module.
See L<App::lcpan::Cmd::related_mods> for more details on how "related modules"
are found.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Acme-CPANModules-ArrayData>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Acme-CPANModules-ArrayData>.

=head1 SEE ALSO

Related lists: L<Acme::CPANModules::TableData>, L<Acme::CPANModules::HashData>.

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

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Acme-CPANModules-ArrayData>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
