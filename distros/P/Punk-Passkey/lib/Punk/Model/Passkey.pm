package Punk::Model::Passkey;

use 5.010;
use strict;
use warnings;
use Punk::Model;

our $VERSION = '0.02';

# The credentials table, for an application that has not declared a model of
# its own. Registered by Punk::Plugin::Passkey under this full class name,
# which Punk takes as a class rather than as a name in the application's
# namespace.
#
# Every column has to be declared or it can never be written: the DBI backend
# writes only declared fields.

table 'passkeys';

field id            => { type => 'integer', primary => 1 };
field user_id       => { type => 'integer' };
field credential_id => { type => 'string' };

# No type: the column holds the COSE key exactly as the authenticator sent
# it, as bytes, and those bytes are not text. Nothing here needs to
# constrain them - the algorithm allowlist is applied to the key itself on
# every login, when it is re-imported, which is the check that matters.
field public_key    => {};

field sign_count    => { type => 'integer' };
field transports    => { type => 'string' };   # space separated
field aaguid        => { type => 'string' };
field label         => { type => 'string' };
field created_at    => { type => 'integer' };  # epoch
field last_used_at  => { type => 'integer' };  # epoch; null never used

1;

__END__

=head1 NAME

Punk::Model::Passkey - the credentials table

=head1 DESCRIPTION

The model L<Punk::Plugin::Passkey> falls back to when the application has
declared none of its own. See L<Punk::Passkey/"The credential table"> for
the Sqitch project that deploys it.

One row is one credential, not one user: a passkey user is expected to have
several - a phone, a laptop, a hardware key - and C<credential_id> is unique
across the whole table rather than per user, because the spec requires
refusing a credential already registered to somebody else.

An application that wants its own - a different table name, an extra column,
different spellings - declares C<MyApp::Model::Passkey> and this class is
never registered.

=head1 SEE ALSO

L<Punk::Plugin::Passkey>, L<Punk::Model>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
