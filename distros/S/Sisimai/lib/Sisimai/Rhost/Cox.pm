package Sisimai::Rhost::Cox;
use v5.26;
use strict;
use warnings;

sub find {
    # Detect bounce reason from https://cox.com/
    # @param    [Sisimai::Fact] argvs   Decoded email object
    # @return   [String]                The bounce reason at Cox
    # @see      https://www.cox.com/residential/support/email-error-codes.html
    # @since v4.25.8
    my $class = shift;
    my $argvs = shift // return ""; return "" unless $argvs->{'diagnosticcode'};

    state $errorcodes = {
        # CXBL
        # - The sending IP address has been blocked by Cox due to exhibiting spam-like behavior.
        # - Send an email request to Cox to ask for a sending IP address be unblocked.
        #   Note: Cox has sole discretion whether to unblock the sending IP address.
        'CXBL' => 'blocked',

        # CXDNS
        # - There was an issue with the connecting IP address Domain Name System (DNS).
        # - The Reverse DNS (rDNS) lookup for your IP address is failing. 
        #   - Confirm the IP address that sends your email.
        #   - Check the rDNS of that IP address. If it passes, then wait 24 hours and try resending
        #     your email.
        'CXDNS' => 'requireptr',

        # CXSNDR
        # - There was a problem with the sender's domain.
        # - Your email failed authentication checks against your sending domain's SPF, DomainKeys,
        #   or DKIM policy.
        'CXSNDR' => 'authfailure',

        # CXSMTP
        # - There was a violation of SMTP protocol.
        # - Your email wasn't delivered because Cox was unable to verify that it came from a
        #   legitimate email sender.
        'CXSMTP' => 'rejected',

        # CXCNCT
        # - There was a connection issue from the IP address.
        # - There is a limit to the number of concurrent SMTP connections per IP address to
        #   protect the systems against attack. Ensure that the sending email server is not
        #   opening more than 10 concurrent connections to avoid reaching this limit.
        'CXCNCT' => 'toomanyconn',

        # CXMXRT
        #   - The sender has sent email to too many recipients and needs to wait before sending
        #     more email.
        #   - The email sender has exceeded the maximum number of sent email allowed.
        'CXMXRT' => 'toomanyconn', 

        # CDRBL
        # - The sending IP address has been temporarily blocked by Cox due to exhibiting spam-like
        #   behavior.
        # - The block duration varies depending on reputation and other factors, but will not exceed
        #   24 hours. Inspect email traffic for potential spam, and retry email delivery.
        'CDRBL' => 'blocked',

        'CXTHRT'    => 'securityerror', # Email sending limited due to suspicious account activity.
        'CXMJ'      => 'securityerror', # Email sending blocked due to suspicious account activity on primary Cox account.
        'IPBL0001'  => 'blocked',       # The sending IP address is listed in the Spamhaus Zen DNSBL.
        'IPBL0010'  => 'blocked',       # The sending IP is listed in the Return Path DNSBL.
        'IPBL0100'  => 'blocked',       # The sending IP is listed in the Invaluement ivmSIP DNSBL.
        'IPBL0011'  => 'blocked',       # The sending IP is in the Spamhaus Zen and Return Path DNSBLs.
        'IPBL0101'  => 'blocked',       # The sending IP is in the Spamhaus Zen and Invaluement ivmSIP DNSBLs.
        'IPBL0110'  => 'blocked',       # The sending IP is in the Return Path and Invaluement ivmSIP DNSBLs.
        'IPBL0111'  => 'blocked',       # The sending IP is in the Spamhaus Zen, Return Path and Invaluement ivmSIP DNSBLs.
        'IPBL1000'  => 'blocked',       # The sending IP address is listed on a CSI blacklist. You can check your status on the CSI website.
        'IPBL1001'  => 'blocked',       # The sending IP is listed in the Cloudmark CSI and Spamhaus Zen DNSBLs.
        'IPBL1010'  => 'blocked',       # The sending IP is listed in the Cloudmark CSI and Return Path DNSBLs.
        'IPBL1011'  => 'blocked',       # The sending IP is in the Cloudmark CSI, Spamhaus Zen and Return Path DNSBLs.
        'IPBL1100'  => 'blocked',       # The sending IP is listed in the Cloudmark CSI and Invaluement ivmSIP DNSBLs.
        'IPBL1101'  => 'blocked',       # The sending IP is in the Cloudmark CSI, Spamhaus Zen and Invaluement IVMsip DNSBLs.
        'IPBL1110'  => 'blocked',       # The sending IP is in the Cloudmark CSI, Return Path and Invaluement ivmSIP DNSBLs.
        'IPBL1111'  => 'blocked',       # The sending IP is in the Cloudmark CSI, Spamhaus Zen, Return Path and Invaluement ivmSIP DNSBLs.
        'IPBL00001' => 'blocked',       # The sending IP address is listed on a Spamhaus blacklist. Check your status at Spamhaus.

        'URLBL011'  => 'spamdetected',  # A URL within the body of the message was found on blocklists SURBL and Spamhaus DBL.
        'URLBL101'  => 'spamdetected',  # A URL within the body of the message was found on blocklists SURBL and ivmURI.
        'URLBL110'  => 'spamdetected',  # A URL within the body of the message was found on blocklists Spamhaus DBL and ivmURI.
        'URLBL1001' => 'spamdetected',  # The URL is listed on a Spamhaus blacklist. Check your status at Spamhaus.
    };
    state $messagesof = {
        'blocked' => [
            # - An email client has repeatedly sent bad commands or invalid passwords resulting in
            #   a three-hour block of the client's IP address.
            # - The sending IP address has exceeded the threshold of invalid recipients and has
            #   been blocked.
            'cox too many bad commands from',
            'too many invalid recipients',
        ],
        'requireptr' => [
            # - The reverse DNS check of the sending server IP address has failed.
            # - Cox requires that all connecting email servers contain valid reverse DNS PTR records.
            'dns check failure - try again later',
            'rejected - no rdns',
        ],
        'policyviolation' => [
            # - The sending server has attempted to communicate too soon within the SMTP transaction
            # - The message has been rejected because it contains an attachment with one of the
            #   following prohibited file types, which commonly contain viruses: .shb, .shs, .vbe,
            #   .vbs, .wsc, .wsf, .wsh, .pif, .msc, .msi, .msp, .reg, .sct, .bat, .chm, .isp, .cpl,
            #   .js, .jse, .scr, .exe.
            'esmtp no data before greeting',
            'attachment extension is forbidden',
        ],
        'rejected' => [
            # Cox requires that all sender domains resolve to a valid MX or A-record within DNS.
            'sender rejected',
        ],
        'systemerror' => [
            # - Our systems are experiencing an issue which is causing a temporary inability to
            #   accept new email.
            'esmtp server temporarily not available',
        ],
        'toomanyconn' => [
            # - The sending IP address has exceeded the five maximum concurrent connection limit.
            # - The SMTP connection has exceeded the 100 email message threshold and was disconnected.
            # - The sending IP address has exceeded one of these rate limits and has been temporarily
            #   blocked.
            'too many sessions from',
            'requested action aborted: try again later',
            'message threshold exceeded',
        ],
        'userunknown' => [
            # - The intended recipient is not a valid Cox Email account.
            'recipient rejected',
        ],
    };
    my $issuedcode = $argvs->{'diagnosticcode'};
    my $codenumber = $issuedcode =~ m/AUP#([0-9A-Z]+)/ ? $1 : 0;
    my $reasontext = $errorcodes->{ $codenumber } || '';

    unless( $reasontext ) {
        # The error code was not found in $errorcodes
        $issuedcode = lc $issuedcode;
        for my $e ( keys %$messagesof ) {
            # Try to find with each error message defined in $messagesof
            next unless grep { index($issuedcode, $_) > -1 } $messagesof->{ $e }->@*;
            $reasontext = $e;
            last;
        }
    }
    return $reasontext;
}

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai::Rhost::Cox - Detect the bounce reason returned from Cox

=head1 SYNOPSIS

    use Sisimai::Rhost::Cox;

=head1 DESCRIPTION

C<Sisimai::Rhost::Cox> detects the bounce reason from the content of C<Sisimai::Fact> object as an
argument of C<find()> method when the value of C<rhost> or C<destination> of the object is C<cox.net>.
This class is called only C<Sisimai::Fact> class.

=head1 CLASS METHODS

=head2 C<B<find(I<Sisimai::Fact Object>)>>

C<find()> method detects the bounce reason.

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2020-2025 azumakuniyuki, All rights reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut

