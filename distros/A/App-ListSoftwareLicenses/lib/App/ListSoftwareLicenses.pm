package App::ListSoftwareLicenses;

use 5.010001;
use strict;
use warnings;

use CHI;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-07-11'; # DATE
our $DIST = 'App-ListSoftwareLicenses'; # DIST
our $VERSION = '0.080'; # VERSION

our %SPEC;

my $cache = CHI->new(
    driver => 'File', root_dir=>$ENV{TMP} // $ENV{TEMP} // '/tmp');
my $table_spec = {
    summary => 'List of Software::License\'s',
    fields  => {
        module => {
            schema   => 'str*',
            index    => 0,
            sortable => 1,
        },
        meta_name => {
            schema   => 'str*',
            index    => 1,
            sortable => 1,
        },
        meta2_name => {
            schema   => 'str*',
            index    => 2,
            sortable => 1,
        },
        name => {
            schema   => 'str*',
            index    => 3,
            sortable => 1,
        },
        version => {
            schema   => 'str*',
            index    => 4,
            sortable => 1,
        },
        url => {
            schema   => 'str*',
            index    => 5,
            sortable => 1,
        },
        notice => {
            schema   => 'str*',
            index    => 6,
            sortable => 1,
        },
        text => {
            schema   => 'str*',
            index    => 7,
            sortable => 1,
            include_by_default => 0,
        },
    },
    pk => 'module',
};

# cache data for a day
my @excluded = qw(Software::License::Custom);
my $table_data = $cache->compute(
    'software_licenses', '24 hours', sub {
        require Module::List;
        require Module::Load;
        my $res = Module::List::list_modules(
            'Software::License::', {list_modules=>1});
        my $data = [map {[$_]} sort keys %$res];
        for my $row (@$data) {
            next if grep { $_ eq $row->[0] } @excluded;
            Module::Load::load($row->[0]);
            my $o;
            eval { $o = $row->[0]->new({holder => 'Copyright_Holder'}) };
            if ($@) {
                # some modules are not really software license, like
                # Software::License::CCpack which are just the main/placeholder
                # module for the Software-License-CCpack distribution.
                next;
            }
            $row->[1] = $o->meta_name;
            $row->[2] = $o->meta2_name;
            $row->[3] = $o->name;
            $row->[4] = $o->version;
            $row->[5] = $o->url;
            $row->[6] = $o->notice;
            $row->[7] = $o->license;
        }
        $data;
    });

use Perinci::Sub::Gen::AccessTable qw(gen_read_table_func);

my $res = gen_read_table_func(
    name       => 'list_software_licenses',
    summary    => 'List all Software::License\'s',
    table_data => $table_data,
    table_spec => $table_spec,
    enable_paging => 0, # there are only a handful of rows
    enable_random_ordering => 0,
);
die "Can't generate list_software_licenses function: $res->[0] - $res->[1]"
    unless $res->[0] == 200;

$SPEC{list_software_licenses}{examples} = [
    {
        argv    => [qw/perl/],
        summary => 'String search',
    },
];

1;
# ABSTRACT: List all Software::License's

__END__

=pod

=encoding UTF-8

=head1 NAME

App::ListSoftwareLicenses - List all Software::License's

=head1 VERSION

This document describes version 0.080 of App::ListSoftwareLicenses (from Perl distribution App-ListSoftwareLicenses), released on 2023-07-11.

=head1 FUNCTIONS


=head2 list_software_licenses

Usage:

 list_software_licenses(%args) -> [$status_code, $reason, $payload, \%result_meta]

List all Software::License's.

Examples:

=over

=item * String search:

 list_software_licenses(queries => ["perl"]);

Result:

 [
   200,
   "OK",
   [
     "Software::License::Artistic_1_0",
     "Software::License::Artistic_1_0_Perl",
     "Software::License::Artistic_2_0",
     "Software::License::LGPL_2_1",
     "Software::License::LGPL_3_0",
     "Software::License::Mozilla_1_0",
     "Software::License::Mozilla_1_1",
     "Software::License::Perl_5",
     "Software::License::Sun",
   ],
   { "table.fields" => ["module"] },
 ]

=back

REPLACE ME

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<detail> => I<bool> (default: 0)

Return array of full records instead of just ID fields.

By default, only the key (ID) field is returned per result entry.

=item * B<exclude_fields> => I<array[str]>

Select fields to return.

=item * B<fields> => I<array[str]>

Select fields to return.

=item * B<meta2_name> => I<str>

Only return records where the 'meta2_name' field equals specified value.

=item * B<meta2_name.contains> => I<str>

Only return records where the 'meta2_name' field contains specified text.

=item * B<meta2_name.in> => I<array[str]>

Only return records where the 'meta2_name' field is in the specified values.

=item * B<meta2_name.is> => I<str>

Only return records where the 'meta2_name' field equals specified value.

=item * B<meta2_name.isnt> => I<str>

Only return records where the 'meta2_name' field does not equal specified value.

=item * B<meta2_name.max> => I<str>

Only return records where the 'meta2_name' field is less than or equal to specified value.

=item * B<meta2_name.min> => I<str>

Only return records where the 'meta2_name' field is greater than or equal to specified value.

=item * B<meta2_name.not_contains> => I<str>

Only return records where the 'meta2_name' field does not contain specified text.

=item * B<meta2_name.not_in> => I<array[str]>

Only return records where the 'meta2_name' field is not in the specified values.

=item * B<meta2_name.xmax> => I<str>

Only return records where the 'meta2_name' field is less than specified value.

=item * B<meta2_name.xmin> => I<str>

Only return records where the 'meta2_name' field is greater than specified value.

=item * B<meta_name> => I<str>

Only return records where the 'meta_name' field equals specified value.

=item * B<meta_name.contains> => I<str>

Only return records where the 'meta_name' field contains specified text.

=item * B<meta_name.in> => I<array[str]>

Only return records where the 'meta_name' field is in the specified values.

=item * B<meta_name.is> => I<str>

Only return records where the 'meta_name' field equals specified value.

=item * B<meta_name.isnt> => I<str>

Only return records where the 'meta_name' field does not equal specified value.

=item * B<meta_name.max> => I<str>

Only return records where the 'meta_name' field is less than or equal to specified value.

=item * B<meta_name.min> => I<str>

Only return records where the 'meta_name' field is greater than or equal to specified value.

=item * B<meta_name.not_contains> => I<str>

Only return records where the 'meta_name' field does not contain specified text.

=item * B<meta_name.not_in> => I<array[str]>

Only return records where the 'meta_name' field is not in the specified values.

=item * B<meta_name.xmax> => I<str>

Only return records where the 'meta_name' field is less than specified value.

=item * B<meta_name.xmin> => I<str>

Only return records where the 'meta_name' field is greater than specified value.

=item * B<module> => I<str>

Only return records where the 'module' field equals specified value.

=item * B<module.contains> => I<str>

Only return records where the 'module' field contains specified text.

=item * B<module.in> => I<array[str]>

Only return records where the 'module' field is in the specified values.

=item * B<module.is> => I<str>

Only return records where the 'module' field equals specified value.

=item * B<module.isnt> => I<str>

Only return records where the 'module' field does not equal specified value.

=item * B<module.max> => I<str>

Only return records where the 'module' field is less than or equal to specified value.

=item * B<module.min> => I<str>

Only return records where the 'module' field is greater than or equal to specified value.

=item * B<module.not_contains> => I<str>

Only return records where the 'module' field does not contain specified text.

=item * B<module.not_in> => I<array[str]>

Only return records where the 'module' field is not in the specified values.

=item * B<module.xmax> => I<str>

Only return records where the 'module' field is less than specified value.

=item * B<module.xmin> => I<str>

Only return records where the 'module' field is greater than specified value.

=item * B<name> => I<str>

Only return records where the 'name' field equals specified value.

=item * B<name.contains> => I<str>

Only return records where the 'name' field contains specified text.

=item * B<name.in> => I<array[str]>

Only return records where the 'name' field is in the specified values.

=item * B<name.is> => I<str>

Only return records where the 'name' field equals specified value.

=item * B<name.isnt> => I<str>

Only return records where the 'name' field does not equal specified value.

=item * B<name.max> => I<str>

Only return records where the 'name' field is less than or equal to specified value.

=item * B<name.min> => I<str>

Only return records where the 'name' field is greater than or equal to specified value.

=item * B<name.not_contains> => I<str>

Only return records where the 'name' field does not contain specified text.

=item * B<name.not_in> => I<array[str]>

Only return records where the 'name' field is not in the specified values.

=item * B<name.xmax> => I<str>

Only return records where the 'name' field is less than specified value.

=item * B<name.xmin> => I<str>

Only return records where the 'name' field is greater than specified value.

=item * B<notice> => I<str>

Only return records where the 'notice' field equals specified value.

=item * B<notice.contains> => I<str>

Only return records where the 'notice' field contains specified text.

=item * B<notice.in> => I<array[str]>

Only return records where the 'notice' field is in the specified values.

=item * B<notice.is> => I<str>

Only return records where the 'notice' field equals specified value.

=item * B<notice.isnt> => I<str>

Only return records where the 'notice' field does not equal specified value.

=item * B<notice.max> => I<str>

Only return records where the 'notice' field is less than or equal to specified value.

=item * B<notice.min> => I<str>

Only return records where the 'notice' field is greater than or equal to specified value.

=item * B<notice.not_contains> => I<str>

Only return records where the 'notice' field does not contain specified text.

=item * B<notice.not_in> => I<array[str]>

Only return records where the 'notice' field is not in the specified values.

=item * B<notice.xmax> => I<str>

Only return records where the 'notice' field is less than specified value.

=item * B<notice.xmin> => I<str>

Only return records where the 'notice' field is greater than specified value.

=item * B<queries> => I<array[str]>

Search.

This will search all searchable fields with one or more specified queries. Each
query can be in the form of C<-FOO> (dash prefix notation) to require that the
fields do not contain specified string, or C</FOO/> to use regular expression.
All queries must match if the C<query_boolean> option is set to C<and>; only one
query should match if the C<query_boolean> option is set to C<or>.

=item * B<query_boolean> => I<str> (default: "and")

Whether records must match all search queries ('and') or just one ('or').

If set to C<and>, all queries must match; if set to C<or>, only one query should
match. See the C<queries> option for more details on searching.

=item * B<sort> => I<array[str]>

Order records according to certain field(s).

A list of field names separated by comma. Each field can be prefixed with '-' to
specify descending order instead of the default ascending.

=item * B<text> => I<str>

Only return records where the 'text' field equals specified value.

=item * B<text.contains> => I<str>

Only return records where the 'text' field contains specified text.

=item * B<text.in> => I<array[str]>

Only return records where the 'text' field is in the specified values.

=item * B<text.is> => I<str>

Only return records where the 'text' field equals specified value.

=item * B<text.isnt> => I<str>

Only return records where the 'text' field does not equal specified value.

=item * B<text.max> => I<str>

Only return records where the 'text' field is less than or equal to specified value.

=item * B<text.min> => I<str>

Only return records where the 'text' field is greater than or equal to specified value.

=item * B<text.not_contains> => I<str>

Only return records where the 'text' field does not contain specified text.

=item * B<text.not_in> => I<array[str]>

Only return records where the 'text' field is not in the specified values.

=item * B<text.xmax> => I<str>

Only return records where the 'text' field is less than specified value.

=item * B<text.xmin> => I<str>

Only return records where the 'text' field is greater than specified value.

=item * B<url> => I<str>

Only return records where the 'url' field equals specified value.

=item * B<url.contains> => I<str>

Only return records where the 'url' field contains specified text.

=item * B<url.in> => I<array[str]>

Only return records where the 'url' field is in the specified values.

=item * B<url.is> => I<str>

Only return records where the 'url' field equals specified value.

=item * B<url.isnt> => I<str>

Only return records where the 'url' field does not equal specified value.

=item * B<url.max> => I<str>

Only return records where the 'url' field is less than or equal to specified value.

=item * B<url.min> => I<str>

Only return records where the 'url' field is greater than or equal to specified value.

=item * B<url.not_contains> => I<str>

Only return records where the 'url' field does not contain specified text.

=item * B<url.not_in> => I<array[str]>

Only return records where the 'url' field is not in the specified values.

=item * B<url.xmax> => I<str>

Only return records where the 'url' field is less than specified value.

=item * B<url.xmin> => I<str>

Only return records where the 'url' field is greater than specified value.

=item * B<version> => I<str>

Only return records where the 'version' field equals specified value.

=item * B<version.contains> => I<str>

Only return records where the 'version' field contains specified text.

=item * B<version.in> => I<array[str]>

Only return records where the 'version' field is in the specified values.

=item * B<version.is> => I<str>

Only return records where the 'version' field equals specified value.

=item * B<version.isnt> => I<str>

Only return records where the 'version' field does not equal specified value.

=item * B<version.max> => I<str>

Only return records where the 'version' field is less than or equal to specified value.

=item * B<version.min> => I<str>

Only return records where the 'version' field is greater than or equal to specified value.

=item * B<version.not_contains> => I<str>

Only return records where the 'version' field does not contain specified text.

=item * B<version.not_in> => I<array[str]>

Only return records where the 'version' field is not in the specified values.

=item * B<version.xmax> => I<str>

Only return records where the 'version' field is less than specified value.

=item * B<version.xmin> => I<str>

Only return records where the 'version' field is greater than specified value.

=item * B<with.text> => I<bool> (default: 0)

Show field 'with'.

=item * B<with_field_names> => I<bool>

Return field names in each record (as hashE<sol>associative array).

When enabled, function will return each record as hash/associative array
(field name => value pairs). Otherwise, function will return each record
as list/array (field value, field value, ...).


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

Please visit the project's homepage at L<https://metacpan.org/release/App-ListSoftwareLicenses>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-ListSoftwareLicenses>.

=head1 SEE ALSO

L<Software::License>

L<App::Software::License> to print out license text

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTOR

=for stopwords Steven Haryanto

Steven Haryanto <stevenharyanto@gmail.com>

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

This software is copyright (c) 2023, 2015, 2014 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-ListSoftwareLicenses>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
