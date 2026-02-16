package WWW::Suffit::Server::ServerInfo;
use strict;
use warnings;
use utf8;

=encoding utf8

=head1 NAME

WWW::Suffit::Server::ServerInfo - The Mojolicious ServerInfo controller for the suffit projects

=head1 DESCRIPTION

The Mojolicious ServerInfo controller for the suffit projects

=head1 METHODS

API methods

=head2 info

The route to show server information

=head1 SEE ALSO

L<WWW::Suffit::Plugin::ServerInfo>

=head1 AUTHOR

Serż Minus (Sergey Lepenkov) L<https://www.serzik.com> E<lt>abalama@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2026 D&D Corporation

=head1 LICENSE

This program is distributed under the terms of the Artistic License Version 2.0

See the C<LICENSE> file or L<https://opensource.org/license/artistic-2-0> for details

=cut

use Mojo::Base 'Mojolicious::Controller';

our $VERSION = '1.02';

sub info { shift->serverinfo }

1;

__END__
