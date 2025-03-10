package App::ProcUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-11-15'; # DATE
our $DIST = 'App-ProcUtils'; # DIST
our $VERSION = '0.039'; # VERSION

our %SPEC;

our %args_filtering = (
    cmdline_match => {
        schema => 're*',
        tags => ['category:filtering'],
        pos => 0,
    },
    cmdline_not_match => {
        schema => 're*',
        tags => ['category:filtering'],
    },
    exec_match => {
        schema => 're*',
        tags => ['category:filtering'],
    },
    exec_not_match => {
        schema => 're*',
        tags => ['category:filtering'],
    },
    pids => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'pid',
        schema => ['array*', of=>'unix::pid*'],
        tags => ['category:filtering'],
    },
    uids => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'uid',
        schema => ['array*', of=>'unix::uid::exists*'],
        tags => ['category:filtering'],
    },
    logic => {
        schema => ['str*', in=>['AND','OR']],
        default => 'AND',
        cmdline_aliases => {
            and => {is_flag=>0, summary=>'Shortcut for --logic=AND', code=>sub {$_[0]{logic} = 'AND' }},
            or  => {is_flag=>0, summary=>'Shortcut for --logic=OR' , code=>sub {$_[0]{logic} = 'OR'  }},
        },
        tags => ['category:filtering'],
    },
    code => {
        schema => 'code*',
        description => <<'MARKDOWN',

Code is given <pm:Proc::ProcessTable::Process> object, which is a hashref
containing items like `pid`, `uid`, etc. It should return true to mean that a
process matches.

MARKDOWN
        tags => ['category:filtering'],
    },
);

our %arg_detail = (
    detail => {
        summary => 'Return detailed records instead of just PIDs',
        schema => 'true',
        cmdline_aliases=>{l=>{}},
    },
);

our %arg_quiet = (
    quiet => {
        schema => 'true',
        cmdline_aliases=>{q=>{}},
    },
);

our @proc_fields = (
    # follows the order of 'ps aux'
    "uid",
    "pid",
    "pctcpu",
    "pctmem",
    "size",
    "rss",
    "ttydev",
    "ttynum",
    "state",
    "start",
    "time",
    "cmndline",

    "cmajflt",
    "cminflt",
    "cstime",
    "ctime",
    "cutime",
    "cwd",
    "egid",
    "euid",
    "exec",
    "fgid",
    "flags",
    "fname",
    "fuid",
    "gid",
    "majflt",
    "minflt",
    "pgrp",
    "ppid",
    "priority",
    "sess",
    "sgid",
    "stime",
    "suid",
    "utime",
    "wchan",

    # not included
    # environ
);

sub _proc_obj_to_hash {
    my $row = {%{$_[0]}};
    $row->{cmdline} = join(" ", grep {$_ ne ''} @{ $row->{cmdline} });
    delete $row->{environ};
    $row;
}

$SPEC{list_parents} = {
    v => 1.1,
    summary => 'List all the parents of the current process',
};
sub list_parents {
    require Proc::Find::Parents;
    [200, "OK", Proc::Find::Parents::get_parent_processes(
        $$, {method=>'proctable'})];
}

$SPEC{table} = {
    v => 1.1,
    summary => 'Run Proc::ProcessTable and display the result',
};
sub table {
    require Proc::ProcessTable;

    my $t = Proc::ProcessTable->new;

    my $resmeta = {};
    $resmeta->{'table.fields'} = \@proc_fields;

    my @rows;
    for my $p (@{ $t->table }) {
        my $row = _proc_obj_to_hash($p);
        push @rows, $row;
    }

    [200, "OK", \@rows, $resmeta];
}

sub _kill_or_list {
    require Proc::ProcessTable;
    require String::Elide::Tiny;

    my $which = shift;
    my %args = @_;

    my $is_or = ($args{logic} // 'AND') eq 'OR' ? 1:0;
    my $proc_table = Proc::ProcessTable->new;

    my @proc_matches;
  ENTRY:
    for my $proc_entry (@{ $proc_table->table }) {
        my $cmdline = join(" ", grep {$_ ne ''} @{ $proc_entry->{cmdline} });
        my $exec = $proc_entry->{exec} // '';

        if (defined $args{cmdline_match}) {
            if ($cmdline =~ /$args{cmdline_match}/) {
                goto MATCH if $is_or;
            } else {
                next ENTRY unless $is_or;
            }
        }
        if (defined $args{cmdline_not_match}) {
            if ($cmdline !~ /$args{cmdline_not_match}/) {
                goto MATCH if $is_or;
            } else {
                next ENTRY unless $is_or;
            }
        }
        if (defined $args{exec_match}) {
            if ($exec =~ /$args{exec_match}/) {
                goto MATCH if $is_or;
            } else {
                next ENTRY unless $is_or;
            }
        }
        if (defined $args{exec_not_match}) {
            if ($exec !~ /$args{exec_not_match}/) {
                goto MATCH if $is_or;
            } else {
                next ENTRY unless $is_or;
            }
        }
        if (defined $args{pids}) {
            if (grep {$proc_entry->{pid} == $_} @{ $args{pids} }) {
                goto MATCH if $is_or;
            } else {
                next ENTRY unless $is_or;
            }
        }
        if (defined $args{uids}) {
            if (grep {$proc_entry->{uid} == $_} @{ $args{uids} }) {
                goto MATCH if $is_or;
            } else {
                next ENTRY unless $is_or;
            }
        }
        if (defined $args{code}) {
            if ($args{code}->($proc_entry)) {
                goto MATCH if $is_or;
            } else {
                next ENTRY unless $is_or;
            }
        }

        if ($proc_entry->{pid} == $$) {
            log_info "Not killing ourself, skipping PID $$";
            next ENTRY;
        }

      MATCH:
        if ($which eq 'kill') {
            if ($args{-dry_run}) {
                log_info "[DRY-RUN] Sending %s signal to PID %d (%s) ...",
                    $args{signal}, $proc_entry->{pid}, elide($cmdline, 40, {truncate=>'middle'});
            } else {
                kill $args{signal} => $proc_entry->{pid};
            }
        } else {
            push @proc_matches, _proc_obj_to_hash($proc_entry);
        }
    } # for each entry

    if ($which eq 'kill') {
        return [200, "OK"];
    } else {
        my $resmeta = {};
        if ($args{detail}) {
            $resmeta->{'table.fields'} = \@proc_fields;
        } else {
            @proc_matches = map { $_->{pid} } @proc_matches;
        }
        return [200, "OK", \@proc_matches, $resmeta];
    }
}

$SPEC{kill} = {
    v => 1.1,
    summary => 'Kill processes that match criteria',
    args => {
        signal => {
            schema => 'unix::signal*',
            default => 'TERM',
        },
        %args_filtering,
    },
    features => {
        dry_run => 1,
    },
};
sub kill {
    _kill_or_list('kill', @_);
}

$SPEC{list} = {
    v => 1.1,
    summary => 'List processes that match criteria',
    args => {
        %args_filtering,
        %arg_detail,
    },
};
sub list {
    _kill_or_list('list', @_);
}

$SPEC{exists} = {
    v => 1.1,
    summary => 'Check if processes that match criteria exists',
    args => {
        %args_filtering,
        %arg_quiet,
    },
};
sub exists {
    my %args = @_;
    my $quiet = delete $args{quiet};
    my $res = &list(%args);
    return $res unless $res->[0] == 200;
    if (@{ $res->[2] }) {
        return [200, "OK", 1, {
            'cmdline.result' => $quiet ? "" : "Processes that match criteria exist",
            'cmdline.exit_code' => 0,
        }];
    } else {
        return [200, "OK", 0, {
            'cmdline.result' => $quiet ? "" : "Processes that match criteria DO NOT exist",
            'cmdline.exit_code' => 1,
        }];
    }
}

1;
# ABSTRACT: Command line utilities related to processes

__END__

=pod

=encoding UTF-8

=head1 NAME

App::ProcUtils - Command line utilities related to processes

=head1 VERSION

This document describes version 0.039 of App::ProcUtils (from Perl distribution App-ProcUtils), released on 2024-11-15.

=head1 SYNOPSIS

This distribution provides the following command-line utilities:

=over

=item * L<proc-exists>

=item * L<proc-kill>

=item * L<proc-list>

=item * L<proc-list-parents>

=item * L<proc-table>

=back

=head1 FUNCTIONS


=head2 exists

Usage:

 exists(%args) -> [$status_code, $reason, $payload, \%result_meta]

Check if processes that match criteria exists.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<cmdline_match> => I<re>

(No description)

=item * B<cmdline_not_match> => I<re>

(No description)

=item * B<code> => I<code>

Code is given L<Proc::ProcessTable::Process> object, which is a hashref
containing items like C<pid>, C<uid>, etc. It should return true to mean that a
process matches.

=item * B<exec_match> => I<re>

(No description)

=item * B<exec_not_match> => I<re>

(No description)

=item * B<logic> => I<str> (default: "AND")

(No description)

=item * B<pids> => I<array[unix::pid]>

(No description)

=item * B<quiet> => I<true>

(No description)

=item * B<uids> => I<array[unix::uid::exists]>

(No description)


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 kill

Usage:

 kill(%args) -> [$status_code, $reason, $payload, \%result_meta]

Kill processes that match criteria.

This function is not exported.

This function supports dry-run operation.


Arguments ('*' denotes required arguments):

=over 4

=item * B<cmdline_match> => I<re>

(No description)

=item * B<cmdline_not_match> => I<re>

(No description)

=item * B<code> => I<code>

Code is given L<Proc::ProcessTable::Process> object, which is a hashref
containing items like C<pid>, C<uid>, etc. It should return true to mean that a
process matches.

=item * B<exec_match> => I<re>

(No description)

=item * B<exec_not_match> => I<re>

(No description)

=item * B<logic> => I<str> (default: "AND")

(No description)

=item * B<pids> => I<array[unix::pid]>

(No description)

=item * B<signal> => I<unix::signal> (default: "TERM")

(No description)

=item * B<uids> => I<array[unix::uid::exists]>

(No description)


=back

Special arguments:

=over 4

=item * B<-dry_run> => I<bool>

Pass -dry_run=E<gt>1 to enable simulation mode.

=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 list

Usage:

 list(%args) -> [$status_code, $reason, $payload, \%result_meta]

List processes that match criteria.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<cmdline_match> => I<re>

(No description)

=item * B<cmdline_not_match> => I<re>

(No description)

=item * B<code> => I<code>

Code is given L<Proc::ProcessTable::Process> object, which is a hashref
containing items like C<pid>, C<uid>, etc. It should return true to mean that a
process matches.

=item * B<detail> => I<true>

Return detailed records instead of just PIDs.

=item * B<exec_match> => I<re>

(No description)

=item * B<exec_not_match> => I<re>

(No description)

=item * B<logic> => I<str> (default: "AND")

(No description)

=item * B<pids> => I<array[unix::pid]>

(No description)

=item * B<uids> => I<array[unix::uid::exists]>

(No description)


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 list_parents

Usage:

 list_parents() -> [$status_code, $reason, $payload, \%result_meta]

List all the parents of the current process.

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



=head2 table

Usage:

 table() -> [$status_code, $reason, $payload, \%result_meta]

Run Proc::ProcessTable and display the result.

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

Please visit the project's homepage at L<https://metacpan.org/release/App-ProcUtils>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-ProcUtils>.

=head1 SEE ALSO

L<Proc::Find> is a similar module; App::ProcUtils provides the CLI scripts as
well as function interface.

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

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-ProcUtils>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
