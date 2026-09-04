package Punk::Mailer::Result;

use 5.010001;
use strict;
use warnings;

use Punk::Mailer ();

our $VERSION = '0.06';

1;

__END__

=head1 NAME

Punk::Mailer::Result - what a delivery attempt came to

=head1 SYNOPSIS

    my $r = $mailer->send(\%message);

    if    ($r->accepted)  { log_id($r->id) }
    elsif ($r->retryable) { die "try again: " . $r->message }   # deferred or failed
    else                  { give_up($r->message) }              # rejected

=head1 DESCRIPTION

Delivery never throws. A refused connection, a server's C<5xx>, a pipe
that exited, a provider's C<429> - each is a Result, so the code that
asked decides what to do, and a job body decides whether to retry.

There is no boolean overload, deliberately. C<unless ($r)> means "there
is no result", never "it was rejected"; ask C<accepted> when that is the
question.

=head1 STATUS

C<status> is one word:

=over 4

=item C<accepted>

The other side took responsibility for the message: SMTP C<250> after
C<DATA>, a provider's C<2xx>, a sendmail that exited C<0>.

=item C<deferred>

Temporarily refused, and worth retrying later: SMTP C<4xx>, a provider's
C<429> or C<5xx>.

=item C<rejected>

Refused, and a retry will be refused the same way: SMTP C<5xx>, a
provider's other C<4xx>, a message over a transport's limit.

=item C<failed>

No verdict at all: the connection was refused or lost, the TLS handshake
failed, the command could not be run. Usually worth retrying.

=item C<unsent>

The log transport: recorded, not delivered, by configuration.

=back

=head1 METHODS

=head2 status

The word above.

=head2 accepted

=head2 deferred

=head2 rejected

=head2 failed

=head2 unsent

True when C<status> is that word.

=head2 retryable

True for C<deferred> and C<failed>: the thing a job asks before it dies
to be retried.

=head2 code

The SMTP reply code or the HTTP status; a sendmail exit status; C<undef>
when there was no conversation.

=head2 enhanced

The SMTP enhanced status code (C<5.7.1>) when the server sent one, else
C<undef>.

=head2 message

What the server, provider or transport said - one line, suitable for a
log.

=head2 id

The provider's id for the message, or the C<Message-ID> the message
carries for transports that have no id of their own; C<undef> on a
failure.

=head2 transport

The short name of the transport that produced this Result.

=head2 recipients

    { 'a@example.com' => { code => 250, message => 'ok' }, ... }

Per-recipient verdicts, for transports that give one (SMTP). A message
some of whose recipients were refused while at least one was accepted
is C<accepted> with the refusals recorded here, which is what the
server did.

=head1 SEE ALSO

L<Punk::Mailer>.

=cut
