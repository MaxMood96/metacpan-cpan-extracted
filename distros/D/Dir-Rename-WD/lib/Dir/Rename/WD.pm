package Dir::Rename::WD;

use strict;
use warnings;

use Cwd 'cwd';
use Errno qw(EINVAL EBUSY);
use Exporter qw(import);

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2026-04-28'; # DATE
our $DIST = 'Dir-Rename-WD'; # DIST
our $VERSION = '0.002'; # VERSION

our @EXPORT_OK = qw(rename_wd);

sub rename_wd {
    defined(my $new_name = shift) or do { $! = EINVAL; return };
    @_ and do { $! = EINVAL; return };

    # check new name
    length $new_name or do { $! = EINVAL; return };
    $new_name =~ s!\\!/!g if $^O eq 'MSWin32';
    $new_name =~ m!/! and do { $! = EINVAL; return };
    $new_name eq '.' and return 1;
    $new_name eq '..' and do { $! = EINVAL; return };

    # up one dir
    my $cwd = cwd();
    $cwd =~ s!\\!/!g if $^O eq 'MSWin32';
    $cwd =~ s!.+/!!;
    if ($cwd eq '/') { $! = EBUSY; return }
    chdir ".." or return;

    # rename
    rename $cwd, $new_name or return;

    # cd into new dir
    chdir $new_name or return;

    1;
}

1;
# ABSTRACT: Rename current working directory

__END__

=pod

=encoding UTF-8

=head1 NAME

Dir::Rename::WD - Rename current working directory

=head1 VERSION

This document describes version 0.002 of Dir::Rename::WD (from Perl distribution Dir-Rename-WD), released on 2026-04-28.

=head1 SYNOPSIS

 use Dir::Rename::WD qw(rename_wd);

 rename_wd "newname" or die "Can't rename working directory: $!";

=head1 DESCRIPTION

This module provides a single routine to change working directory then put the
process back to the newly renamed working directory. Basically to do this, we
change directory up one level first, then change into the directory after the
rename.

=head1 FUNCTIONS

=head2 rename_wd

Usage:

 rename_wd $newname

Rename current working directory. Takes a single argument (will set C<$!> to
C<EINVAL> if argument not supplied or extra arguments are supplied).

Return true on success, false otherwise (check C<$!> for error detail). Failing
also include case when directory has been renamed but we cannot change back into
it e.g. due to permission problem like directory not having execute bit set.

Root directory cannot be renamed (will set C<$!> to C<EBUSY>).

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Dir-Rename-WD>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Dir-Rename-WD>.

=head1 SEE ALSO

L<renwd> from L<App::renwd> provides a CLI for this routine.

L<renlikewd> from L<App::renlikewd> which provides tab completion for renaming
current directory on the CLI.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTOR

=for stopwords perlancar

perlancar <perlancar@gmail.com>

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

This software is copyright (c) 2026 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Dir-Rename-WD>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
