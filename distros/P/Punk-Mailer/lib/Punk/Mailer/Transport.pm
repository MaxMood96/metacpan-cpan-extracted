package Punk::Mailer::Transport;

use 5.016;
use strict;
use warnings;

use Punk::Mailer ();

our $VERSION = '0.02';

1;

__END__

=head1 NAME

Punk::Mailer::Transport - the transports, and what one has to be

=head1 SYNOPSIS

    Punk::Mailer->new(transport => 'smtp',     smtp     => { host => 'mail.example.com', ... });
    Punk::Mailer->new(transport => 'resend',   resend   => { api_key => $key });
    Punk::Mailer->new(transport => 'sendmail', sendmail => { command => [ '/usr/sbin/sendmail', '-i' ] });
    Punk::Mailer->new(transport => 'capture',  capture  => { dir => 'var/mail' });
    Punk::Mailer->new(transport => 'log');
    Punk::Mailer->new(transport => 'My::Transport', options => { ... });

=head1 DESCRIPTION

A transport takes a message and its envelope and returns a
L<Punk::Mailer::Result>. The engine builds one at C<new>, which is where
every option is checked - an unknown option, a missing credential, a
command given as a string - so nothing is deferred to the first send.

=head1 THE SHIPPED TRANSPORTS

=head2 capture

    capture => { dir => 'var/mail', result => 'accepted' }

For tests and development. Every delivery is kept on C<messages> as
C<< { spec, envelope, bytes, result } >>, so a test reads what would have
gone out; C<clear> empties it. With C<dir>, each message is also written
as one C<< <epoch>.<seq>.<pid>.eml >> under C<dir/new/>, which a mail
client can open. C<result> scripts the verdict - C<accepted>,
C<deferred>, C<rejected> or C<failed> - so a test can exercise its
error branch without a server.

=head2 log

    log => { to => $fh | \&code }

The honest fallback: the message goes to C<STDERR> (or C<to>) and the
Result is C<unsent>. It exists so a development box says
C<< transport => 'log' >> and sees the mail, rather than having no
transport and wondering where it went.

=head2 sendmail

    sendmail => { command => [ '/usr/sbin/sendmail', '-i' ] }

A local MTA's command line. C<command> is a list of arguments and is
run without a shell; a string croaks at C<new>. C<-f> with the envelope
sender and then the envelope recipients are appended, so C<bcc> works
without C<-t>. The message streams straight into the command's standard
input. A non-zero exit is a C<failed> Result carrying the exit status;
C<127> means the command was not found.

The default command is C<< ['/usr/sbin/sendmail', '-i'] >>. Keep the
C<-i> in your own: without it a line holding a single C<.> ends the
message for most sendmails.

=head2 resend

    resend => { api_key => $key, timeout => 10, max_attachment => 8 * 1024 * 1024 }

L<Resend|https://resend.com>'s HTTP API, one JSON POST per message.
C<2xx> is C<accepted> with Resend's id; C<429> and C<5xx> are
C<deferred>; any other C<4xx> is C<rejected> with Resend's message; no
answer is C<failed>. An attachment is sent as one base64 string, which
is the one place a file named by C<path> is read into memory, so
C<max_attachment> (default 8MB) refuses a larger one locally as
C<rejected> rather than uploading it. C<url> points the transport
elsewhere, for a proxy or a test.

=head2 smtp

    smtp => {
        host     => 'mail.example.com',
        port     => 587,                 # the default for the tls mode
        tls      => 'starttls',          # starttls | implicit | none
        verify   => 1,
        timeout  => 15,
        username => 'ops@example.com',
        password => $password,
        name     => 'app.example.com',   # the EHLO name; the From domain by default
    };

RFC 5321, with STARTTLS on 587, implicit TLS on 465, or plaintext on 25.
TLS comes from L<Fetch>'s client configuration, so the system's
certificate store applies and C<verify> (on by default) checks the
server's certificate and hostname. C<timeout> bounds every read and
write on the connection.

The client asks for STARTTLS only after the greeting, upgrades only on
a C<220>, and sends C<EHLO> again afterwards - the capabilities a server
announced in plaintext are not trusted. A server that does not offer
STARTTLS when C<tls> is C<starttls> is a C<failed> Result, never a
silent plaintext session.

C<AUTH PLAIN> is used when offered, C<AUTH LOGIN> otherwise. A password
is never sent over plaintext: C<tls => 'none'> with a C<username> croaks
at C<new> unless C<insecure_auth => 1> is also given, which is a way of
saying so in writing.

When the server announces C<SIZE>, the message's size is sent with
C<MAIL FROM> - known from arithmetic, without reading an attachment -
and a message already over the limit is C<rejected> locally with
C<552>. The message itself streams from the builder onto the socket,
dot-stuffed, so an attachment never sits in memory.

The Result: the C<250> after C<DATA> is C<accepted>, with the server's
text (usually a queue id) in C<message>; a C<4xx> anywhere is
C<deferred>; a C<5xx> is C<rejected>; a lost connection, a timeout, a
failed handshake or an unparseable reply is C<failed>, and the message
names the phase - C<greeting>, C<ehlo>, C<starttls>, C<auth>, C<mail>,
C<rcpt>, C<data>. Every recipient's verdict is in C<recipients>; a
message some of whose recipients were refused while at least one was
accepted is C<accepted> with the refusals recorded, which is what the
server did. The C<enhanced> status code is kept when the server sent
one.

=head1 WRITING ONE

    package My::Transport;
    sub new     { my ($class, $opts) = @_; ... bless {...}, $class }
    sub deliver { my ($self, $spec, $envelope) = @_; ... return $result }
    sub name    { 'mine' }

C<deliver> receives the message hashref with the engine's defaults
filled in and already validated, and the envelope
C<< { from => $addr, to => [ @addrs ] } >>. It must return a
L<Punk::Mailer::Result>; build the bytes with
C<< Punk::Mailer->build($spec) >> or stream them with C<build_to>.
Return a Result for anything that went wrong on the wire, and die only
for a bug.

=head1 SEE ALSO

L<Punk::Mailer>, L<Punk::Mailer::Result>.

=cut
