package SortKey::Num::by_length;

use 5.010001;
use strict;
use warnings;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-01-23'; # DATE
our $DIST = 'SortKey-Num-by_length'; # DIST
our $VERSION = '0.001'; # VERSION

sub meta {
    return +{
        v => 1,
        args => {
        },
    };
}

sub gen_keygen {
    my %args = @_;

    \&CORE::length;
}

1;
# ABSTRACT: String length as sort key

__END__

=pod

=encoding UTF-8

=head1 NAME

SortKey::Num::by_length - String length as sort key

=head1 VERSION

This document describes version 0.001 of SortKey::Num::by_length (from Perl distribution SortKey-Num-by_length), released on 2024-01-23.

=head1 SYNOPSIS

 use Sort::Key qw(nkeysort);
 use SortKey::Num::by_length;

 my $keygen = SortKey::Num::by_length::gen_keygen;
 my @sorted = &nkeysort($keygen, "food", "foolish", "foo");

=head1 DESCRIPTION

This is just a demonstration module for L<SortKey>. You might just as well:

 nkeysort { length shift } ...

=for Pod::Coverage ^(meta|gen_keygen)$

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/SortKey-Num-by_length>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-SortKey-Num-by_length>.

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

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=SortKey-Num-by_length>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
