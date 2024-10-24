package Sisimai::Lhost::Facebook;
use parent 'Sisimai::Lhost';
use v5.26;
use strict;
use warnings;

sub description { 'Facebook: https://www.facebook.com' }
sub inquire {
    # Detect an error from Facebook
    # @param    [Hash] mhead    Message headers of a bounce email
    # @param    [String] mbody  Message body of a bounce email
    # @return   [Hash]          Bounce data list and message/rfc822 part
    # @return   [undef]         failed to decodes or the arguments are missing
    # @since v4.0.0
    my $class = shift;
    my $mhead = shift // return undef;
    my $mbody = shift // return undef;

    return undef unless $mhead->{'from'} eq 'Facebook <mailer-daemon@mx.facebook.com>';
    return undef unless $mhead->{'subject'} eq 'Sorry, your message could not be delivered';

    state $indicators = __PACKAGE__->INDICATORS;
    state $boundaries = ['Content-Disposition: inline'];
    state $startingof = { 'message' => ['This message was created automatically by Facebook.'] };
    state $errorcodes = {
        # http://postmaster.facebook.com/response_codes
        # NOT TESTD EXCEPT RCP-P2
        'userunknown' => [
            'RCP-P1',   # The attempted recipient address does not exist.
            'INT-P1',   # The attempted recipient address does not exist.
            'INT-P3',   # The attempted recpient group address does not exist.
            'INT-P4',   # The attempted recipient address does not exist.
        ],
        'filtered' => [
            'RCP-P2',   # The attempted recipient's preferences prevent messages from being delivered.
            'RCP-P3',   # The attempted recipient's privacy settings blocked the delivery.
        ],
        'blocked' => [
            'POL-P1',   # Your mail server's IP Address is listed on the Spamhaus PBL.
            'POL-P2',   # Facebook will no longer accept mail from your mail server's IP Address.
        ],
        'mesgtoobig' => [
            'MSG-P1',   # The message exceeds Facebook's maximum allowed size.
            'INT-P2',   # The message exceeds Facebook's maximum allowed size.
        ],
        'contenterror' => [
            'MSG-P2',   # The message contains an attachment type that Facebook does not accept.
            'MSG-P3',   # The message contains multiple instances of a header field that can only be present once.
            'POL-P6',   # The message contains a url that has been blocked by Facebook.
            'POL-P7',   # The message does not comply with Facebook's abuse policies and will not be accepted.
        ],
        'securityerror' => [
            'POL-P7',   # The message does not comply with Facebook's Domain Authentication requirements.
        ],
        'notaccept' => [
            'POL-P3',   # Facebook is not accepting messages from your mail server. This will persist for 4 to 8 hours.
            'POL-P4',   # Facebook is not accepting messages from your mail server. This will persist for 24 to 48 hours.
            'POL-T1',   # Facebook is not accepting messages from your mail server, but they may be retried later. This will persist for 1 to 2 hours.
            'POL-T2',   # Facebook is not accepting messages from your mail server, but they may be retried later. This will persist for 4 to 8 hours.
            'POL-T3',   # Facebook is not accepting messages from your mail server, but they may be retried later. This will persist for 24 to 48 hours.
        ],
        'rejected' => [
            'DNS-P1',   # Your SMTP MAIL FROM domain does not exist.
            'DNS-P2',   # Your SMTP MAIL FROM domain does not have an MX record.
            'DNS-T1',   # Your SMTP MAIL FROM domain exists but does not currently resolve.
            'DNS-P3',   # Your mail server does not have a reverse DNS record.
            'DNS-T2',   # You mail server's reverse DNS record does not currently resolve.
        ],
        'systemerror' => [
            'CON-T1',   # Facebook's mail server currently has too many connections open to allow another one.
            'RCP-T1',   # The attempted recipient address is not currently available due to an internal system issue. This is a temporary condition.
        ],
        'toomanyconn' => [
            'CON-T2',   # Your mail server currently has too many connections open to Facebook's mail servers.
            'CON-T3',   # Your mail server has opened too many new connections to Facebook's mail servers in a short period of time.
        ],
        'virusdetected' => [
            'POL-P5',   # The message contains a virus.
        ],
        'suspend' => [
            'RCP-T4',   # The attempted recipient address is currently deactivated. The user may or may not reactivate it.
        ],
        'undefined' => [
            'MSG-T1',   # The number of recipients on the message exceeds Facebook's allowed maximum.
            'CON-T4',   # Your mail server has exceeded the maximum number of recipients for its current connection.
        ],
    };

    my $fieldtable = Sisimai::RFC1894->FIELDTABLE;
    my $permessage = {};    # (Hash) Store values of each Per-Message field
    my $dscontents = [__PACKAGE__->DELIVERYSTATUS];
    my $emailparts = Sisimai::RFC5322->part($mbody, $boundaries);
    my $readcursor = 0;     # (Integer) Points the current cursor position
    my $recipients = 0;     # (Integer) The number of 'Final-Recipient' header
    my $fbresponse = '';    # (String) Response code from Facebook
    my $v = undef;
    my $p = '';

    for my $e ( split("\n", $emailparts->[0]) ) {
        # Read error messages and delivery status lines from the head of the email to the previous
        # line of the beginning of the original message.
        unless( $readcursor ) {
            # Beginning of the bounce message or message/delivery-status part
            $readcursor |= $indicators->{'deliverystatus'} if index($e, $startingof->{'message'}->[0]) == 0;
            next;
        }
        next unless $readcursor & $indicators->{'deliverystatus'};
        next unless length $e;

        if( my $f = Sisimai::RFC1894->match($e) ) {
            # $e matched with any field defined in RFC3464
            next unless my $o = Sisimai::RFC1894->field($e);
            $v = $dscontents->[-1];

            if( $o->[-1] eq 'addr' ) {
                # Final-Recipient: rfc822; kijitora@example.jp
                # X-Actual-Recipient: rfc822; kijitora@example.co.jp
                if( $o->[0] eq 'final-recipient' ) {
                    # Final-Recipient: rfc822; kijitora@example.jp
                    if( $v->{'recipient'} ) {
                        # There are multiple recipient addresses in the message body.
                        push @$dscontents, __PACKAGE__->DELIVERYSTATUS;
                        $v = $dscontents->[-1];
                    }
                    $v->{'recipient'} = $o->[2];
                    $recipients++;

                } else {
                    # X-Actual-Recipient: rfc822; kijitora@example.co.jp
                    $v->{'alias'} = $o->[2];
                }
            } elsif( $o->[-1] eq 'code' ) {
                # Diagnostic-Code: SMTP; 550 5.1.1 <userunknown@example.jp>... User Unknown
                $v->{'spec'} = $o->[1];
                $v->{'diagnosis'} = $o->[2];

            } else {
                # Other DSN fields defined in RFC3464
                next unless exists $fieldtable->{ $o->[0] };
                $v->{ $fieldtable->{ $o->[0] } } = $o->[2];

                next unless $f == 1;
                $permessage->{ $fieldtable->{ $o->[0] } } = $o->[2];
            }
        } else {
            # Continued line of the value of Diagnostic-Code field
            next unless index($p, 'Diagnostic-Code:') == 0;
            next unless index($e, ' ') == 0;
            $v->{'diagnosis'} .= ' '.substr($e, rindex($e, ' ') + 1,);
        }
    } continue {
        # Save the current line for the next loop
        $p = $e;
    }
    return undef unless $recipients;

    for my $e ( @$dscontents ) {
        $e->{'diagnosis'} = Sisimai::String->sweep($e->{'diagnosis'});

        my $p0 = index($e->{'diagnosis'}, '-');
        $fbresponse = substr($e->{'diagnosis'}, $p0 - 3, 6) if $p0 > 0;

        SESSION: for my $r ( keys %$errorcodes ) {
            # Verify each regular expression of session errors
            PATTERN: for my $rr ( $errorcodes->{ $r }->@* ) {
                # Check each regular expression
                next(PATTERN) unless $fbresponse eq $rr;
                $e->{'reason'} = $r;
                last(SESSION);
            }
        }
        next if $e->{'reason'};

        # http://postmaster.facebook.com/response_codes
        #   Facebook System Resource Issues
        #   These codes indicate a temporary issue internal to Facebook's
        #   system. Administrators observing these issues are not required to
        #   take any action to correct them.
        #
        # * INT-Tx
        #
        # https://groups.google.com/forum/#!topic/cdmix/eXfi4ddgYLQ
        # This block has not been tested because we have no email sample
        # including "INT-T?" error code.
        next unless index($fbresponse, 'INT-T') == 0;
        $e->{'reason'} = 'systemerror';
    }
    return { 'ds' => $dscontents, 'rfc822' => $emailparts->[1] };
}

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai::Lhost::Facebook - bounce mail decoder class for Facebook L<https://www.facebook.com>.

=head1 SYNOPSIS

    use Sisimai::Lhost::Facebook;

=head1 DESCRIPTION

C<Sisimai::Lhost::Facebook> decodes a bounce email which created by Facebook L<https://www.facebook.com>.
Methods in the module are called from only C<Sisimai::Message>.

=head1 CLASS METHODS

=head2 C<B<description()>>

C<description()> returns description string of this module.

    print Sisimai::Lhost::Facebook->description;

=head2 C<B<inquire(I<header data>, I<reference to body string>)>>

C<inquire()> method decodes a bounced email and return results as a array reference.
See C<Sisimai::Message> for more details.

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2014-2024 azumakuniyuki, All rights reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut

