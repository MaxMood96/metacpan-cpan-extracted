package Punk::Mailer::Job;

use 5.010001;
use strict;
use warnings;
use Punk::Mailer ();

our $VERSION = '0.05';

1;

__END__

=head1 NAME

Punk::Mailer::Job - the queue task behind C<mail_later>

=head1 DESCRIPTION

The body L<Punk::Plugin::Mailer> declares as the C<later> task. See
L<Punk::Plugin::Mailer/later>.

=head2 send($job, $class, \%message)

Finds the L<Punk::Mailer> the application class registered and sends
the message: an C<accepted> Result is the job's result; C<deferred> and
C<failed> die so the queue retries; C<rejected> notes C<final> on the
job and dies.

=cut
