package Sisimai::Lhost::MessagingServer;
use parent 'Sisimai::Lhost';
use v5.26;
use strict;
use warnings;

sub description { 'Oracle Communications Messaging Server: https://docs.oracle.com/en/industries/communications/messaging-server/index.html' }
sub inquire {
    # Detect an error from Oracle Communications Messaging Server
    # @param    [Hash] mhead    Message headers of a bounce email
    # @param    [String] mbody  Message body of a bounce email
    # @return   [Hash]          Bounce data list and message/rfc822 part
    # @return   [undef]         failed to decode or the arguments are missing
    # @since v4.1.3
    my $class = shift;
    my $mhead = shift // return undef;
    my $mbody = shift // return undef;
    my $match = 0; $match ||= 1 if rindex($mhead->{'content-type'}, 'Boundary_(ID_') > -1;
                   $match ||= 1 if index($mhead->{'subject'}, 'Delivery Notification: ') == 0;
    return undef unless $match;

    state $indicators = __PACKAGE__->INDICATORS;
    state $boundaries = ['Content-Type: message/rfc822', 'Return-path: '];
    state $startingof = {'message' => ['This report relates to a message you sent with the following header fields:']};
    state $messagesof = {'hostunknown' => ['Illegal host/domain name found']};

    my $dscontents = [__PACKAGE__->DELIVERYSTATUS]; my $v = undef;
    my $emailparts = Sisimai::RFC5322->part($mbody, $boundaries);
    my $readcursor = 0;     # (Integer) Points the current cursor position
    my $recipients = 0;     # (Integer) The number of 'Final-Recipient' header

    for my $e ( split("\n", $emailparts->[0]) ) {
        # Read error messages and delivery status lines from the head of the email to the previous
        # line of the beginning of the original message.
        unless( $readcursor ) {
            # Beginning of the bounce message or message/delivery-status part
            $readcursor |= $indicators->{'deliverystatus'} if index($e, $startingof->{'message'}->[0]) == 0;
            next;
        }
        next if ($readcursor & $indicators->{'deliverystatus'}) == 0 || $e eq "";

        # --Boundary_(ID_0000000000000000000000)
        # Content-type: text/plain; charset=us-ascii
        # Content-language: en-US
        #
        # This report relates to a message you sent with the following header fields:
        #
        #   Message-id: <CD8C6134-C312-41D5-B083-366F7FA1D752@me.example.com>
        #   Date: Fri, 21 Nov 2014 23:34:45 +0900
        #   From: Shironeko <shironeko@me.example.com>
        #   To: kijitora@example.jp
        #   Subject: Nyaaaaaaaaaaaaaaaaaaaaaan
        #
        # Your message cannot be delivered to the following recipients:
        #
        #   Recipient address: kijitora@example.jp
        #   Reason: Remote SMTP server has rejected address
        #   Diagnostic code: smtp;550 5.1.1 <kijitora@example.jp>... User Unknown
        #   Remote system: dns;mx.example.jp (TCP|17.111.174.67|47323|192.0.2.225|25) (6jo.example.jp ESMTP SENDMAIL-VM)
        $v = $dscontents->[-1];

        if( Sisimai::String->aligned(\$e, ['  Recipient address: ', '@', '.']) ||
            Sisimai::String->aligned(\$e, ['  Original address: ',  '@', '.']) ) {
            #   Recipient address: @smtp.example.net:kijitora@server
            #   Original address: kijitora@example.jp
            my $cv = Sisimai::Address->s3s4(substr($e, rindex($e, ' ') + 1),);
            next unless Sisimai::Address->is_emailaddress($cv);

            if( $v->{'recipient'} && $cv ne $v->{'recipient'}) {
                # There are multiple recipient addresses in the message body.
                push @$dscontents, __PACKAGE__->DELIVERYSTATUS;
                $v = $dscontents->[-1];
            }
            $v->{'recipient'} = $cv;
            $recipients++;

        } elsif( index($e, '  Date: ') == 0 ) {
            #   Date: Fri, 21 Nov 2014 23:34:45 +0900
            $v->{'date'} = substr($e, index($e, ':') + 2,);

        } elsif( index($e, '  Reason: ') == 0 ) {
            #   Reason: Remote SMTP server has rejected address
            $v->{'diagnosis'} = substr($e, index($e, ':') + 2,);

        } elsif( index($e, '  Diagnostic code: ') == 0 ) {
            #   Diagnostic code: smtp;550 5.1.1 <kijitora@example.jp>... User Unknown
            my $p1 = index($e, ':');
            my $p2 = index($e, ';');
            $v->{'spec'} = uc substr($e, $p1 + 2, $p2 - $p1 - 2);
            $v->{'diagnosis'} = substr($e, $p2 + 1,);

        } elsif( index($e, '  Remote system: ') == 0 ) {
            #   Remote system: dns;mx.example.jp (TCP|17.111.174.67|47323|192.0.2.225|25)
            #     (6jo.example.jp ESMTP SENDMAIL-VM)
            my $p1 = index($e, ';');
            my $p2 = index($e, '(');

            my $remotehost = substr($e, $p1 + 1, $p2 - $p1 - 2);
            my $sessionlog = [split('|', substr($e, $p2,))];
            $v->{'rhost'} = $remotehost;

            # The value does not include ".", use IP address instead.
            # (TCP|17.111.174.67|47323|192.0.2.225|25)
            next unless $sessionlog->[0] eq '(TCP';
            $v->{'lhost'} = $sessionlog->[1];
            $v->{'rhost'} = $sessionlog->[3] unless index($remotehost, '.') > 1;

        } else {
            # Original-envelope-id: 0NFC009FLKOUVMA0@mr21p30im-asmtp004.me.com
            # Reporting-MTA: dns;mr21p30im-asmtp004.me.com (tcp-daemon)
            # Arrival-date: Thu, 29 Apr 2014 23:34:45 +0000 (GMT)
            #
            # Original-recipient: rfc822;kijitora@example.jp
            # Final-recipient: rfc822;kijitora@example.jp
            # Action: failed
            # Status: 5.1.1 (Remote SMTP server has rejected address)
            # Remote-MTA: dns;mx.example.jp (TCP|17.111.174.67|47323|192.0.2.225|25)
            #  (6jo.example.jp ESMTP SENDMAIL-VM)
            # Diagnostic-code: smtp;550 5.1.1 <kijitora@example.jp>... User Unknown
            #
            if( index($e, 'Status: ') == 0 ) {
                # Status: 5.1.1 (Remote SMTP server has rejected address)
                my $p1 = index($e, ':');
                my $p2 = index($e, '(');
                $v->{'status'}      = substr($e, $p1 + 2, $p2 - $p1 - 3);
                $v->{'diagnosis'} ||= substr($e, $p2 + 1, index($e, ')') - $p2 - 1);

            } elsif( index($e, 'Arrival-Date: ') == 0 ) {
                # Arrival-date: Thu, 29 Apr 2014 23:34:45 +0000 (GMT)
                $v->{'date'} ||= substr($e, index($e, ':') + 2,);

            } elsif( index($e, 'Reporting-MTA: ') == 0 ) {
                # Reporting-MTA: dns;mr21p30im-asmtp004.me.com (tcp-daemon)
                my $localhost = substr($e, index($e, ';') + 1,);
                $v->{'lhost'} ||= $localhost;
                $v->{'lhost'}   = $localhost unless index($v->{'lhost'}, '.') > 0;
            }
        } # End of error message part
    }
    return undef unless $recipients;

    for my $e ( @$dscontents ) {
        $e->{'diagnosis'} = Sisimai::String->sweep($e->{'diagnosis'});

        SESSION: for my $r ( keys %$messagesof ) {
            # Verify each regular expression of session errors
            next unless grep { index($e->{'diagnosis'}, $_) > -1 } $messagesof->{ $r }->@*;
            $e->{'reason'} = $r;
            last;
        }
    }
    return {"ds" => $dscontents, "rfc822" => $emailparts->[1]};
}

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai::Lhost::MessagingServer - bounce mail decoder class for C<Sun Java System Messaging Server>
and C<Oracle Communications Messaging Server> L<https://docs.oracle.com/en/industries/communications/messaging-server/index.html>.

=head1 SYNOPSIS

    use Sisimai::Lhost::MessagingServer;

=head1 DESCRIPTION

C<Sisimai::Lhost::MessagingServer> decodes a bounce email which created by Oracle Communications
Messaging Server L<https://docs.oracle.com/en/industries/communications/messaging-server/index.html>
and Sun Java System Messaging Server. Methods in the module are called from only C<Sisimai::Message>.

=head1 CLASS METHODS

=head2 C<B<description()>>

C<description()> returns description string of this module.

    print Sisimai::Lhost::MessagingServer->description;

=head2 C<B<inquire(I<header data>, I<reference to body string>)>>

C<inquire()> method decodes a bounced email and return results as a array reference.
See C<Sisimai::Message> for more details.

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2014-2025 azumakuniyuki, All rights reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut

