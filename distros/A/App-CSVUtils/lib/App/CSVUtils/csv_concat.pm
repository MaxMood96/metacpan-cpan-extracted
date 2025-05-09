package App::CSVUtils::csv_concat;

use 5.010001;
use strict;
use warnings;
use Log::ger;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2025-02-04'; # DATE
our $DIST = 'App-CSVUtils'; # DIST
our $VERSION = '1.036'; # VERSION

use App::CSVUtils qw(
                        gen_csv_util
                );

gen_csv_util(
    name => 'csv_concat',
    summary => 'Concatenate several CSV files together, '.
        'collecting all the fields',
    description => <<'MARKDOWN',

Example, concatenating this CSV:

    col1,col2
    1,2
    3,4

and:

    col2,col4
    a,b
    c,d
    e,f

and:

    col3
    X
    Y

will result in:

    col1,col2,col4,col3
    1,2,
    3,4,
    ,a,b
    ,c,d
    ,e,f
    ,,,X
    ,,,Y

When `--overlay` option is enabled, the result will be:

    col1,col2,col4,col3
    1,2,b,X
    3,4,d,Y
    ,e,f,

When `--overlay` as well as `--overwrite-fields` option are enabled, the result
will be:

    col1,col2,col4,col3
    1,a,b,X
    3,c,d,Y
    ,e,f,

Keywords: join, merge, overlay

MARKDOWN
    add_args => {
        overlay => {
            summary => 'Whether to overlay rows from second and subsequent CSV files to the first',
            schema => 'bool*',
            description => <<'MARKDOWN',

By default, rows from the second CSV file will be added after all the rows from
the first CSV are added, and so on. However, when this option is enabled, the
rows the second and subsequent CSV files will be added together (overlaid). See
the utility's example for an illustration.

See also the `--overwrite-fields` option.

MARKDOWN
        },
        overwrite_fields => {
            summary => 'Whether fields from subsequent CSV files should overwrite existing fields from previous CSV files',
            schema => 'bool*',
            description => <<'MARKDOWN',

When in overlay mode (`--overlay`), by default the value for a field is
retrieved from the first CSV file that has the field. With `--overwrite-fields`
option enabled, the value will be retrieved from the last CSV that has the
field. See the utility's example for an illustration.

MARKDOWN
        },
    },
    tags => ['category:combining', 'join', 'merge'],

    reads_multiple_csv => 1,

    before_open_input_files => sub {
        my $r = shift;

        # we add the following keys to the stash
        $r->{all_input_fields} = [];
        $r->{all_input_fh} = [];
    },

    on_input_header_row => sub {
        my $r = shift;

        # after we read the header row of each input file, we record the fields
        # as well as the filehandle, so we can resume reading the data rows
        # later. before printing all the rows, we collect all the fields from
        # all files first.

        push @{ $r->{all_input_fields} }, $r->{input_fields};
        push @{ $r->{all_input_fh} }, $r->{input_fh};
        $r->{wants_skip_file}++;
    },

    after_close_input_files => sub {
        my $r = shift;

        # as described in the on_input_header_row hook, we have saved the input
        # fields as well as the filehandles. so even though we are called in the
        # after_close_input_files hook, where the main routine supposedly has
        # closed all input files, we actually have saved the filehandles and can
        # resume reading from them.

        # collect all output fields
        $r->{output_fields} = [];
        $r->{output_fields_idx} = {};
        for my $i (0 .. $#{ $r->{all_input_fields} }) {
            my $input_fields = $r->{all_input_fields}[$i];
            for my $j (0 .. $#{ $input_fields }) {
                my $field = $input_fields->[$j];
                unless (grep {$field eq $_} @{ $r->{output_fields} }) {
                    push @{ $r->{output_fields} }, $field;
                    $r->{output_fields_idx}{$field} = $#{ $r->{output_fields} };
                }
            }
        }

        my $csv = $r->{input_parser};

        if ($r->{util_args}{overlay}) {

            my $overwrite_fields = $r->{util_args}{overwrite_fields};
            my $output_fields_idx = $r->{output_fields_idx};
            while (1) {
                my $has_not_eof;
                my $combined_row = [("") x @{ $r->{output_fields} }];
                my %seen_fields;
                for my $i (0 .. $#{ $r->{all_input_fh} }) {
                    my $fh = $r->{all_input_fh}[$i];

                    next if eof($fh);
                    $has_not_eof++;
                    my $row = $csv->getline($fh);
                    my $input_fields = $r->{all_input_fields}[$i];
                    for my $j (0 .. $#{ $input_fields }) {
                        my $field = $input_fields->[$j];
                        if (!($seen_fields{$field}++) || $overwrite_fields) {
                            $combined_row->[ $output_fields_idx->{$field} ] = $row->[$j];
                        }
                    }
                } # for all_input_fh
                last unless $has_not_eof;
                $r->{code_print_row}->($combined_row);
            } # while 1

        } else {

            # print all the data rows
            for my $i (0 .. $#{ $r->{all_input_fh} }) {
                log_trace "[%d/%d] Adding rows from file #%d ...",
                    $i+1, scalar(@{$r->{all_input_fh}}), $i+1;
                my $fh = $r->{all_input_fh}[$i];
                my $input_fields = $r->{all_input_fields}[$i];
                while (my $row = $csv->getline($fh)) {
                    my $combined_row = [("") x @{ $r->{output_fields} }];
                    for my $j (0 .. $#{ $input_fields }) {
                        my $field = $input_fields->[$j];
                        $combined_row->[ $r->{output_fields_idx}{$field} ] = $row->[$j];
                    }
                    $r->{code_print_row}->($combined_row);
                }
            } # for all input fh

        }
    },
);

1;
# ABSTRACT: Concatenate several CSV files together, collecting all the fields

__END__

=pod

=encoding UTF-8

=head1 NAME

App::CSVUtils::csv_concat - Concatenate several CSV files together, collecting all the fields

=head1 VERSION

This document describes version 1.036 of App::CSVUtils::csv_concat (from Perl distribution App-CSVUtils), released on 2025-02-04.

=head1 FUNCTIONS


=head2 csv_concat

Usage:

 csv_concat(%args) -> [$status_code, $reason, $payload, \%result_meta]

Concatenate several CSV files together, collecting all the fields.

Example, concatenating this CSV:

 col1,col2
 1,2
 3,4

and:

 col2,col4
 a,b
 c,d
 e,f

and:

 col3
 X
 Y

will result in:

 col1,col2,col4,col3
 1,2,
 3,4,
 ,a,b
 ,c,d
 ,e,f
 ,,,X
 ,,,Y

When C<--overlay> option is enabled, the result will be:

 col1,col2,col4,col3
 1,2,b,X
 3,4,d,Y
 ,e,f,

When C<--overlay> as well as C<--overwrite-fields> option are enabled, the result
will be:

 col1,col2,col4,col3
 1,a,b,X
 3,c,d,Y
 ,e,f,

Keywords: join, merge, overlay

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

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

=item * B<input_filenames> => I<array[filename]> (default: ["-"])

Input CSV files.

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

=item * B<overlay> => I<bool>

Whether to overlay rows from second and subsequent CSV files to the first.

By default, rows from the second CSV file will be added after all the rows from
the first CSV are added, and so on. However, when this option is enabled, the
rows the second and subsequent CSV files will be added together (overlaid). See
the utility's example for an illustration.

See also the C<--overwrite-fields> option.

=item * B<overwrite> => I<bool>

Whether to override existing output file.

=item * B<overwrite_fields> => I<bool>

Whether fields from subsequent CSV files should overwrite existing fields from previous CSV files.

When in overlay mode (C<--overlay>), by default the value for a field is
retrieved from the first CSV file that has the field. With C<--overwrite-fields>
option enabled, the value will be retrieved from the last CSV that has the
field. See the utility's example for an illustration.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)

=head1 IMPLEMENTATION NOTES

We first read only the header rows for all input files, while collecting the
input filehandles. Then we read the data rows of all the files ourselves.

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
