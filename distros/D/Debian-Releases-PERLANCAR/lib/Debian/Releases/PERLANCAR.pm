package Debian::Releases::PERLANCAR;

use 5.010001;
use strict;
use warnings;

use Exporter 'import';
use Perinci::Sub::Gen::AccessTable qw(gen_read_table_func);

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-07-13'; # DATE
our $DIST = 'Debian-Releases-PERLANCAR'; # DIST
our $VERSION = '20230713.0'; # VERSION

our @EXPORT_OK = qw(
                       list_debian_releases
               );

our %SPEC;

our $meta = {
    summary => 'List of Debian releases',
    fields => {
        version         => { pos => 0, schema => "str*", sortable => 1, summary => "Version", unique => 1 },
        code_name       => { pos => 1, schema => "str*", sortable => 1, summary => "Code name", unique => 1 },
        reldate         => { pos => 2, schema => "date*", sortable => 1, summary => "Release date" },
        eoldate         => { pos => 3, schema => "date*", sortable => 1, summary => "Supported until" },

        linux_version   => {pos=> 4, schema=>'str*'},

        mysql_version        => {pos=> 5, schema=>'str*'},
        mariadb_version      => {pos=> 6, schema=>'str*'},
        postgresql_version   => {pos=> 7, schema=>'str*'},
        apache_httpd_version => {pos=> 8, schema=>'str*'},
        nginx_version        => {pos=> 9, schema=>'str*'},

        perl_version         => {pos=>10, schema=>'str*'},
        python_version       => {pos=>11, schema=>'str*'},
        php_version          => {pos=>12, schema=>'str*'},
        ruby_version         => {pos=>13, schema=>'str*'},
        bash_version         => {pos=>14, schema=>'str*'},
    },
    pk => "version",
};

our $data = do {
    no warnings 'void';
    [];
 [
   {
     apache_httpd_version => "--",
     bash_version         => "1.14.6",
     code_name            => "buzz",
     eoldate              => undef,
     linux_version        => "2.0.0",
     mariadb_version      => "--",
     mysql_version        => "--",
     nginx_version        => undef,
     perl_version         => 5.2,
     php_version          => "--",
     postgresql_version   => "--",
     python_version       => 1.3,
     reldate              => "1996-06-17",
     ruby_version         => undef,
     version              => 1.1,
   },
   {
     apache_httpd_version => "--",
     bash_version         => "1.14.7",
     code_name            => "rex",
     eoldate              => undef,
     linux_version        => "2.0.27",
     mariadb_version      => "--",
     mysql_version        => "--",
     nginx_version        => undef,
     perl_version         => "5.3.7",
     php_version          => "--",
     postgresql_version   => "--",
     python_version       => "1.4.0",
     reldate              => "1996-12-12",
     ruby_version         => undef,
     version              => 1.2,
   },
   {
     apache_httpd_version => "--",
     bash_version         => "2.0",
     code_name            => "bo",
     eoldate              => undef,
     linux_version        => "2.0.29",
     mariadb_version      => "--",
     mysql_version        => "--",
     nginx_version        => undef,
     perl_version         => "5.3.7",
     php_version          => "2.0b10",
     postgresql_version   => "--",
     python_version       => "1.4.0",
     reldate              => "1997-06-05",
     ruby_version         => undef,
     version              => 1.3,
   },
   {
     apache_httpd_version => "--",
     bash_version         => "--",
     code_name            => "hamm",
     eoldate              => undef,
     linux_version        => "2.0.34",
     mariadb_version      => "--",
     mysql_version        => "3.21.31",
     nginx_version        => undef,
     perl_version         => "5.4.4",
     php_version          => "3.0",
     postgresql_version   => "6.3.2",
     python_version       => "1.5.1",
     reldate              => "1998-07-23",
     ruby_version         => undef,
     version              => "2.0",
   },
   {
     apache_httpd_version => "--",
     bash_version         => "--",
     code_name            => "slink",
     eoldate              => undef,
     linux_version        => "2.0.36",
     mariadb_version      => "--",
     mysql_version        => "3.21.33b",
     nginx_version        => undef,
     perl_version         => "5.4.4",
     php_version          => "3.0.5",
     postgresql_version   => "6.3.2",
     python_version       => "1.5.1",
     reldate              => "1999-03-09",
     ruby_version         => undef,
     version              => 2.1,
   },
   {
     apache_httpd_version => "--",
     bash_version         => 2.03,
     code_name            => "potato",
     eoldate              => undef,
     linux_version        => "2.2.16",
     mariadb_version      => "--",
     mysql_version        => "3.22.32",
     nginx_version        => undef,
     perl_version         => "5.4.5",
     php_version          => "4.0.3pl1",
     postgresql_version   => "6.5.3",
     python_version       => "1.5.2",
     reldate              => "2000-08-15",
     ruby_version         => undef,
     version              => 2.2,
   },
   {
     apache_httpd_version => "--",
     bash_version         => "2.05a",
     code_name            => "woody",
     eoldate              => undef,
     linux_version        => "2.2.20",
     mariadb_version      => "--",
     mysql_version        => "3.23.49",
     nginx_version        => undef,
     perl_version         => "5.6.1",
     php_version          => "4.1.2",
     postgresql_version   => "7.2.1",
     python_version       => "2.1.3",
     reldate              => "2002-07-19",
     ruby_version         => undef,
     version              => "3.0",
   },
   {
     apache_httpd_version => "2.0.54",
     bash_version         => "2.05b",
     code_name            => "sarge",
     eoldate              => undef,
     linux_version        => "2.4.27",
     mariadb_version      => "--",
     mysql_version        => "4.0.24",
     nginx_version        => undef,
     perl_version         => "5.8.4",
     php_version          => "4.3.10",
     postgresql_version   => "7.4.7",
     python_version       => "2.3.5",
     reldate              => "2005-06-06",
     ruby_version         => undef,
     version              => 3.1,
   },
   {
     apache_httpd_version => "2.2.3",
     bash_version         => 3.1,
     code_name            => "etch",
     eoldate              => undef,
     linux_version        => "2.6.18",
     mariadb_version      => "--",
     mysql_version        => "5.0.32",
     nginx_version        => undef,
     perl_version         => "5.8.8",
     php_version          => "5.2.0",
     postgresql_version   => "8.1.8",
     python_version       => "2.4.4",
     reldate              => "2007-04-08",
     ruby_version         => undef,
     version              => "4.0",
   },
   {
     apache_httpd_version => "2.2.9",
     bash_version         => 3.2,
     code_name            => "lenny",
     eoldate              => undef,
     linux_version        => "2.6.26",
     mariadb_version      => "--",
     mysql_version        => "5.0.51a",
     nginx_version        => undef,
     perl_version         => "5.10.0",
     php_version          => "5.2.6",
     postgresql_version   => "8.3.6",
     python_version       => "2.5.2",
     reldate              => "2009-02-15",
     ruby_version         => undef,
     version              => "5.0",
   },
   {
     apache_httpd_version => "2.2.16",
     bash_version         => 4.1,
     code_name            => "squeeze",
     eoldate              => "2016-02",
     linux_version        => "2.6.32",
     mariadb_version      => "--",
     mysql_version        => "5.1.49",
     nginx_version        => undef,
     perl_version         => "5.10.1",
     php_version          => "5.3.3",
     postgresql_version   => "8.4.5",
     python_version       => "2.6.6",
     reldate              => "2011-02-06",
     ruby_version         => undef,
     version              => "6.0",
   },
   {
     apache_httpd_version => "2.2.22",
     bash_version         => 4.2,
     code_name            => "wheezy",
     eoldate              => "2018-05",
     linux_version        => "3.2.41",
     mariadb_version      => "--",
     mysql_version        => "5.5.30",
     nginx_version        => undef,
     perl_version         => "5.14.2",
     php_version          => "5.4.4",
     postgresql_version   => "9.1.9",
     python_version       => "2.7.3",
     reldate              => "2013-05-04",
     ruby_version         => undef,
     version              => "7.0",
   },
   {
     apache_httpd_version => "2.4.10",
     bash_version         => 4.3,
     code_name            => "jessie",
     eoldate              => "2020-07",
     linux_version        => "3.16.7",
     mariadb_version      => "10.0.16",
     mysql_version        => "5.5.43",
     nginx_version        => undef,
     perl_version         => "5.20.2",
     php_version          => "5.6.7",
     postgresql_version   => "9.4.1",
     python_version       => "2.7.9",
     reldate              => "2015-04-26",
     ruby_version         => undef,
     version              => "8.0",
   },
   {
     apache_httpd_version => "2.4.25",
     bash_version         => 4.4,
     code_name            => "stretch",
     eoldate              => undef,
     linux_version        => "4.9.30",
     mariadb_version      => "10.1.23",
     mysql_version        => "--",
     nginx_version        => undef,
     perl_version         => "5.24.1",
     php_version          => "7.0.19",
     postgresql_version   => "9.6.3",
     python_version       => "2.7.13",
     reldate              => "2017-06-18",
     ruby_version         => undef,
     version              => 9,
   },
   {
     apache_httpd_version => "2.4.38",
     bash_version         => "5.0",
     code_name            => "buster",
     eoldate              => undef,
     linux_version        => "4.19.37",
     mariadb_version      => "10.3.15",
     mysql_version        => "--",
     nginx_version        => undef,
     perl_version         => "5.28.1",
     php_version          => "7.3.4",
     postgresql_version   => 11.4,
     python_version       => "3.7.3",
     reldate              => "2019-07-06",
     ruby_version         => undef,
     version              => 10,
   },
   {
     apache_httpd_version => "2.4.48",
     bash_version         => 5.1,
     code_name            => "bullseye",
     eoldate              => undef,
     linux_version        => "5.10.46",
     mariadb_version      => "10.5.11",
     mysql_version        => "--",
     nginx_version        => undef,
     perl_version         => "5.32.1",
     php_version          => "7.4.21",
     postgresql_version   => 13.3,
     python_version       => "3.9.2",
     reldate              => "2021-08-14",
     ruby_version         => undef,
     version              => 11,
   },
   {
     apache_httpd_version => "2.4.57",
     bash_version         => "5.2.15",
     code_name            => "bookworm",
     eoldate              => undef,
     linux_version        => "6.1.27",
     mariadb_version      => "10.11.3",
     mysql_version        => "--",
     nginx_version        => undef,
     perl_version         => "5.36.0",
     php_version          => "8.2.5",
     postgresql_version   => 15.3,
     python_version       => "3.11.2",
     reldate              => "2023-06-10",
     ruby_version         => undef,
     version              => 12,
   },
 ]
};

my $res = gen_read_table_func(
    name => 'list_debian_releases',
    table_data => $data,
    table_spec => $meta,
    #langs => ['en_US', 'id_ID'],
);
die "BUG: Can't generate func: $res->[0] - $res->[1]" unless $res->[0] == 200;

1;
# ABSTRACT: List Debian releases

__END__

=pod

=encoding UTF-8

=head1 NAME

Debian::Releases::PERLANCAR - List Debian releases

=head1 VERSION

This document describes version 20230713.0 of Debian::Releases::PERLANCAR (from Perl distribution Debian-Releases-PERLANCAR), released on 2023-07-13.

=head1 SYNOPSIS

 use Debian::Releases::PERLANCAR;
 my $res = list_debian_releases(detail=>1);
 # raw data is in $Debian::Releases::PERLANCAR::data;

=head1 DESCRIPTION

This module contains list of Debian releases. It is an alternative to the
no-longer-updated L<Debian::Releases> (last released in 2011). This module
contains extra data as well.

=head1 FUNCTIONS


=head2 list_debian_releases

Usage:

 list_debian_releases(%args) -> [$status_code, $reason, $payload, \%result_meta]

List of Debian releases.

REPLACE ME

This function is not exported by default, but exportable.

Arguments ('*' denotes required arguments):

=over 4

=item * B<apache_httpd_version> => I<str>

Only return records where the 'apache_httpd_version' field equals specified value.

=item * B<apache_httpd_version.contains> => I<str>

Only return records where the 'apache_httpd_version' field contains specified text.

=item * B<apache_httpd_version.in> => I<array[str]>

Only return records where the 'apache_httpd_version' field is in the specified values.

=item * B<apache_httpd_version.is> => I<str>

Only return records where the 'apache_httpd_version' field equals specified value.

=item * B<apache_httpd_version.isnt> => I<str>

Only return records where the 'apache_httpd_version' field does not equal specified value.

=item * B<apache_httpd_version.max> => I<str>

Only return records where the 'apache_httpd_version' field is less than or equal to specified value.

=item * B<apache_httpd_version.min> => I<str>

Only return records where the 'apache_httpd_version' field is greater than or equal to specified value.

=item * B<apache_httpd_version.not_contains> => I<str>

Only return records where the 'apache_httpd_version' field does not contain specified text.

=item * B<apache_httpd_version.not_in> => I<array[str]>

Only return records where the 'apache_httpd_version' field is not in the specified values.

=item * B<apache_httpd_version.xmax> => I<str>

Only return records where the 'apache_httpd_version' field is less than specified value.

=item * B<apache_httpd_version.xmin> => I<str>

Only return records where the 'apache_httpd_version' field is greater than specified value.

=item * B<bash_version> => I<str>

Only return records where the 'bash_version' field equals specified value.

=item * B<bash_version.contains> => I<str>

Only return records where the 'bash_version' field contains specified text.

=item * B<bash_version.in> => I<array[str]>

Only return records where the 'bash_version' field is in the specified values.

=item * B<bash_version.is> => I<str>

Only return records where the 'bash_version' field equals specified value.

=item * B<bash_version.isnt> => I<str>

Only return records where the 'bash_version' field does not equal specified value.

=item * B<bash_version.max> => I<str>

Only return records where the 'bash_version' field is less than or equal to specified value.

=item * B<bash_version.min> => I<str>

Only return records where the 'bash_version' field is greater than or equal to specified value.

=item * B<bash_version.not_contains> => I<str>

Only return records where the 'bash_version' field does not contain specified text.

=item * B<bash_version.not_in> => I<array[str]>

Only return records where the 'bash_version' field is not in the specified values.

=item * B<bash_version.xmax> => I<str>

Only return records where the 'bash_version' field is less than specified value.

=item * B<bash_version.xmin> => I<str>

Only return records where the 'bash_version' field is greater than specified value.

=item * B<code_name> => I<str>

Only return records where the 'code_name' field equals specified value.

=item * B<code_name.contains> => I<str>

Only return records where the 'code_name' field contains specified text.

=item * B<code_name.in> => I<array[str]>

Only return records where the 'code_name' field is in the specified values.

=item * B<code_name.is> => I<str>

Only return records where the 'code_name' field equals specified value.

=item * B<code_name.isnt> => I<str>

Only return records where the 'code_name' field does not equal specified value.

=item * B<code_name.max> => I<str>

Only return records where the 'code_name' field is less than or equal to specified value.

=item * B<code_name.min> => I<str>

Only return records where the 'code_name' field is greater than or equal to specified value.

=item * B<code_name.not_contains> => I<str>

Only return records where the 'code_name' field does not contain specified text.

=item * B<code_name.not_in> => I<array[str]>

Only return records where the 'code_name' field is not in the specified values.

=item * B<code_name.xmax> => I<str>

Only return records where the 'code_name' field is less than specified value.

=item * B<code_name.xmin> => I<str>

Only return records where the 'code_name' field is greater than specified value.

=item * B<detail> => I<bool> (default: 0)

Return array of full records instead of just ID fields.

By default, only the key (ID) field is returned per result entry.

=item * B<eoldate> => I<date>

Only return records where the 'eoldate' field equals specified value.

=item * B<eoldate.in> => I<array[date]>

Only return records where the 'eoldate' field is in the specified values.

=item * B<eoldate.is> => I<date>

Only return records where the 'eoldate' field equals specified value.

=item * B<eoldate.isnt> => I<date>

Only return records where the 'eoldate' field does not equal specified value.

=item * B<eoldate.max> => I<date>

Only return records where the 'eoldate' field is less than or equal to specified value.

=item * B<eoldate.min> => I<date>

Only return records where the 'eoldate' field is greater than or equal to specified value.

=item * B<eoldate.not_in> => I<array[date]>

Only return records where the 'eoldate' field is not in the specified values.

=item * B<eoldate.xmax> => I<date>

Only return records where the 'eoldate' field is less than specified value.

=item * B<eoldate.xmin> => I<date>

Only return records where the 'eoldate' field is greater than specified value.

=item * B<exclude_fields> => I<array[str]>

Select fields to return.

=item * B<fields> => I<array[str]>

Select fields to return.

=item * B<linux_version> => I<str>

Only return records where the 'linux_version' field equals specified value.

=item * B<linux_version.contains> => I<str>

Only return records where the 'linux_version' field contains specified text.

=item * B<linux_version.in> => I<array[str]>

Only return records where the 'linux_version' field is in the specified values.

=item * B<linux_version.is> => I<str>

Only return records where the 'linux_version' field equals specified value.

=item * B<linux_version.isnt> => I<str>

Only return records where the 'linux_version' field does not equal specified value.

=item * B<linux_version.max> => I<str>

Only return records where the 'linux_version' field is less than or equal to specified value.

=item * B<linux_version.min> => I<str>

Only return records where the 'linux_version' field is greater than or equal to specified value.

=item * B<linux_version.not_contains> => I<str>

Only return records where the 'linux_version' field does not contain specified text.

=item * B<linux_version.not_in> => I<array[str]>

Only return records where the 'linux_version' field is not in the specified values.

=item * B<linux_version.xmax> => I<str>

Only return records where the 'linux_version' field is less than specified value.

=item * B<linux_version.xmin> => I<str>

Only return records where the 'linux_version' field is greater than specified value.

=item * B<mariadb_version> => I<str>

Only return records where the 'mariadb_version' field equals specified value.

=item * B<mariadb_version.contains> => I<str>

Only return records where the 'mariadb_version' field contains specified text.

=item * B<mariadb_version.in> => I<array[str]>

Only return records where the 'mariadb_version' field is in the specified values.

=item * B<mariadb_version.is> => I<str>

Only return records where the 'mariadb_version' field equals specified value.

=item * B<mariadb_version.isnt> => I<str>

Only return records where the 'mariadb_version' field does not equal specified value.

=item * B<mariadb_version.max> => I<str>

Only return records where the 'mariadb_version' field is less than or equal to specified value.

=item * B<mariadb_version.min> => I<str>

Only return records where the 'mariadb_version' field is greater than or equal to specified value.

=item * B<mariadb_version.not_contains> => I<str>

Only return records where the 'mariadb_version' field does not contain specified text.

=item * B<mariadb_version.not_in> => I<array[str]>

Only return records where the 'mariadb_version' field is not in the specified values.

=item * B<mariadb_version.xmax> => I<str>

Only return records where the 'mariadb_version' field is less than specified value.

=item * B<mariadb_version.xmin> => I<str>

Only return records where the 'mariadb_version' field is greater than specified value.

=item * B<mysql_version> => I<str>

Only return records where the 'mysql_version' field equals specified value.

=item * B<mysql_version.contains> => I<str>

Only return records where the 'mysql_version' field contains specified text.

=item * B<mysql_version.in> => I<array[str]>

Only return records where the 'mysql_version' field is in the specified values.

=item * B<mysql_version.is> => I<str>

Only return records where the 'mysql_version' field equals specified value.

=item * B<mysql_version.isnt> => I<str>

Only return records where the 'mysql_version' field does not equal specified value.

=item * B<mysql_version.max> => I<str>

Only return records where the 'mysql_version' field is less than or equal to specified value.

=item * B<mysql_version.min> => I<str>

Only return records where the 'mysql_version' field is greater than or equal to specified value.

=item * B<mysql_version.not_contains> => I<str>

Only return records where the 'mysql_version' field does not contain specified text.

=item * B<mysql_version.not_in> => I<array[str]>

Only return records where the 'mysql_version' field is not in the specified values.

=item * B<mysql_version.xmax> => I<str>

Only return records where the 'mysql_version' field is less than specified value.

=item * B<mysql_version.xmin> => I<str>

Only return records where the 'mysql_version' field is greater than specified value.

=item * B<nginx_version> => I<str>

Only return records where the 'nginx_version' field equals specified value.

=item * B<nginx_version.contains> => I<str>

Only return records where the 'nginx_version' field contains specified text.

=item * B<nginx_version.in> => I<array[str]>

Only return records where the 'nginx_version' field is in the specified values.

=item * B<nginx_version.is> => I<str>

Only return records where the 'nginx_version' field equals specified value.

=item * B<nginx_version.isnt> => I<str>

Only return records where the 'nginx_version' field does not equal specified value.

=item * B<nginx_version.max> => I<str>

Only return records where the 'nginx_version' field is less than or equal to specified value.

=item * B<nginx_version.min> => I<str>

Only return records where the 'nginx_version' field is greater than or equal to specified value.

=item * B<nginx_version.not_contains> => I<str>

Only return records where the 'nginx_version' field does not contain specified text.

=item * B<nginx_version.not_in> => I<array[str]>

Only return records where the 'nginx_version' field is not in the specified values.

=item * B<nginx_version.xmax> => I<str>

Only return records where the 'nginx_version' field is less than specified value.

=item * B<nginx_version.xmin> => I<str>

Only return records where the 'nginx_version' field is greater than specified value.

=item * B<perl_version> => I<str>

Only return records where the 'perl_version' field equals specified value.

=item * B<perl_version.contains> => I<str>

Only return records where the 'perl_version' field contains specified text.

=item * B<perl_version.in> => I<array[str]>

Only return records where the 'perl_version' field is in the specified values.

=item * B<perl_version.is> => I<str>

Only return records where the 'perl_version' field equals specified value.

=item * B<perl_version.isnt> => I<str>

Only return records where the 'perl_version' field does not equal specified value.

=item * B<perl_version.max> => I<str>

Only return records where the 'perl_version' field is less than or equal to specified value.

=item * B<perl_version.min> => I<str>

Only return records where the 'perl_version' field is greater than or equal to specified value.

=item * B<perl_version.not_contains> => I<str>

Only return records where the 'perl_version' field does not contain specified text.

=item * B<perl_version.not_in> => I<array[str]>

Only return records where the 'perl_version' field is not in the specified values.

=item * B<perl_version.xmax> => I<str>

Only return records where the 'perl_version' field is less than specified value.

=item * B<perl_version.xmin> => I<str>

Only return records where the 'perl_version' field is greater than specified value.

=item * B<php_version> => I<str>

Only return records where the 'php_version' field equals specified value.

=item * B<php_version.contains> => I<str>

Only return records where the 'php_version' field contains specified text.

=item * B<php_version.in> => I<array[str]>

Only return records where the 'php_version' field is in the specified values.

=item * B<php_version.is> => I<str>

Only return records where the 'php_version' field equals specified value.

=item * B<php_version.isnt> => I<str>

Only return records where the 'php_version' field does not equal specified value.

=item * B<php_version.max> => I<str>

Only return records where the 'php_version' field is less than or equal to specified value.

=item * B<php_version.min> => I<str>

Only return records where the 'php_version' field is greater than or equal to specified value.

=item * B<php_version.not_contains> => I<str>

Only return records where the 'php_version' field does not contain specified text.

=item * B<php_version.not_in> => I<array[str]>

Only return records where the 'php_version' field is not in the specified values.

=item * B<php_version.xmax> => I<str>

Only return records where the 'php_version' field is less than specified value.

=item * B<php_version.xmin> => I<str>

Only return records where the 'php_version' field is greater than specified value.

=item * B<postgresql_version> => I<str>

Only return records where the 'postgresql_version' field equals specified value.

=item * B<postgresql_version.contains> => I<str>

Only return records where the 'postgresql_version' field contains specified text.

=item * B<postgresql_version.in> => I<array[str]>

Only return records where the 'postgresql_version' field is in the specified values.

=item * B<postgresql_version.is> => I<str>

Only return records where the 'postgresql_version' field equals specified value.

=item * B<postgresql_version.isnt> => I<str>

Only return records where the 'postgresql_version' field does not equal specified value.

=item * B<postgresql_version.max> => I<str>

Only return records where the 'postgresql_version' field is less than or equal to specified value.

=item * B<postgresql_version.min> => I<str>

Only return records where the 'postgresql_version' field is greater than or equal to specified value.

=item * B<postgresql_version.not_contains> => I<str>

Only return records where the 'postgresql_version' field does not contain specified text.

=item * B<postgresql_version.not_in> => I<array[str]>

Only return records where the 'postgresql_version' field is not in the specified values.

=item * B<postgresql_version.xmax> => I<str>

Only return records where the 'postgresql_version' field is less than specified value.

=item * B<postgresql_version.xmin> => I<str>

Only return records where the 'postgresql_version' field is greater than specified value.

=item * B<python_version> => I<str>

Only return records where the 'python_version' field equals specified value.

=item * B<python_version.contains> => I<str>

Only return records where the 'python_version' field contains specified text.

=item * B<python_version.in> => I<array[str]>

Only return records where the 'python_version' field is in the specified values.

=item * B<python_version.is> => I<str>

Only return records where the 'python_version' field equals specified value.

=item * B<python_version.isnt> => I<str>

Only return records where the 'python_version' field does not equal specified value.

=item * B<python_version.max> => I<str>

Only return records where the 'python_version' field is less than or equal to specified value.

=item * B<python_version.min> => I<str>

Only return records where the 'python_version' field is greater than or equal to specified value.

=item * B<python_version.not_contains> => I<str>

Only return records where the 'python_version' field does not contain specified text.

=item * B<python_version.not_in> => I<array[str]>

Only return records where the 'python_version' field is not in the specified values.

=item * B<python_version.xmax> => I<str>

Only return records where the 'python_version' field is less than specified value.

=item * B<python_version.xmin> => I<str>

Only return records where the 'python_version' field is greater than specified value.

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

=item * B<random> => I<bool> (default: 0)

Return records in random order.

=item * B<reldate> => I<date>

Only return records where the 'reldate' field equals specified value.

=item * B<reldate.in> => I<array[date]>

Only return records where the 'reldate' field is in the specified values.

=item * B<reldate.is> => I<date>

Only return records where the 'reldate' field equals specified value.

=item * B<reldate.isnt> => I<date>

Only return records where the 'reldate' field does not equal specified value.

=item * B<reldate.max> => I<date>

Only return records where the 'reldate' field is less than or equal to specified value.

=item * B<reldate.min> => I<date>

Only return records where the 'reldate' field is greater than or equal to specified value.

=item * B<reldate.not_in> => I<array[date]>

Only return records where the 'reldate' field is not in the specified values.

=item * B<reldate.xmax> => I<date>

Only return records where the 'reldate' field is less than specified value.

=item * B<reldate.xmin> => I<date>

Only return records where the 'reldate' field is greater than specified value.

=item * B<result_limit> => I<int>

Only return a certain number of records.

=item * B<result_start> => I<int> (default: 1)

Only return starting from the n'th record.

=item * B<ruby_version> => I<str>

Only return records where the 'ruby_version' field equals specified value.

=item * B<ruby_version.contains> => I<str>

Only return records where the 'ruby_version' field contains specified text.

=item * B<ruby_version.in> => I<array[str]>

Only return records where the 'ruby_version' field is in the specified values.

=item * B<ruby_version.is> => I<str>

Only return records where the 'ruby_version' field equals specified value.

=item * B<ruby_version.isnt> => I<str>

Only return records where the 'ruby_version' field does not equal specified value.

=item * B<ruby_version.max> => I<str>

Only return records where the 'ruby_version' field is less than or equal to specified value.

=item * B<ruby_version.min> => I<str>

Only return records where the 'ruby_version' field is greater than or equal to specified value.

=item * B<ruby_version.not_contains> => I<str>

Only return records where the 'ruby_version' field does not contain specified text.

=item * B<ruby_version.not_in> => I<array[str]>

Only return records where the 'ruby_version' field is not in the specified values.

=item * B<ruby_version.xmax> => I<str>

Only return records where the 'ruby_version' field is less than specified value.

=item * B<ruby_version.xmin> => I<str>

Only return records where the 'ruby_version' field is greater than specified value.

=item * B<sort> => I<array[str]>

Order records according to certain field(s).

A list of field names separated by comma. Each field can be prefixed with '-' to
specify descending order instead of the default ascending.

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

Please visit the project's homepage at L<https://metacpan.org/release/Debian-Releases-PERLANCAR>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Debian-Releases-PERLANCAR>.

=head1 SEE ALSO

L<Ubuntu::Releases>

L<Debian::Releases>

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

This software is copyright (c) 2023, 2022, 2020, 2019, 2017, 2015 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Debian-Releases-PERLANCAR>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
