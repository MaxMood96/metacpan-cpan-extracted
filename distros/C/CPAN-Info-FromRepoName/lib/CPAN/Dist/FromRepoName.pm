package CPAN::Dist::FromRepoName;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2020-10-02'; # DATE
our $DIST = 'CPAN-Info-FromRepoName'; # DIST
our $VERSION = '0.001'; # VERSION

use 5.010001;
use strict;
use warnings;

use CPAN::Info::FromRepoName qw(extract_cpan_info_from_repo_name);

use Exporter qw(import);
our @EXPORT_OK = qw(extract_cpan_dist_from_repo_name);

our %SPEC;

$SPEC{extract_cpan_dist_from_repo_name} = {
    v => 1.1,
    summary => 'Extract CPAN distribution name from a repos name',
    args => {
        repo_name => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
    args_as => 'array',
    result => {
        schema => 'str',
    },
    result_naked => 1,
    examples => [

        {
            name => "perl-<dist>",
            args => {repo_name=>'perl-Foo-Bar'},
            result => "Foo-Bar",
        },
        {
            name => 'unknown',
            args => {repo_name=>'@something'},
            result => undef,
        },
    ],
};
sub extract_cpan_dist_from_repo_name {
    my $repo_name = shift;

    my $ecires = extract_cpan_info_from_repo_name($repo_name);
    return undef unless defined $ecires;
    $ecires->{dist};
}

1;
# ABSTRACT: Extract CPAN distribution name from a repos name

__END__

=pod

=encoding UTF-8

=head1 NAME

CPAN::Dist::FromRepoName - Extract CPAN distribution name from a repos name

=head1 VERSION

This document describes version 0.001 of CPAN::Dist::FromRepoName (from Perl distribution CPAN-Info-FromRepoName), released on 2020-10-02.

=head1 FUNCTIONS


=head2 extract_cpan_dist_from_repo_name

Usage:

 extract_cpan_dist_from_repo_name($repo_name) -> str

Extract CPAN distribution name from a repos name.

Examples:

=over

=item * Example #1 (perl-<distE<gt>):

 extract_cpan_dist_from_repo_name("perl-Foo-Bar"); # -> "Foo-Bar"

=item * Example #2 (unknown):

 extract_cpan_dist_from_repo_name("\@something"); # -> undef

=back

This function is not exported by default, but exportable.

Arguments ('*' denotes required arguments):

=over 4

=item * B<$repo_name>* => I<str>


=back

Return value:  (str)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/CPAN-Info-FromRepoName>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-CPAN-Info-FromRepoName>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-Info-FromRepoName>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 SEE ALSO

L<CPAN::Dist::FromURL>

L<CPAN::Info::FromRepoName>, the more generic module which is used by this module.

L<CPAN::Author::FromRepoName>

L<CPAN::Module::FromRepoName>

L<CPAN::Release::FromRepoName>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
