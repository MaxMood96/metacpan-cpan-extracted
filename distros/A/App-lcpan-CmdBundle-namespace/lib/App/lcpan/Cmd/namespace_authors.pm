package App::lcpan::Cmd::namespace_authors;

use 5.010001;
use strict;
use warnings;

require App::lcpan;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-01-09'; # DATE
our $DIST = 'App-lcpan-CmdBundle-namespace'; # DIST
our $VERSION = '0.001'; # VERSION

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => "Given a namespace, list authors in that namespace sorted by module count",
    args => {
        %App::lcpan::common_args,
        namespace => {
            schema => ['perl::modname*'],
            req => 1,
            pos => 0,
            completion => \&App::lcpan::_complete_ns,
        },
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $sth = $dbh->prepare("SELECT num_modules FROM namespace WHERE name=?");
    $sth->execute($args{namespace});
    my $row = $sth->fetchrow_arrayref or return [404, "No such namespace"];
    my $num_modules = $row->[0];
    return [200, "OK", []] unless $num_modules;

    $sth = $dbh->prepare("SELECT cpanid AS author,COUNT(*) AS num_modules, 100.0*COUNT(*)/$num_modules AS pct_modules FROM module WHERE name LIKE '$args{namespace}\::%' GROUP BY cpanid ORDER BY num_modules DESC");
    $sth->execute;

    my @rows;
    while (my $row = $sth->fetchrow_hashref) { $row->{pct_modules} = sprintf "%.2f", $row->{pct_modules}; push @rows, $row }

    [200, "OK", \@rows];
}

1;
# ABSTRACT: Given a namespace, list authors in that namespace sorted by module count

__END__

=pod

=encoding UTF-8

=head1 NAME

App::lcpan::Cmd::namespace_authors - Given a namespace, list authors in that namespace sorted by module count

=head1 VERSION

This document describes version 0.001 of App::lcpan::Cmd::namespace_authors (from Perl distribution App-lcpan-CmdBundle-namespace), released on 2024-01-09.

=head1 DESCRIPTION

This module handles the L<lcpan> subcommand C<namespace-authors>.

=head1 FUNCTIONS


=head2 handle_cmd

Usage:

 handle_cmd(%args) -> [$status_code, $reason, $payload, \%result_meta]

Given a namespace, list authors in that namespace sorted by module count.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<cpan> => I<dirname>

Location of your local CPAN mirror, e.g. E<sol>pathE<sol>toE<sol>cpan.

Defaults to C<~/cpan>.

=item * B<index_name> => I<filename> (default: "index.db")

Filename of index.

If C<index_name> is a filename without any path, e.g. C<index.db> then index will
be located in the top-level of C<cpan>. If C<index_name> contains a path, e.g.
C<./index.db> or C</home/ujang/lcpan.db> then the index will be located solely
using the C<index_name>.

=item * B<namespace>* => I<perl::modname>

(No description)

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

Please visit the project's homepage at L<https://metacpan.org/release/App-lcpan-CmdBundle-namespace>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-lcpan-CmdBundle-namespace>.

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

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-lcpan-CmdBundle-namespace>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
