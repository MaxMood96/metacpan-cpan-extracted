package TableDataRole::Spec::TableDef;

use strict;
use warnings;

use Role::Tiny;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-02-24'; # DATE
our $DIST = 'TableDataRole-Spec-TableDef'; # DIST
our $VERSION = '0.001'; # VERSION

requires 'get_table_def';

1;
# ABSTRACT: Role to require methods related to TableDef

__END__

=pod

=encoding UTF-8

=head1 NAME

TableDataRole::Spec::TableDef - Role to require methods related to TableDef

=head1 VERSION

This document describes version 0.001 of TableDataRole::Spec::TableDef (from Perl distribution TableDataRole-Spec-TableDef), released on 2023-02-24.

=head1 DESCRIPTION

=for Pod::Coverage ^(.+)$

=head1 REQUIRED METHODS

=head2 get_table_def

Usage:

 my $def = $CLASS->get_table_def;

Must return hashref (defhash) structure as described in L<TableDef>.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/TableDataRole-Spec-TableDef>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-TableDataRole-Spec-TableDef>.

=head1 SEE ALSO

L<TableDef>

L<TableData>

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

This software is copyright (c) 2023 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=TableDataRole-Spec-TableDef>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
