package Perinci::Examples::CSV;

use 5.010;
use strict;
use warnings;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-07-17'; # DATE
our $DIST = 'Perinci-Examples'; # DIST
our $VERSION = '0.825'; # VERSION

our %SPEC;

$SPEC{output_table} = {
    v => 1.1,
    summary => "Output some table, try displaying it on CLI with --format=csv",
    args => {
    },
};
sub output_table {
    my %args = @_;

    my $table = [
        ["col1", "col2", "col3"],
        [1,2,3],
        [qw/foo bar baz/],
        ['"contains quotes"', 'contains \\backslash', '"contains \\both\\"'],
    ];

    [200, "OK", $table];
}

1;
# ABSTRACT: Test CSV output

__END__

=pod

=encoding UTF-8

=head1 NAME

Perinci::Examples::CSV - Test CSV output

=head1 VERSION

This document describes version 0.825 of Perinci::Examples::CSV (from Perl distribution Perinci-Examples), released on 2024-07-17.

=head1 DESCRIPTION

=head1 FUNCTIONS


=head2 output_table

Usage:

 output_table() -> [$status_code, $reason, $payload, \%result_meta]

Output some table, try displaying it on CLI with --format=csv.

This function is not exported.

No arguments.

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Perinci-Examples>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Perinci-Examples>.

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

This software is copyright (c) 2024, 2023, 2022, 2020, 2019, 2018, 2017, 2016, 2015, 2014, 2013, 2012, 2011 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Perinci-Examples>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
