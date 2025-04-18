use strict; use warnings;

package DBIx::Connector::Driver::MSSQL;

use DBIx::Connector::Driver;

our $VERSION = '0.60';
our @ISA = qw( DBIx::Connector::Driver );

sub savepoint {
    my ($self, $dbh, $name) = @_;
    $dbh->do("SAVE TRANSACTION $name");
}

# MSSQL automatically releases a savepoint when you start another one with the
# same name.
sub release { 1 }

sub rollback_to {
    my ($self, $dbh, $name) = @_;
    $dbh->do("ROLLBACK TRANSACTION $name");
}

1;

__END__

=head1 NAME

DBIx::Connector::Driver::MSSQL - Microsoft SQL Server-specific connection interface

=head1 DESCRIPTION

This subclass of L<DBIx::Connector::Driver|DBIx::Connector::Driver> provides
Microsoft SQL server-specific implementations of the following methods:

=over

=item C<savepoint>

=item C<release>

=item C<rollback_to>

=back

=head1 AUTHORS

This module was written by:

=over

=item David E. Wheeler <david@kineticode.com>

=back

It is based on code written by:

=over

=item Matt S. Trout <mst@shadowcatsystems.co.uk>

=item Peter Rabbitson <rabbit+dbic@rabbit.us>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009-2013 David E. Wheeler. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
