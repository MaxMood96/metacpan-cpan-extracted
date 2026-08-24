package Punk::Mailer::Transport::Resend;

use 5.016;
use strict;
use warnings;

use Punk::Mailer ();

our $VERSION = '0.03';

1;

__END__

=head1 NAME

Punk::Mailer::Transport::Resend - the resend transport

=head1 DESCRIPTION

See L<Punk::Mailer::Transport/resend> for what it does and its options.
L<Punk::Mailer>'s C<new> constructs it; the methods below are the
transport contract plus what this one adds.

=head2 new(\%options)

=head2 deliver(\%message, \%envelope)

Returns a L<Punk::Mailer::Result>.

=head2 name

C<resend>.

=head2 url

=head2 timeout

=head2 max_attachment

What the transport was built with.

=cut
