package Net::Async::Slack::Event::FileChange;

use strict;
use warnings;

our $VERSION = '0.015'; # VERSION

use Net::Async::Slack::EventType;

=head1 NAME

Net::Async::Slack::Event::FileChange - A file was changed

=head1 DESCRIPTION

Example input data:

    files:read

=cut

sub type { 'file_change' }

1;

__END__

=head1 AUTHOR

Tom Molesworth <TEAM@cpan.org>

=head1 LICENSE

Copyright Tom Molesworth 2016-2024. Licensed under the same terms as Perl itself.
