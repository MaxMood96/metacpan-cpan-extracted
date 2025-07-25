package Sisimai::Lhost::Exchange2003;
use parent 'Sisimai::Lhost';
use v5.26;
use strict;
use warnings;

sub description { 'Microsoft Exchange Server 2003: https://www.microsoft.com/microsoft-365/exchange/email' }
sub inquire {
    # Detect an error from Microsoft Exchange Server 2003
    # @param    [Hash] mhead    Message headers of a bounce email
    # @param    [String] mbody  Message body of a bounce email
    # @return   [Hash]          Bounce data list and message/rfc822 part
    # @return   [undef]         failed to decode or the arguments are missing
    # @since v4.1.1
    my $class = shift;
    my $mhead = shift // return undef;
    my $mbody = shift // return undef;

    # X-MS-TNEF-Correlator: <00000000000000000000000000000000000000@example.com>
    # X-Mailer: Internet Mail Service (5.5.1960.3)
    # X-MS-Embedded-Report:
    my $match = 0; $match ||= 1 if defined $mhead->{'x-ms-embedded-report'};
    EXCHANGE_OR_NOT: while(1) {
        # Check the value of X-Mailer header
        last if $match;

        if( defined $mhead->{'x-mailer'} ) {
            # X-Mailer:  Microsoft Exchange Server Internet Mail Connector Version 4.0.994.63
            # X-Mailer: Internet Mail Service (5.5.2232.9)
            my $tryto = ['Internet Mail Service (', 'Microsoft Exchange Server Internet Mail Connector'];
            my $value = $mhead->{'x-mailer'} || '';
            $match ||= 1 if index($value, $tryto->[0]) == 0 || index($value, $tryto->[1]) == 0;
            last if $match;
        }

        if( defined $mhead->{'x-mimeole'} ) {
            # X-MimeOLE: Produced By Microsoft Exchange V6.5
            $match ||= 1 if index($mhead->{'x-mimeole'}, 'Produced By Microsoft Exchange') == 0;
            last if $match;
        }

        last unless scalar $mhead->{'received'}->@*;
        for my $e ( $mhead->{'received'}->@* ) {
            # Received: by ***.**.** with Internet Mail Service (5.5.2657.72)
            next unless rindex($e, ' with Internet Mail Service (') > -1;
            $match = 1;
            last(EXCHANGE_OR_NOT);
        }
        last;
    }
    return undef unless $match;

    state $indicators = __PACKAGE__->INDICATORS;
    state $boundaries = ['Content-Type: message/rfc822'];
    state $startingof = {
        'message' => ['Your message'],
        'error'   => ['did not reach the following recipient(s):'],
    };
    state $errorcodes = {
        'onhold' => [
            '000B099C', # Host Unknown, Message exceeds size limit, ...
            '000B09AA', # Unable to relay for, Message exceeds size limit,...
            '000B09B6', # Error messages by remote MTA
        ],
        'userunknown' => [
            '000C05A6', # Unknown Recipient,
        ],
        'systemerror' => [
            '00010256', # Too many recipients.
            '000D06B5', # No proxy for recipient (non-smtp mail?)
        ],
        'networkerror' => [
            '00120270', # Too Many Hops
        ],
        'contenterror' => [
            '00050311', # Conversion to Internet format failed
            '000502CC', # Conversion to Internet format failed
        ],
        'securityerror' => [
            '000B0981', # 502 Server does not support AUTH
        ],
        'filtered' => [
            '000C0595', # Ambiguous Recipient
        ],
    };

    my $dscontents = [__PACKAGE__->DELIVERYSTATUS]; my $v = undef;
    my $emailparts = Sisimai::RFC5322->part($mbody, $boundaries);
    my $readcursor = 0;     # (Integer) Points the current cursor position
    my $recipients = 0;     # (Integer) The number of 'Final-Recipient' header
    my $statuspart = 0;     # (Integer) Flag, 1 = have got delivery status part.
    my $connvalues = 0;     # (Integer) Flag, 1 if all the value of $connheader have been set
    my $connheader = {
        'to'      => '',    # The value of "To"
        'date'    => '',    # The value of "Date"
        'subject' => '',    # The value of "Subject"
    };

    for my $e ( split("\n", $emailparts->[0]) ) {
        # Read error messages and delivery status lines from the head of the email to the previous
        # line of the beginning of the original message.
        unless( $readcursor ) {
            # Beginning of the bounce message or message/delivery-status part
            $readcursor |= $indicators->{'deliverystatus'} if index($e, $startingof->{'message'}->[0]) == 0;
            next;
        }
        next if ($readcursor & $indicators->{'deliverystatus'}) == 0 || $statuspart == 1;

        if( $connvalues == scalar(keys %$connheader) ) {
            # did not reach the following recipient(s):
            #
            # kijitora@example.co.jp on Thu, 29 Apr 2007 16:51:51 -0500
            #     The recipient name is not recognized
            #     The MTS-ID of the original message is: c=jp;a= ;p=neko
            # ;l=EXCHANGE000000000000000000
            #     MSEXCH:IMS:KIJITORA CAT:EXAMPLE:EXCHANGE 0 (000C05A6) Unknown Recipient
            # mikeneko@example.co.jp on Thu, 29 Apr 2007 16:51:51 -0500
            #     The recipient name is not recognized
            #     The MTS-ID of the original message is: c=jp;a= ;p=neko
            # ;l=EXCHANGE000000000000000000
            #     MSEXCH:IMS:KIJITORA CAT:EXAMPLE:EXCHANGE 0 (000C05A6) Unknown Recipient
            $v = $dscontents->[-1];

            if( Sisimai::String->aligned(\$e, ['@', ' on ']) ) {
                # kijitora@example.co.jp on Thu, 29 Apr 2007 16:51:51 -0500
                #   kijitora@example.com on 4/29/99 9:19:59 AM
                if( $v->{'recipient'} ) {
                    # There are multiple recipient addresses in the message body.
                    push @$dscontents, __PACKAGE__->DELIVERYSTATUS;
                    $v = $dscontents->[-1];
                }

                my $p1 = index(lc $e, 'smtp='); $p1 = $p1 == -1 ? 0 : $p1 + 5;
                my $p2 = index($e, ' on ') + 1;
                $v->{'recipient'} = Sisimai::Address->s3s4(substr($e, $p1, $p2));
                $v->{'msexch'} = 0;
                $recipients++;

            } elsif( index($e, ' ') == 0 && index($e, 'MSEXCH:') > 0 ) {
                #     MSEXCH:IMS:KIJITORA CAT:EXAMPLE:EXCHANGE 0 (000C05A6) Unknown Recipient
                $v->{'diagnosis'} .= substr($e, index($e, 'MSEXCH:'),);

            } else {
                next if $v->{'msexch'};
                if( index($v->{'diagnosis'}, 'MSEXCH:') == 0 ) {
                    # Continued from MEEXCH in the previous line
                    $v->{'msexch'} = 1;
                    $v->{'diagnosis'} .= ' '.$e;
                    $statuspart = 1;

                } else {
                    # Error message in the body part
                    $v->{'alterrors'} .= ' '.$e;
                }
            }
        } else {
            # Your message
            #
            #  To:      shironeko@example.jp
            #  Subject: ...
            #  Sent:    Thu, 29 Apr 2010 18:14:35 +0000
            #
            if( index($e, '  To:  ') == 0 || index($e, '      To: ') == 0 ) {
                #  To:      shironeko@example.jp
                next if $connheader->{'to'};
                $connheader->{'to'} = substr($e, rindex($e, ' ') + 1,);
                $connvalues++;

            } elsif( index($e, '      Subject: ') == 0  || index($e, '  Subject: ') == 0 ) {
                #  Subject: ...
                next if length $connheader->{'subject'};
                $connheader->{'subject'} = substr($e, rindex($e, ' ') + 1,);
                $connvalues++;

            } elsif( index($e, '  Sent: ') == 0 || index($e, '      Sent: ') == 0 ) {
                #  Sent:    Thu, 29 Apr 2010 18:14:35 +0000
                #  Sent:    4/29/99 9:19:59 AM
                next if $connheader->{'date'};
                $connheader->{'date'} = substr($e, index($e, ':') + 2,);
                $connvalues++;
            }
        } # End of error message part
    }
    return undef unless $recipients;

    for my $e ( @$dscontents ) {
        $e->{'diagnosis'} = Sisimai::String->sweep($e->{'diagnosis'});
        delete $e->{'msexch'};

        if( index($e->{'diagnosis'}, 'MSEXCH:') == 0 ) {
            #     MSEXCH:IMS:KIJITORA CAT:EXAMPLE:EXCHANGE 0 (000C05A6) Unknown Recipient
            my $capturedcode = substr($e->{'diagnosis'}, index($e->{'diagnosis'}, '(') + 1, 8);
            my $errormessage = substr($e->{'diagnosis'}, index($e->{'diagnosis'}, ')') + 1,  );

            for my $r ( keys %$errorcodes ) {
                # Find captured code from the error code table
                next unless grep { $capturedcode eq $_ } $errorcodes->{ $r }->@*;
                $e->{'reason'} = $r;
                $e->{'status'} = Sisimai::SMTP::Status->code($r) || '';
                last;
            }
            $e->{'diagnosis'} = $errormessage;
        }

        # Could not detect the reason from the value of "diagnosis", copy alternative error message
        next if $e->{'reason'};
        next unless exists $e->{'alterrors'} && length $e->{'alterrors'};

        $e->{'diagnosis'} = $e->{'alterrors'}.' '.$e->{'diagnosis'};
        $e->{'diagnosis'} = Sisimai::String->sweep($e->{'diagnosis'});
        delete $e->{'alterrors'};
    }

    unless( length $emailparts->[1] ) {
        # When original message does not included in the bounce message
        $emailparts->[1] .= sprintf("From: %s\n", $connheader->{'to'});
        $emailparts->[1] .= sprintf("Date: %s\n", $connheader->{'date'});
        $emailparts->[1] .= sprintf("Subject: %s\n", $connheader->{'subject'});
    }
    return {"ds" => $dscontents, "rfc822" => $emailparts->[1]};
}

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai::Lhost::Exchange2003 - bounce mail decoder class for Microsft Exchange Server 2003 L<https://www.microsoft.com/microsoft-365/exchange/email>.

=head1 SYNOPSIS

    use Sisimai::Lhost::Exchange2003;

=head1 DESCRIPTION

C<Sisimai::Lhost::Exchange> decodes a bounce email which created by Microsoft Exchange Server 2003
L<https://www.microsoft.com/microsoft-365/exchange/email>. Methods in the module are called from
only C<Sisimai::Message>.

=head1 CLASS METHODS

=head2 C<B<description()>>

C<description()> returns description string of this module.

    print Sisimai::Lhost::Exchange2003->description;

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

