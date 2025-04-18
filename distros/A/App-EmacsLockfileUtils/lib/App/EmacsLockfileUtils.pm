package App::EmacsLockfileUtils;

use strict;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2025-03-13'; # DATE
our $DIST = 'App-EmacsLockfileUtils'; # DIST
our $VERSION = '0.001'; # VERSION

1;
# ABSTRACT: Utilities related to Emacs-style lock files

__END__

=pod

=encoding UTF-8

=head1 NAME

App::EmacsLockfileUtils - Utilities related to Emacs-style lock files

=head1 VERSION

This document describes version 0.001 of App::EmacsLockfileUtils (from Perl distribution App-EmacsLockfileUtils), released on 2025-03-13.

=head1 DESCRIPTION

This distributions provides the following command-line utilities:

=over

=item * L<emacs-lockfile-get>

=item * L<emacs-lockfile-lock>

=item * L<emacs-lockfile-locked>

=item * L<emacs-lockfile-unlock>

=back

which are CLI interface for the functions in the L<File::Lockfile::Emacs>.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/App-EmacsLockfileUtils>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-EmacsLockfileUtils>.

=head1 SEE ALSO

L<File::Lockfile::Emacs>

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

This software is copyright (c) 2025 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-EmacsLockfileUtils>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
