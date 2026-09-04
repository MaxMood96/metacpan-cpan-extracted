package Punk::Mailer::Transport::Log;

use 5.010001;
use strict;
use warnings;

use Punk::Mailer ();

our $VERSION = '0.06';

1;

__END__

=head1 NAME

Punk::Mailer::Transport::Log - the log transport

=head1 DESCRIPTION

See L<Punk::Mailer::Transport/log> for what it does and its options.
L<Punk::Mailer>'s C<new> constructs it; the methods below are the
transport contract plus what this one adds.

=head2 new(\%options)

=head2 deliver(\%message, \%envelope)

Returns a L<Punk::Mailer::Result>.

=head2 name

C<log>.

=cut
