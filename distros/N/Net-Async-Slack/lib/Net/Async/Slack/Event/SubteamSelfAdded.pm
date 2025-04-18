package Net::Async::Slack::Event::SubteamSelfAdded;

use strict;
use warnings;

our $VERSION = '0.015'; # VERSION

use Net::Async::Slack::EventType;

=head1 NAME

Net::Async::Slack::Event::SubteamSelfAdded - You have been added to a User Group

=head1 DESCRIPTION

Example input data:

    usergroups:read

=cut

sub type { 'subteam_self_added' }

1;

__END__

=head1 AUTHOR

Tom Molesworth <TEAM@cpan.org>

=head1 LICENSE

Copyright Tom Molesworth 2016-2024. Licensed under the same terms as Perl itself.
