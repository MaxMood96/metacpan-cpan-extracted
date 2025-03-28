package TableDataRole::Source::DBI;

use 5.010001;
use strict;
use warnings;

use Role::Tiny;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-05-14'; # DATE
our $DIST = 'TableDataRole-Source-DBI'; # DIST
our $VERSION = '0.026'; # VERSION

with 'TableDataRole::Spec::Basic';

sub new {
    my ($class, %args) = @_;

    my $dsn      = delete $args{dsn};
    my $user     = delete $args{user};
    my $password = delete $args{password};
    my $dbh = delete $args{dbh};
    if (defined $dbh) {
    } elsif (defined $dsn) {
        require DBI;
        $dbh = DBI->connect($dsn, $user, $password, {RaiseError=>1});
    }

    my $sth   = delete $args{sth};
    my $sth_bind_params = delete $args{sth_bind_params};
    my $query = delete $args{query};
    my $table = delete $args{table};
    if (defined $sth) {
    } else {
        die "You specify 'query' or 'table', but you don't specify ".
            "dbh/dsn+user+password, so I cannot create a statement handle"
            unless $dbh;
        if (defined $query) {
        } elsif (defined $table) {
            $query = "SELECT * FROM $table";
        } else {
            die "Please specify 'sth', 'query', or 'table' argument";
        }
        $sth = $dbh->prepare($query);
        $sth->execute(@{ $sth_bind_params // [] }); # to check query syntax
    }

    my $row_count_sth = delete $args{row_count_sth};
    my $row_count_sth_bind_params = delete $args{row_count_sth_bind_params};
    my $row_count_query = delete $args{row_count_query};
    if (defined $row_count_sth) {
    } else {
        die "You specify 'row_count_query' or 'table', but you don't specify ".
            "dbh/dsn+user+password, so I cannot create a statement handle"
            unless $dbh;
        if (defined $row_count_query) {
        } elsif (defined $table) {
            $row_count_query = "SELECT COUNT(*) FROM $table";
        } else {
            die "For getting row count, please specify 'row_count_sth', ".
                "'row_count_query', or 'table' argument";
        }
        $row_count_sth = $dbh->prepare($row_count_query);
        $sth->execute(@{ $row_count_sth_bind_params // [] }); # to check query syntax
    }

    die "Unknown argument(s): ". join(", ", sort keys %args)
        if keys %args;

    bless {
        #dbh => $dbh,
        sth => $sth,
        sth_bind_params => $sth_bind_params,
        row_count_sth => $row_count_sth,
        row_count_sth_bind_params => $row_count_sth_bind_params,

        pos => 0,
    }, $class;
}

sub _get_row {
    # get a hashref row from sth, and empty the buffer
    my $self = shift;
    if ($self->{buffer}) {
        my $row = delete $self->{buffer};
        if (!ref($row) && $row == -1) {
            return undef; ## no critic: Subroutines::ProhibitExplicitReturnUndef
        } else {
            return $row;
        }
    } else {
        my $row = $self->{sth}->fetchrow_hashref;
        return undef unless $row; ## no critic: Subroutines::ProhibitExplicitReturnUndef
        return $row;
    }
}

sub _peek_row {
    # get a row from iterator, put it in buffer. will return the existing buffer
    # content if it exists.
    my $self = shift;
    unless ($self->{buffer}) {
        $self->{buffer} = $self->{sth}->fetchrow_hashref // -1;
    }
    if (!ref($self->{buffer}) && $self->{buffer} == -1) {
        return undef; ## no critic: Subroutines::ProhibitExplicitReturnUndef
    } else {
        return $self->{buffer};
    }
}

sub get_column_count {
    my $self = shift;
    $self->{sth}{NUM_OF_FIELDS};
}

sub get_column_names {
    my $self = shift;
    wantarray ? @{ $self->{sth}{NAME_lc} } : $self->{sth}{NAME_lc};
}

sub has_next_item {
    my $self = shift;
    $self->_peek_row ? 1:0;
}

sub get_next_item {
    my $self = shift;
    my $row_hashref = $self->_get_row;
    die "StopIteration" unless $row_hashref;
    $self->{pos}++;
    my $row_aryref = [];
    my $column_names = $self->get_column_names;
    for (0..$#{$column_names}) {
        $row_aryref->[$_] = $row_hashref->{ $column_names->[$_] };
    }
    $row_aryref;
}

sub get_next_row_hashref {
    my $self = shift;
    my $row = $self->_get_row;
    die "StopIteration" unless $row;
    $self->{pos}++;
    $row;
}

sub get_row_count {
    my $self = shift;
    $self->{row_count_sth}->execute(@{ $self->{row_count_sth_bind_params} // [] });
    my ($row_count) = $self->{row_count_sth}->fetchrow_array;
    $row_count;
}

sub reset_iterator {
    my $self = shift;
    $self->{sth}->execute(@{ $self->{sth_bind_params} // [] });
    delete $self->{buffer};
    $self->{pos} = 0;
}

sub get_iterator_pos {
    my $self = shift;
    $self->{pos};
}

1;
# ABSTRACT: Role to access table data from DBI

__END__

=pod

=encoding UTF-8

=head1 NAME

TableDataRole::Source::DBI - Role to access table data from DBI

=head1 VERSION

This document describes version 0.026 of TableDataRole::Source::DBI (from Perl distribution TableDataRole-Source-DBI), released on 2024-05-14.

=head1 DESCRIPTION

This role expects table data in L<DBI> database table.

=for Pod::Coverage ^(.+)$

=head1 ROLES MIXED IN

L<TableDataRole::Spec::Basic>

=head1 METHODS

=head2 new

Usage:

 my $table = $CLASS->new(%args);

Arguments:

=over

=item * sth

=item * dbh

=item * query

=item * table

One of L</sth>, L</dbh>, L</query>, or L</table> is required.

=item * row_count_sth

=item * row_count_query

One of L</row_count_sth>, L</row_count_query>, or L</table> is required. If you
specify C<row_count_query> or C<table>, you need to specify L</dbh> or L</dsn>.

=back

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/TableDataRole-Source-DBI>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-TableDataRole-Source-DBI>.

=head1 SEE ALSO

L<TableDataRole::Source::SQLite>

L<DBI>

L<TableData>

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

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=TableDataRole-Source-DBI>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
