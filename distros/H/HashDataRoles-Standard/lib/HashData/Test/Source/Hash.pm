## no critic: TestingAndDebugging::RequireUseStrict
package HashData::Test::Source::Hash;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-11-04'; # DATE
our $DIST = 'HashDataRoles-Standard'; # DIST
our $VERSION = '0.005'; # VERSION

use alias::module 'HashData::Hash';

1;
# ABSTRACT: Alias package for HashData::Hash

__END__

=pod

=encoding UTF-8

=head1 NAME

HashData::Test::Source::Hash - Alias package for HashData::Hash

=head1 VERSION

This document describes version 0.005 of HashData::Test::Source::Hash (from Perl distribution HashDataRoles-Standard), released on 2024-11-04.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/HashDataRoles-Standard>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-HashDataRoles-Standard>.

=head1 SEE ALSO

L<HashData::Hash>

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

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=HashDataRoles-Standard>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
