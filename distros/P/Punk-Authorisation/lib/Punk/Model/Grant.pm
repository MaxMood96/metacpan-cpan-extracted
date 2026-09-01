package Punk::Model::Grant;

use 5.010;
use strict;
use warnings;
use Punk::Model;

our $VERSION = '0.01';

table 'authz_grants';

field id         => { type => 'integer', primary => 1 };
field subject_id => { type => 'integer', required => 1 };
field action     => { type => 'string',  required => 1 };
field object_id  => { type => 'string',  required => 1 };
field granted_by => { type => 'integer' };
field created    => { type => 'integer' };

1;

__END__

=head1 NAME

Punk::Model::Grant - the grants table L<Punk::Plugin::Authorisation> reads

=head1 DESCRIPTION

Shipped for the application that turns grants on without a model of its
own: C<< plugin 'Authorisation' => { grants => 'Grant' } >> uses
C<< <AppClass>::Model::Grant >> when it exists and this one otherwise.

One row is one grant - subject, action, object - and the unique index over
the three is what makes granting twice a no-op rather than two rows.
C<object_id> is text because the objects an application names are not all
one table nor all one key type; the rule that reads it knows what it
means.

With Punk-Sqitch the table is the C<punk_authz> project. The DDL, for an
application that manages its schema another way:

    CREATE TABLE authz_grants (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id  INTEGER NOT NULL,
        action      TEXT    NOT NULL,
        object_id   TEXT    NOT NULL,
        granted_by  INTEGER,
        created     INTEGER
    );
    CREATE UNIQUE INDEX authz_grants_one ON authz_grants (subject_id, action, object_id);
    CREATE INDEX authz_grants_object ON authz_grants (action, object_id);

=head1 SEE ALSO

L<Punk::Plugin::Authorisation>, L<Punk::Model>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
