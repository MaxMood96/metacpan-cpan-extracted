package Sisimai::ARF;
use v5.26;
use strict;
use warnings;
use Sisimai::Lhost;
use Sisimai::RFC5322;

sub description { return 'Abuse Feedback Reporting Format' }
sub is_arf {
    # Email is a Feedback-Loop message or not
    # @param    [Hash] heads    Email header including "Content-Type", "From" and "Subject" field
    # @return   [Integer]       1: Feedback Loop
    #                           0: is not Feedback loop
    my $class = shift;
    my $heads = shift || return 0;
    my $abuse = ['staff@hotmail.com', 'complaints@email-abuse.amazonses.com'];
    my $ctype = $heads->{"content-type"} || "";

    # Content-Type: multipart/report; report-type=feedback-report; ...
    return 1 if Sisimai::String->aligned(\$ctype, ["report-type=", "feedback-report"]);

    if( index($ctype, "multipart/mixed") > -1 ) {
        # Microsoft (Hotmail, MSN, Live, Outlook) uses its own report format.
        # Amazon SES Complaints bounces
        if( index($heads->{"subject"}, "complaint about message from ") > -1 ) {
            # From: staff@hotmail.com
            # From: complaints@email-abuse.amazonses.com
            # Subject: complaint about message from 192.0.2.1
            return 1 if grep { index($heads->{"from"}, $_) > -1 } @$abuse;
        }
    }

    # X-Apple-Unsubscribe: true
    return 0 unless exists $heads->{"x-apple-unsubscribe"};
    return 1 if $heads->{"x-apple-unsubscribe"} eq "true";
    return 0;
}

sub inquire {
    # Detect an error for Feedback Loop
    # @param    [Hash] mhead    Message headers of a bounce email
    # @param    [String] mbody  Message body of a bounce email
    # @return   [Hash]          Bounce data list and message/rfc822 part
    # @return   [undef]         failed to decode or the arguments are missing
    my $class = shift;
    my $mhead = shift // return undef; return undef unless is_arf(undef, $mhead);
    my $mbody = shift // return undef;

    # http://tools.ietf.org/html/rfc5965
    # http://en.wikipedia.org/wiki/Feedback_loop_(email)
    # http://en.wikipedia.org/wiki/Abuse_Reporting_Format
    #
    # Netease DMARC uses:    This is a spf/dkim authentication-failure report for an email message received from IP
    # OpenDMARC 1.3.0 uses:  This is an authentication failure report for an email message received from IP
    # Abusix ARF uses:       this is an autogenerated email abuse complaint regarding your network.
    state $indicators = Sisimai::Lhost->INDICATORS;
    state $reportfrom = "Content-Type: message/feedback-report";
    state $boundaries = [
        "Content-Type: message/rfc822",
        "Content-Type: text/rfc822-headers",
        "Content-Type: text/rfc822-header",  # ??
    ];
    state $arfpreface = [
        ["this is a", "abuse report"],
        ["this is a", "authentication", "failure report"],
        ["this is a", " report for"],
        ["this is an authentication", "failure report"],
        ["this is an autogenerated email abuse complaint"],
        ["this is an email abuse report"],
    ];

    my $dscontents = [Sisimai::Lhost->DELIVERYSTATUS]; my $v = $dscontents->[-1];
    my $reportpart = 0;
    my $emailparts = Sisimai::RFC5322->part($mbody, $boundaries);
    my $readcursor = 0;     # Points the current cursor position
    my $recipients = 0;     # The number of "Final-Recipient" header
    my $timestamp0 = "";    # The value of "Arrival-Date" or "Received-Date"
    my $remotehost = "";    # The value of "Source-IP" field
    my $reportedby = "";    # The value of "Reporting-MTA" field
    my $anotherone = "";    # Other fields(append to Diagnosis)

    # 3.1.  Required Fields
    #
    #   The following report header fields MUST appear exactly once:
    #
    #   o  "Feedback-Type" contains the type of feedback report (as defined
    #      in the corresponding IANA registry and later in this memo).  This
    #      is intended to let report parsers distinguish among different
    #      types of reports.
    #
    #   o  "User-Agent" indicates the name and version of the software
    #      program that generated the report.  The format of this field MUST
    #      follow section 14.43 of [HTTP].  This field is for documentation
    #      only; there is no registry of user agent names or versions, and
    #      report receivers SHOULD NOT expect user agent names to belong to a
    #      known set.
    #
    #   o  "Version" indicates the version of specification that the report
    #      generator is using to generate the report.  The version number in
    #      this specification is set to "1".
    #
    for my $e ( split("\n", $emailparts->[0]) ) {
        # Read error messages and delivery status lines from the head of the email to the
        # previous line of the beginning of the original message.
        unless( $readcursor ) {
            # Beginning of the bounce message or message/delivery-status part
            my $r = lc $e;
            for my $f ( @$arfpreface ) {
                # Hello,
                # this is an autogenerated email abuse complaint regarding your network.
                next unless Sisimai::String->aligned(\$r, $f);
                $readcursor |= $indicators->{'deliverystatus'};
                $v->{"diagnosis"} .= " ".$e;
                last;
            }
            next;
        }
        next if ($readcursor & $indicators->{'deliverystatus'}) == 0 || $e eq "";
        if( $e eq $reportfrom ) { $reportpart = 1; next }

        if( $reportpart ) {
            # Content-Type: message/feedback-report
            # MIME-Version: 1.0
            #
            # Feedback-Type: abuse
            # User-Agent: SomeGenerator/1.0
            # Version: 0.1
            # Original-Mail-From: <somespammer@example.net>
            # Original-Rcpt-To: <kijitora@example.jp>
            # Received-Date: Thu, 29 Apr 2009 00:00:00 JST
            # Source-IP: 192.0.2.1
            if( index($e, "Original-Rcpt-To: ") == 0 || index($e, "Removal-Recipient: ") == 0 ) {
                # Original-Rcpt-To header field is optional and may appear any number of times as appropriate:
                # Original-Rcpt-To: <kijitora@example.jp>
                # Removal-Recipient: user@example.com
                my $cv = Sisimai::Address->s3s4(substr($e, index($e, " ") + 1,)); next unless Sisimai::Address->is_emailaddress($cv);
                my $cw = scalar @$dscontents;                                     next if $cw > 0 && $cv eq $dscontents->[$cw - 1]->{"recipient"};

                if( $v->{"recipient"} ) {
                    # There are multiple recipient addresses in the message body.
                    push @$dscontents, Sisimai::Lhost->DELIVERYSTATUS;
                    $v = $dscontents->[-1];
                }
                $v->{"recipient"} = Sisimai::Address->s3s4(substr($e, index($e, " ") +1,));
                $recipients++;

            } elsif( index($e, "Feedback-Type: ") == 0 ) {
                # The header field MUST appear exactly once.
                # Feedback-Type: abuse
                $v->{"feedbacktype"} = substr($e, index($e, " ") + 1,);

            } elsif( index($e, "Authentication-Results: ") == 0 || index($e, "User-Agent: ") == 0 || index($e, "Original-Mail-From: ") == 0 ) {
                # "Authentication-Results" indicates the result of one or more authentication checks
                # run by the report generator.
                #   - Authentication-Results: mail.example.com;
                #   - spf=fail smtp.mail=somespammer@example.com
                #
                # The header field MUST appear exactly once.
                #   - User-Agent: SomeGenerator/1.0
                #
                # The header is optional and MUST NOT appear more than once.
                #   - Original-Mail-From: <somespammer@example.net>
                $anotherone .= $e.", ";

            } elsif( index($e, "Received-Date: ") == 0 || index($e, "Arrival-Date: ") == 0 ) {
                # Arrival-Date header is optional and MUST NOT appear more than once.
                # Received-Date: Thu, 29 Apr 2010 00:00:00 JST
                # Arrival-Date: Thu, 29 Apr 2010 00:00:00 +0000
                $timestamp0 = substr($e, index($e, " ") + 1,);

            } elsif( index($e, "Reporting-MTA: ") == 0 ) {
                # The header is optional and MUST NOT appear more than once.
                # Reporting-MTA: dns; mx.example.jp
                my $cv = Sisimai::RFC1894->field($e); next if scalar(@$cv) == 0;
                $reportedby = $cv->[2];

            } elsif( index($e, "Source-IP: ") == 0 ) {
                # The header is optional and MUST NOT appear more than once.
                # Source-IP: 192.0.2.45
                $remotehost = substr($e, index($e, ' ') + 1,);
            }
        } else {
            # Messages before "Content-Type: message/feedback-report" part
            $v->{"diagnosis"} .= " ".$e;
        }
    }

    while( $recipients == 0 ) {
        # There is no recipient address in the message
        if( exists $mhead->{"x-apple-unsubscribe"} ) {
            # X-Apple-Unsubscribe: true
            last if $mhead->{"x-apple-unsubscribe"} ne "true" || index($mhead->{"from"}, "@") < 1;
            $dscontents->[0]->{"recipient"}    = $mhead->{"from"};
            $dscontents->[0]->{"diagnosis"}    = Sisimai::String->sweep($emailparts->[0]);
            $dscontents->[0]->{"feedbacktype"} = "opt-out";

            # Addpend To: field as a pseudo header
            $emailparts->[1] = sprintf("To: <%s>\n", $mhead->{"from"}) if $emailparts->[1] eq "";

        } else {
            # Pick it from the original message part
            my $p1 = index($emailparts->[1], "\nTo:");       last if $p1 < 0;
            my $p2 = index($emailparts->[1], "\n", $p1 + 4); last if $p2 < 0;
            my $cv = Sisimai::Address->s3s4(substr($emailparts->[1], $p1 + 4, $p2 - $p1));

            # There is no valid email address in the To: header of the original message such as
            # To: <Undisclosed Recipients>
            $cv = Sisimai::Address->undisclosed("r") unless Sisimai::Address->is_emailaddress($cv);
            $dscontents->[0]->{"recipient"} = $cv;
        }
        $recipients++;
    }
    return undef if $recipients == 0;

    $anotherone = ": ".Sisimai::String->sweep($anotherone) if $anotherone ne "";
    substr($anotherone, -1, 1, "") if substr($anotherone, -1, 1) eq ",";

    my $j = -1; for my $e ( @$dscontents ) {
        # Tidy up the error message in e.Diagnosis, Try to detect the bounce reason.
        $j++;
        $e->{"diagnosis"} = Sisimai::String->sweep($e->{"diagnosis"}.$anotherone);
        $e->{"reason"}    = "feedback";
        $e->{"rhost"}     = $remotehost;
        $e->{"lhost"}     = $reportedby;
        $e->{"date"}      = $timestamp0;

        # Copy some values from the previous element when the report have 2 or more email address
        next if $j == 0 || scalar(@$dscontents) == 1;
        $e->{"diagnosis"}    = $dscontents->[$j - 1]->{"diagnosis"};
        $e->{"feedbacktype"} = $dscontents->[$j - 1]->{"feedbacktype"};
    }
    return {"ds" => $dscontents, "rfc822" => $emailparts->[1]};
}

1;
__END__

=encoding utf-8

=head1 NAME

C<Sisimai::ARF> - Decoder class for detecting ARF: Abuse Feedback Reporting Format.

=head1 SYNOPSIS

    use Sisimai::ARF;
    my $v = Sisimai::ARF->inquire($header, $body);

=head1 DESCRIPTION

C<Sisimai::ARF> is a decoder for email returned as a Feedback Loop report message.

=head1 FEEDBACK TYPES

=over

=item B<abuse> spam or some other kind of email abuse

=item B<fraud> Indicates some kind of fraud or phishing activity

=item B<virus> report of a virus found in the originating message

=item B<other> any other feedback that doesn't fit into other types

=item B<not-spam> can be used to report an email message that was mistakenly marked as spam

=back

=head1 SEE ALSO

L<http://tools.ietf.org/html/rfc5965>

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2014-2021,2023-2025 azumakuniyuki, All rights reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut
