package Git::Raw::Odb::Backend::Pack;
$Git::Raw::Odb::Backend::Pack::VERSION = '0.90';
use strict;
use warnings;

use Git::Raw;

=head1 NAME

Git::Raw::Odb::Backend::Pack - Git packed object database backend class

=head1 VERSION

version 0.90

=head1 DESCRIPTION

A L<Git::Raw::Odb::Backend::Pack> represents a git packed object database backend.

B<WARNING>: The API of this module is unstable and may change without warning
(any change will be appropriately documented in the changelog).

=head1 METHODS

=head2 new( $directory )

Create a backend for the packfiles.

=head1 AUTHOR

Jacques Germishuys <jacquesg@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2016 Jacques Germishuys.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of Git::Raw::Odb::Backend::Pack
