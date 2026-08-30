package Punk::Mailer::Transport::SMTP;

use 5.010001;
use strict;
use warnings;

use Punk::Mailer ();

our $VERSION = '0.05';

1;

__END__

=head1 NAME

Punk::Mailer::Transport::SMTP - the smtp transport

=head1 DESCRIPTION

See L<Punk::Mailer::Transport/smtp> for what it does and its options.
L<Punk::Mailer>'s C<new> constructs it; the methods below are the
transport contract plus what this one adds.

=head2 new(\%options)

=head2 deliver(\%message, \%envelope)

Returns a L<Punk::Mailer::Result>.

=head2 name

C<smtp>.

=head2 host

=head2 port

=head2 tls

=head2 verify

=head2 timeout

=head2 username

What the transport was built with. The password is not reachable once given.

=cut
