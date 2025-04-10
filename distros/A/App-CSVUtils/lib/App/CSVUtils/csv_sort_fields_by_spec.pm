package App::CSVUtils::csv_sort_fields_by_spec;

use 5.010001;
use strict;
use warnings;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2025-02-04'; # DATE
our $DIST = 'App-CSVUtils'; # DIST
our $VERSION = '1.036'; # VERSION

use App::CSVUtils;
use App::CSVUtils::csv_sort_fields;
use Perinci::Sub::Util qw(gen_modified_sub);

my $res = gen_modified_sub(
    output_name => 'csv_sort_fields_by_spec',
    base_name => 'App::CSVUtils::csv_sort_fields::csv_sort_fields',
    summary => 'Sort CSV fields by spec',
    description => <<'MARKDOWN',

This is a thin wrapper for <prog:csv-sort-fields> to allow you to sort "by
spec". Sorting by spec is an advanced form of sorting by example. In addition to
specifying strings of examples, you can also specify regexes or Perl sorter
codes. For more details, see the sorting backend module <pm:Sort::BySpec>.

To specify a regex on the command-line, use one of these forms:

    /.../
    qr(...)

and to specify Perl code on the command-line, use this form:

    sub { ... }

For example, modifying from example in `Sort::BySpec`'s Synopsis, you want to
sort these fields:

    field1..field15 field42

as follow: 1) put fields with odd numbers first in ascending order; 2) put the
specific fields field4, field2, field42 in that order; 3) put the remaining
fields of even numbers in descending order. To do this:

    % perl -E'say join(",",map {"field$_"} 1..15,42)' | csv-sort-fields-by-spec - \
        'qr([13579]\z)' 'sub { my($a,$b)=@_; for($a,$b){s/field//} $a<=>$b }' \
        field4 field2 field42 \
        'sub { my($a,$b)=@_; for($a,$b){s/field//} $b<=>$a }'

The result:

    field1,field3,field5,field7,field9,field11,field13,field15,field4,field2,field42,field14,field12,field10,field8,field6

MARKDOWN
    remove_args => ['by_examples', 'by_code', 'by_sortsub'],
    add_args => {
        specs => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'spec',
            summary => 'Spec entries',
            'summary.alt.plurality.singular' => 'Add a spec entry',
            schema => ['array*', of=>'str_or_re_or_code*'],
            req => 1,
            pos => 1,
            slurpy => 1,
            completion => \&App::CSVUtils::_complete_field,
        },
    },
    modify_args => {
        output_filename => sub {
            my $argspec = shift;
            delete $argspec->{pos};
        },
    },
    tags => ['category:sorting'],
    output_code => sub {
        my %args = @_;
        my $spec = delete $args{specs};
        require Sort::BySpec;
        App::CSVUtils::csv_sort_fields::csv_sort_fields(
            %args,
            by_code => Sort::BySpec::cmp_by_spec(spec=>$spec),
        );
    },
);

1;
# ABSTRACT: Sort CSV fields by spec

__END__

=pod

=encoding UTF-8

=head1 NAME

App::CSVUtils::csv_sort_fields_by_spec - Sort CSV fields by spec

=head1 VERSION

This document describes version 1.036 of App::CSVUtils::csv_sort_fields_by_spec (from Perl distribution App-CSVUtils), released on 2025-02-04.

=for Pod::Coverage ^(on|after|before)_.+$

=head1 FUNCTIONS


=head2 csv_sort_fields_by_spec

Usage:

 csv_sort_fields_by_spec(%args) -> [$status_code, $reason, $payload, \%result_meta]

Sort CSV fields by spec.

This is a thin wrapper for L<csv-sort-fields> to allow you to sort "by
spec". Sorting by spec is an advanced form of sorting by example. In addition to
specifying strings of examples, you can also specify regexes or Perl sorter
codes. For more details, see the sorting backend module L<Sort::BySpec>.

To specify a regex on the command-line, use one of these forms:

 /.../
 qr(...)

and to specify Perl code on the command-line, use this form:

 sub { ... }

For example, modifying from example in C<Sort::BySpec>'s Synopsis, you want to
sort these fields:

 field1..field15 field42

as follow: 1) put fields with odd numbers first in ascending order; 2) put the
specific fields field4, field2, field42 in that order; 3) put the remaining
fields of even numbers in descending order. To do this:

 % perl -E'say join(",",map {"field$_"} 1..15,42)' | csv-sort-fields-by-spec - \
     'qr([13579]\z)' 'sub { my($a,$b)=@_; for($a,$b){s/field//} $a<=>$b }' \
     field4 field2 field42 \
     'sub { my($a,$b)=@_; for($a,$b){s/field//} $b<=>$a }'

The result:

 field1,field3,field5,field7,field9,field11,field13,field15,field4,field2,field42,field14,field12,field10,field8,field6

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<ci> => I<bool>

(No description)

=item * B<inplace> => I<true>

Output to the same file as input.

Normally, you output to a different file than input. If you try to output to the
same file (C<-o INPUT.csv -O>) you will clobber the input file; thus the utility
prevents you from doing it. However, with this C<--inplace> option, you can
output to the same file. Like perl's C<-i> option, this will first output to a
temporary file in the same directory as the input file then rename to the final
file at the end. You cannot specify output file (C<-o>) when using this option,
but you can specify backup extension with C<-b> option.

Some caveats:

=over

=item * if input file is a symbolic link, it will be replaced with a regular file;

=item * renaming (implemented using C<rename()>) can fail if input filename is too long;

=item * value specified in C<-b> is currently not checked for acceptable characters;

=item * things can also fail if permissions are restrictive;

=back

=item * B<inplace_backup_ext> => I<str> (default: "")

Extension to add for backup of input file.

In inplace mode (C<--inplace>), if this option is set to a non-empty string, will
rename the input file using this extension as a backup. The old existing backup
will be overwritten, if any.

=item * B<input_escape_char> => I<str>

Specify character to escape value in field in input CSV, will be passed to Text::CSV_XS.

Defaults to C<\\> (backslash). Overrides C<--input-tsv> option.

=item * B<input_filename> => I<filename> (default: "-")

Input CSV file.

Use C<-> to read from stdin.

Encoding of input file is assumed to be UTF-8.

=item * B<input_header> => I<bool> (default: 1)

Specify whether input CSV has a header row.

By default, the first row of the input CSV will be assumed to contain field
names (and the second row contains the first data row). When you declare that
input CSV does not have header row (C<--no-input-header>), the first row of the
CSV is assumed to contain the first data row. Fields will be named C<field1>,
C<field2>, and so on.

=item * B<input_quote_char> => I<str>

Specify field quote character in input CSV, will be passed to Text::CSV_XS.

Defaults to C<"> (double quote). Overrides C<--input-tsv> option.

=item * B<input_sep_char> => I<str>

Specify field separator character in input CSV, will be passed to Text::CSV_XS.

Defaults to C<,> (comma). Overrides C<--input-tsv> option.

=item * B<input_skip_num_lines> => I<posint>

Number of lines to skip before header row.

This can be useful if you have a CSV files (usually some generated reports,
sometimes converted from spreadsheet) that have additional header lines or info
before the CSV header row.

See also the alternative option: C<--input-skip-until-pattern>.

=item * B<input_skip_until_pattern> => I<re_from_str>

Skip rows until the first header row matches a regex pattern.

This is an alternative to the C<--input-skip-num-lines> and can be useful if you
have a CSV files (usually some generated reports, sometimes converted from
spreadsheet) that have additional header lines or info before the CSV header
row.

With C<--input-skip-num-lines>, you skip a fixed number of lines. With this
option, rows will be skipped until the first field matches the specified regex
pattern.

=item * B<input_tsv> => I<true>

Inform that input file is in TSV (tab-separated) format instead of CSV.

Overriden by C<--input-sep-char>, C<--input-quote-char>, C<--input-escape-char>
options. If one of those options is specified, then C<--input-tsv> will be
ignored.

=item * B<output_always_quote> => I<bool> (default: 0)

Whether to always quote values.

When set to false (the default), values are quoted only when necessary:

 field1,field2,"field three contains comma (,)",field4

When set to true, then all values will be quoted:

 "field1","field2","field three contains comma (,)","field4"

=item * B<output_escape_char> => I<str>

Specify character to escape value in field in output CSV, will be passed to Text::CSV_XS.

This is like C<--input-escape-char> option but for output instead of input.

Defaults to C<\\> (backslash). Overrides C<--output-tsv> option.

=item * B<output_filename> => I<filename>

Output filename.

Use C<-> to output to stdout (the default if you don't specify this option).

Encoding of output file is assumed to be UTF-8.

=item * B<output_header> => I<bool>

Whether output CSV should have a header row.

By default, a header row will be output I<if> input CSV has header row. Under
C<--output-header>, a header row will be output even if input CSV does not have
header row (value will be something like "col0,col1,..."). Under
C<--no-output-header>, header row will I<not> be printed even if input CSV has
header row. So this option can be used to unconditionally add or remove header
row.

=item * B<output_quote_char> => I<str>

Specify field quote character in output CSV, will be passed to Text::CSV_XS.

This is like C<--input-quote-char> option but for output instead of input.

Defaults to C<"> (double quote). Overrides C<--output-tsv> option.

=item * B<output_quote_empty> => I<bool> (default: 0)

Whether to quote empty values.

When set to false (the default), empty values are not quoted:

 field1,field2,,field4

When set to true, then empty values will be quoted:

 field1,field2,"",field4

=item * B<output_sep_char> => I<str>

Specify field separator character in output CSV, will be passed to Text::CSV_XS.

This is like C<--input-sep-char> option but for output instead of input.

Defaults to C<,> (comma). Overrides C<--output-tsv> option.

=item * B<output_tsv> => I<bool>

Inform that output file is TSV (tab-separated) format instead of CSV.

This is like C<--input-tsv> option but for output instead of input.

Overriden by C<--output-sep-char>, C<--output-quote-char>, C<--output-escape-char>
options. If one of those options is specified, then C<--output-tsv> will be
ignored.

=item * B<overwrite> => I<bool>

Whether to override existing output file.

=item * B<reverse> => I<bool>

(No description)

=item * B<sortsub_args> => I<hash>

Arguments to pass to Sort::Sub routine.

=item * B<specs>* => I<array[str_or_re_or_code]>

Spec entries.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/App-CSVUtils>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-CSVUtils>.

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

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-CSVUtils>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
