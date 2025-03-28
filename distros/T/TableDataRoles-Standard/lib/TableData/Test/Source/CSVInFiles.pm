package ## no critic: Modules::RequireFilenameMatchesPackage
    # hide from PAUSE
    TableDataRole::Test::Source::CSVInFiles;

use 5.010001;
use strict;
use warnings;

use Role::Tiny;
with 'TableDataRole::Source::CSVInFiles';

around new => sub {
    my $orig = shift;

    require File::Basename;
    my @filenames;
    for my $i (1..3) {
        my $filename = File::Basename::dirname(__FILE__) . "/../../../../share/examples/eng-ind$i.csv";
        unless (-f $filename) {
            require File::ShareDir;
            $filename = File::ShareDir::dist_file('TableDataRoles-Standard', "examples/eng-ind$i.csv");
        }
        push @filenames, $filename;
    }
    $orig->(@_, filenames=>\@filenames);
};

package TableData::Test::Source::CSVInFiles;

use 5.010001;
use strict;
use warnings;

use Role::Tiny::With;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-05-14'; # DATE
our $DIST = 'TableDataRoles-Standard'; # DIST
our $VERSION = '0.025'; # VERSION

with 'TableDataRole::Test::Source::CSVInFiles';

1;
# ABSTRACT: Some English words with Indonesian equivalents

__END__

=pod

=encoding UTF-8

=head1 NAME

TableDataRole::Test::Source::CSVInFiles - Some English words with Indonesian equivalents

=head1 VERSION

This document describes version 0.025 of TableDataRole::Test::Source::CSVInFiles (from Perl distribution TableDataRoles-Standard), released on 2024-05-14.

=head1 SYNOPSIS

To use from Perl code:

 use TableData::Test::Source::CSVInFiles;

 my $td = TableData::Test::Source::CSVInFiles->new;

 # Iterate rows of the table
 $td->each_row_arrayref(sub { my $row = shift; ... });
 $td->each_row_hashref (sub { my $row = shift; ... });

 # Get the list of column names
 my @columns = $td->get_column_names;

 # Get the number of rows
 my $row_count = $td->get_row_count;

See also L<TableDataRole::Spec::Basic> for other methods.

To use from command-line (using L<tabledata> CLI):

 # Display as ASCII table and view with pager
 % tabledata Test::Source::CSVInFiles --page

 # Get number of rows
 % tabledata --action count_rows Test::Source::CSVInFiles

See the L<tabledata> CLI's documentation for other available actions and options.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/TableDataRoles-Standard>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-TableDataRoles-Standard>.

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

This software is copyright (c) 2024, 2023, 2022, 2021 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=TableDataRoles-Standard>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
