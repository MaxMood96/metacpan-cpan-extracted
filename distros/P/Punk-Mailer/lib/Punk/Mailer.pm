package Punk::Mailer;

use 5.010001;
use strict;
use warnings;

our $VERSION = '0.05';

require XSLoader;
XSLoader::load('Punk::Mailer', $VERSION);

1;

__END__

=head1 NAME

Punk::Mailer - outbound mail: messages, MIME, and the transports that carry them

=head1 VERSION

Version 0.05

=head1 SYNOPSIS

    use Punk::Mailer;

    my $bytes = Punk::Mailer->build({
        from    => 'Example <ops@example.com>',
        to      => [ 'alice@example.com', 'Bob <bob@example.com>' ],
        subject => 'Your invoice',
        text    => "Attached.\n",
        html    => "<p>Attached.</p>",
        attachments => [
            { path => '/var/store/inv-42.pdf', filename => 'invoice.pdf',
              type => 'application/pdf' },
        ],
    });

=head1 DESCRIPTION

A message is a plain hashref, and C<build> turns it into RFC 5322 bytes:
the headers, a C<multipart/alternative> when there is both text and HTML,
a C<multipart/mixed> around that when there are attachments, each part
encoded as its content requires. The result is 7-bit clean whatever was
put in, so the same bytes can go to any server.

The rules that matter are enforced here and nowhere else: a header value
may not contain a line break, so a caller cannot inject one; an address
must be an address; a display name or subject with characters outside
ASCII is encoded so that it survives; and an attachment named by path is
read in chunks and never held in memory.

Sending is L<Punk::Mailer::Transport> territory; L<Punk::Plugin::Mailer>
wires both into a Punk application.

=head1 THE MESSAGE

    {
        from     => 'Name <addr>',                  # required; exactly one
        to       => 'addr' | 'Name <addr>' | [ ... ],
        cc       => ...,                            # at least one of to, cc, bcc
        bcc      => ...,                            # envelope only; never a header
        reply_to => ...,
        subject  => 'any text',                     # required
        text     => "a plain body",                 # text and/or html
        html     => "<p>an HTML body</p>",
        headers  => { 'List-Unsubscribe' => '<...>' },
        attachments => [
            { path => '/file', filename => 'name.pdf', type => 'application/pdf' },
            { content => $bytes, filename => 'name.csv', type => 'text/csv' },
            $upload,        # anything with path, filename and type methods
        ],
        message_id        => '<...>',     # generated when absent
        message_id_domain => 'example.com',   # the From domain when absent
        date              => $epoch,      # now when absent
    }

A key not in that list is an error: a misspelt option that silently did
nothing is worse than one that stops the program.

=head2 Addresses

C<addr>, C<Name E<lt>addrE<gt>> and C<"Quoted Name" E<lt>addrE<gt>>, one
or a list of them. The address itself must be ASCII with exactly one C<@>
and something on each side of it; the display name may be anything and
is encoded (RFC 2047) when it needs to be, or quoted when it contains
characters that would otherwise be read as structure.

=head2 Headers

Every header value is refused if it contains a carriage return, a line
feed or a NUL. That is the rule that stops a form field from becoming a
second header, and it applies to addresses, the subject, and the
C<headers> hash alike. Long headers fold at whitespace to 78 columns.
C<Date>, C<Message-ID>, C<MIME-Version>, the C<Content-*> headers and the
address headers are generated and may not be supplied through C<headers>.

=head2 Encoding

A text part is sent as C<7bit> when it is ASCII with lines under 998
bytes, C<quoted-printable> when it is mostly ASCII, and C<base64>
otherwise. Attachments are always C<base64>, in 76-column lines. The
charset is always C<utf-8>; a string with perl's UTF-8 flag off is
treated as perl would treat it.

=head2 Attachments

C<path> is read in chunks as the message is built; a 100MB attachment
costs a small buffer, not 100MB. C<content> is bytes already in memory.
An object with C<path>, C<filename> and C<type> methods - a
L<Punk::Upload> - is accepted directly. C<filename> is required and is
only ever a header value: nothing here opens it.

=head1 SENDING

    my $mailer = Punk::Mailer->new(
        transport => 'smtp',                   # smtp, resend, sendmail, capture, log
        from      => 'Example <ops@example.com>',
        reply_to  => 'help@example.com',
        message_id_domain => 'example.com',
        smtp      => { host => 'mail.example.com', username => ..., password => ... },
    );

    my $result = $mailer->send(\%message);
    $result->accepted or warn $result->message;

=head2 new(%options)

Builds the transport and checks every option of every layer, so a typo,
a missing credential or a command given as a string is a croak here
rather than a surprise at the first send. Options:

=over 4

=item C<transport>

Required. One of C<smtp>, C<resend>, C<sendmail>, C<capture>, C<log>,
or a class name containing C<::> - see L<Punk::Mailer::Transport>.

=item C<from>, C<reply_to>, C<message_id_domain>

Defaults for messages that leave them out. C<from> and C<reply_to> must
be addresses.

=item C<smtp>, C<resend>, C<sendmail>, C<capture>, C<log>

A hashref of options for the transport of that name; C<options> for a
class. An option the transport does not know croaks.

=back

=head2 send(\%message)

Fills in the defaults, validates the message - a malformed one croaks,
because it is a programming error - and hands it to the transport.
Returns a L<Punk::Mailer::Result>, whatever happened on the wire:
delivery never throws.

=head2 transport

The transport object C<new> built.

=head2 transport_name

The name it was asked for by.

=head2 from

=head2 reply_to

=head2 message_id_domain

The defaults C<new> was given, or C<undef>.

=head1 METHODS

=head2 build(\%message)

The message as bytes: headers, a blank line, the body, CRLF throughout.

=head2 build_to(\%message, sub { ... })

The same bytes handed to a callback in chunks as they are produced, for
a caller that wants to stream them somewhere rather than hold them.

=head2 envelope(\%message)

    { from => 'ops@example.com', to => [ 'alice@example.com', ... ] }

The bare addresses a transport needs: the sender, and every recipient
across C<to>, C<cc> and C<bcc>, in that order, each once.

=head1 SEE ALSO

L<Punk::Plugin::Mailer>, L<Punk>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
