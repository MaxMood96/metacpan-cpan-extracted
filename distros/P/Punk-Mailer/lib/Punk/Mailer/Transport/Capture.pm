package Punk::Mailer::Transport::Capture;

use 5.010001;
use strict;
use warnings;

use Punk::Mailer ();

our $VERSION = '0.05';

1;

__END__

=head1 NAME

Punk::Mailer::Transport::Capture - the capture transport

=head1 DESCRIPTION

See L<Punk::Mailer::Transport/capture> for what it does and its options.
L<Punk::Mailer>'s C<new> constructs it; the methods below are the
transport contract plus what this one adds.

=head2 new(\%options)

=head2 deliver(\%message, \%envelope)

Returns a L<Punk::Mailer::Result>.

=head2 name

C<capture>.

=head2 messages

The captured messages, oldest first: C<< [ { spec, envelope, bytes, result }, ... ] >>.

=head2 clear

Empties C<messages>.

=head2 dir

=head2 last_path

The directory, if one was given, and the file the newest message was written to.

=cut
