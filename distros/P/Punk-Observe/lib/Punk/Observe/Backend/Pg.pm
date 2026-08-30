package Punk::Observe::Backend::Pg;

use 5.010;
use strict;
use warnings;

use parent -norequire, 'Punk::Observe::Backend';

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

# The key for pg_advisory_lock. Chosen once and written down rather than
# hashed at runtime: a key that varies with a Perl version, or with hash
# randomisation, is a lock two processes do not share.
#
# IT FITS A 32-BIT IV, deliberately. `pg_advisory_lock` takes a bigint and the
# obvious thing is to use the range - but several supported perls have a
# 32-bit IV, where a 17-digit constant becomes an NV and reaches DBI as a
# float. The lock would then be taken on a different key, or on none, on
# exactly the platforms nobody tests interactively.
use constant MIGRATE_LOCK => 1_953_657_198;    # "po" in the low bytes

# AN ADVISORY LOCK, NOT A TABLE LOCK.
#
# PostgreSQL has a real one, so unlike SQLite there is no need to make the
# transaction do double duty. `pg_advisory_lock` blocks until it is granted
# and is held until unlocked or the session ends - so a worker killed mid
# migration releases it by disconnecting, rather than leaving a row behind
# that the next boot has to reason about.
#
# Session-scoped rather than transaction-scoped, deliberately: the migration
# runs several statements and PostgreSQL is happy to run DDL inside a
# transaction, but the caller may already own one and
# `pg_advisory_xact_lock` would then release at their commit rather than ours.
sub _locked {
    my ($self, $code) = @_;
    my $dbh = $self->dbh;

    $dbh->do('SELECT pg_advisory_lock(?)', undef, MIGRATE_LOCK);
    my @r = eval { $code->() };
    my $err = $@;
    # Released whatever happened. A lock leaked here is a boot that hangs
    # forever the next time, which is a worse failure than the one that
    # caused it.
    eval { $dbh->do('SELECT pg_advisory_unlock(?)', undef, MIGRATE_LOCK) };
    die $err if $err;
    return wantarray ? @r : $r[0];
}

1;

__END__

=head1 NAME

Punk::Observe::Backend::Pg - configuration in PostgreSQL

=head1 SYNOPSIS

    plugin 'Observe' => {
        guard => 'Web::Auth#observe_admin',
        store => '/var/lib/punk-observe',
        db    => 'dbi:Pg:dbname=observe;host=db.internal',
    };

=head1 DESCRIPTION

For an installation that already runs PostgreSQL and would rather have one
database than two. L<Punk::Observe::Backend::SQLite> is the default, and is
the better answer for a single node.

Requires L<DBD::Pg>, which this distribution does not depend on - it is loaded
only when a C<dbi:Pg:> dsn asks for it, so an installation using the default
never needs it installed.

=head2 The lock is advisory

PostgreSQL has a real advisory lock, so C<migrate> takes one rather than
making the transaction do double duty as SQLite must. It is session-scoped
rather than transaction-scoped on purpose: the caller may already own a
transaction, and C<pg_advisory_xact_lock> would then release at their commit
rather than at the end of the migration.

It is released whatever happens, including on failure. A leaked lock here is a
boot that hangs forever next time, which is worse than whatever caused it.

=head1 METHODS

Everything is inherited from L<Punk::Observe::Backend>. This class exists to
say what the dialect needs.

=head2 MIGRATE_LOCK

The advisory lock key, a constant so that two processes agree on it without
coordinating. It fits a 32-bit IV deliberately: C<pg_advisory_lock> takes a
bigint, but several supported perls have a 32-bit IV where a larger constant
becomes an NV and reaches DBI as a float - taking the lock on a different key,
on exactly the platforms nobody tests interactively.

=head1 SEE ALSO

L<Punk::Observe::Backend>

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION.

This is free software, licensed under the Artistic License 2.0.

=cut
