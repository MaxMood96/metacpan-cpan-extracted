package Punk::Observe::Backend::SQLite;

use 5.010;
use strict;
use warnings;

use parent -norequire, 'Punk::Observe::Backend';

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

# WAL mode and foreign keys, both off by default and both wanted.
#
# `foreign_keys` is off in SQLite for backwards compatibility, so every
# REFERENCES clause in the schema is decoration until it is turned on - and a
# panel outliving its dashboard is exactly the kind of thing that then shows
# up as a render failure a long way from the delete that caused it.
#
# WAL mode is what lets the reader drawing a page and the worker running a
# migration coexist. `busy_timeout` is the other half: without it a writer
# holding the lock for ten milliseconds is an immediate SQLITE_BUSY rather
# than a ten-millisecond wait.
sub _on_connect {
    my ($self, $dbh) = @_;
    $dbh->do('PRAGMA foreign_keys = ON');
    $dbh->do('PRAGMA busy_timeout = 5000');
    eval { $dbh->do('PRAGMA journal_mode = WAL'); 1 };   # not on :memory:

    # BEGIN IMMEDIATE THROUGH DBI, NOT AROUND IT.
    #
    # `$dbh->do('BEGIN IMMEDIATE')` while DBI believes AutoCommit is on is the
    # documented way to leave a transaction DBI does not know it has - and a
    # transaction nobody commits is a connection holding the write lock for
    # its whole life. With four workers that is four processes each pinning
    # the database, and every write anywhere answering "database is locked"
    # with nothing visibly contending.
    #
    # This makes begin_work issue BEGIN IMMEDIATE, so the lock discipline
    # below is the one DBI is tracking.
    $dbh->{sqlite_use_immediate_transaction} = 1;
    return;
}

# THE LOCK IS THE TRANSACTION.
#
# SQLite has no advisory lock, so there is nothing to take that is not also
# the write lock itself. BEGIN IMMEDIATE acquires it up front rather than on
# the first write, which is the difference between two workers serialising and
# two workers deadlocking halfway through a migration - the deferred default
# would let both begin, both read version 0, and one fail on upgrade.
#
# `busy_timeout` above is what makes the loser wait rather than fail.
sub _locked {
    my ($self, $code) = @_;
    my $dbh = $self->dbh;

    my $outer = !$dbh->{AutoCommit};       # somebody else owns the transaction
    $dbh->begin_work unless $outer;

    my @r = eval { $code->() };
    if ($@) {
        my $err = $@;
        eval { $dbh->rollback } unless $outer;
        die $err;
    }
    $dbh->commit unless $outer;
    return wantarray ? @r : $r[0];
}

sub _tables {
    my ($self) = @_;
    my $t = $self->dbh->selectcol_arrayref(
        "SELECT name FROM sqlite_master
          WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name");
    return $t || [];
}

1;

__END__

=head1 NAME

Punk::Observe::Backend::SQLite - the default configuration store

=head1 SYNOPSIS

    plugin 'Observe' => {
        guard => 'Web::Auth#observe_admin',
        store => '/var/lib/punk-observe',
        db    => 'dbi:SQLite:dbname=/var/lib/punk-observe/config.db',
    };

=head1 DESCRIPTION

The default. A self-hosted single-node installation is the case this
distribution is built for, and for a few dozen rows of configuration a file
beside the store is the right database - it needs no server, no user, and no
second thing to back up.

L<Punk::Observe::Backend::Pg> is the option for an installation that already
runs PostgreSQL and would rather have one database than two.

=head2 What this turns on

C<foreign_keys>, which SQLite leaves off for compatibility - so without it
every C<REFERENCES> in the schema is decoration, and a panel outliving its
deleted dashboard surfaces as a render failure a long way from the cause.

C<journal_mode = WAL>, so the request drawing a page and the worker running a
migration do not block each other, and C<busy_timeout>, so the one that loses
waits instead of failing.

=head2 The lock is the transaction

SQLite has no advisory lock. C<migrate> therefore takes the write lock itself,
with C<BEGIN IMMEDIATE> rather than the deferred default: deferred would let
two workers both begin, both read version 0, and one fail partway through
applying the same migration. Immediate makes them serialise.

It is taken through C<begin_work>, with
C<sqlite_use_immediate_transaction> set so that C<begin_work> means
C<BEGIN IMMEDIATE>. Issuing the C<BEGIN> as a statement instead leaves a
transaction DBI does not know it has, and a transaction nobody commits is a
connection holding the write lock for the rest of its life - which with four
workers is four processes each pinning the database, and every write anywhere
answering "database is locked" with nothing visibly contending.

If the caller already has a transaction open, this joins it rather than
nesting - SQLite has no nested transactions, and the alternative is a commit
that silently ends somebody else's.

=head1 METHODS

Everything is inherited from L<Punk::Observe::Backend>. This class exists to
say what the dialect needs.

=head1 SEE ALSO

L<Punk::Observe::Backend>

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION.

This is free software, licensed under the Artistic License 2.0.

=cut
