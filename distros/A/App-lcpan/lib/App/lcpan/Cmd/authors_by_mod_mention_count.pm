package App::lcpan::Cmd::authors_by_mod_mention_count;

use 5.010;
use strict;
use warnings;

require App::lcpan;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-09-26'; # DATE
our $DIST = 'App-lcpan'; # DIST
our $VERSION = '1.074'; # VERSION

our %SPEC;

$SPEC{'handle_cmd'} = {
    v => 1.1,
    summary => 'List authors ranked by number of module mentions',
    description => <<'_',

This shows the list of most mentioned authors, that is, authors whose modules
are linked/referred to the most in PODs.

By default, each source module/script that mentions a module from author is
counted as one mention (`--count-per content`). Use `--count-per dist` to only
count mentions by modules/scripts from the same dist as one mention (so an
author only gets a maximum of 1 vote per dist). Use `--count-per author` to only
count mentions by modules/scripts from the same author as one mention (so an
author only gets a maximum of 1 vote per mentioning author).

By default, only mentions from other authors are included. Use
`--include-self-mentions` to also include mentions from the same author.

_
    args => {
        %App::lcpan::common_args,
        include_self_mentions => {
            schema => 'bool',
            default => 0,
        },
        count_per => {
            schema => ['str*', in=>['content', 'dist', 'author']],
            default => 'content',
        },
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $count_per = $args{count_per} // 'content';

    my @where = ("author IS NOT NULL");

    push @where, "file.cpanid <> author"
        unless $args{include_self_mentions};

    my $count = '*';
    if ($count_per eq 'dist') {
        $count = 'DISTINCT file.id';
    } elsif ($count_per eq 'author') {
        $count = 'DISTINCT file.cpanid';
    }

    my $sql = "SELECT
  module.cpanid author,
  COUNT($count) AS mod_mention_count
FROM mention
LEFT JOIN file ON mention.source_file_id=file.id
LEFT JOIN module ON module.id=mention.module_id
WHERE ".join(" AND ", @where)."
GROUP BY module.cpanid
ORDER BY mod_mention_count DESC
";

    my @res;
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    while (my $row = $sth->fetchrow_hashref) {
        push @res, $row;
    }

    require Data::TableData::Rank;
    Data::TableData::Rank::add_rank_column_to_table(table => \@res, data_columns => ['mod_mention_count']);

    my $resmeta = {};
    $resmeta->{'table.fields'} = [qw/rank author mod_mention_count/];
    [200, "OK", \@res, $resmeta];
}

1;
# ABSTRACT: List authors ranked by number of module mentions

__END__

=pod

=encoding UTF-8

=head1 NAME

App::lcpan::Cmd::authors_by_mod_mention_count - List authors ranked by number of module mentions

=head1 VERSION

This document describes version 1.074 of App::lcpan::Cmd::authors_by_mod_mention_count (from Perl distribution App-lcpan), released on 2023-09-26.

=head1 FUNCTIONS


=head2 handle_cmd

Usage:

 handle_cmd(%args) -> [$status_code, $reason, $payload, \%result_meta]

List authors ranked by number of module mentions.

This shows the list of most mentioned authors, that is, authors whose modules
are linked/referred to the most in PODs.

By default, each source module/script that mentions a module from author is
counted as one mention (C<--count-per content>). Use C<--count-per dist> to only
count mentions by modules/scripts from the same dist as one mention (so an
author only gets a maximum of 1 vote per dist). Use C<--count-per author> to only
count mentions by modules/scripts from the same author as one mention (so an
author only gets a maximum of 1 vote per mentioning author).

By default, only mentions from other authors are included. Use
C<--include-self-mentions> to also include mentions from the same author.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<count_per> => I<str> (default: "content")

(No description)

=item * B<cpan> => I<dirname>

Location of your local CPAN mirror, e.g. E<sol>pathE<sol>toE<sol>cpan.

Defaults to C<~/cpan>.

=item * B<include_self_mentions> => I<bool> (default: 0)

(No description)

=item * B<index_name> => I<filename> (default: "index.db")

Filename of index.

If C<index_name> is a filename without any path, e.g. C<index.db> then index will
be located in the top-level of C<cpan>. If C<index_name> contains a path, e.g.
C<./index.db> or C</home/ujang/lcpan.db> then the index will be located solely
using the C<index_name>.

=item * B<update_db_schema> => I<bool> (default: 1)

Whether to update database schema to the latest.

By default, when the application starts and reads the index database, it updates
the database schema to the latest if the database happens to be last updated by
an older version of the application and has the old database schema (since
database schema is updated from time to time, for example at 1.070 the database
schema is at version 15).

When you disable this option, the application will not update the database
schema. This option is for testing only, because it will probably cause the
application to run abnormally and then die with a SQL error when reading/writing
to the database.

Note that in certain modes e.g. doing tab completion, the application also will
not update the database schema.

=item * B<use_bootstrap> => I<bool> (default: 1)

Whether to use bootstrap database from App-lcpan-Bootstrap.

If you are indexing your private CPAN-like repository, you want to turn this
off.


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

Please visit the project's homepage at L<https://metacpan.org/release/App-lcpan>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-lcpan>.

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

This software is copyright (c) 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-lcpan>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
