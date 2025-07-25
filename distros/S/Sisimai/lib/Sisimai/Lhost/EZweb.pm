package Sisimai::Lhost::EZweb;
use parent 'Sisimai::Lhost';
use v5.26;
use strict;
use warnings;

sub description { 'au EZweb: https://www.au.com/mobile/' }
sub inquire {
    # Detect an error from EZweb
    # @param    [Hash] mhead    Message headers of a bounce email
    # @param    [String] mbody  Message body of a bounce email
    # @return   [Hash]          Bounce data list and message/rfc822 part
    # @return   [undef]         failed to decode or the arguments are missing
    # @since v4.0.0
    my $class = shift;
    my $mhead = shift // return undef;
    my $mbody = shift // return undef;

    # Pre-process email headers of NON-STANDARD bounce message au by EZweb, as known as ezweb.ne.jp.
    #   Subject: Mail System Error - Returned Mail
    #   From: <Postmaster@ezweb.ne.jp>
    #   Received: from ezweb.ne.jp (wmflb12na02.ezweb.ne.jp [222.15.69.197])
    #   Received: from nmomta.auone-net.jp ([aaa.bbb.ccc.ddd]) by ...
    my $match = 0; $match++ if rindex($mhead->{'from'}, 'Postmaster@ezweb.ne.jp') > -1;
                   $match++ if rindex($mhead->{'from'}, 'Postmaster@au.com') > -1;
                   $match++ if $mhead->{'subject'} eq 'Mail System Error - Returned Mail';
                   $match++ if grep { rindex($_, 'ezweb.ne.jp (EZweb Mail) with') > -1 } $mhead->{'received'}->@*;
                   $match++ if grep { rindex($_, '.au.com (') > -1 } $mhead->{'received'}->@*;
    if( defined $mhead->{'message-id'} ) {
        $match++ if substr($mhead->{'message-id'}, -13, 13) eq '.ezweb.ne.jp>';
        $match++ if substr($mhead->{'message-id'}, -8, 8) eq '.au.com>';
    }
    return undef if $match < 2;

    require Sisimai::SMTP::Command;
    state $indicators = __PACKAGE__->INDICATORS;
    state $boundaries = ["--------------------------------------------------", "Content-Type: message/rfc822"];
    state $startingof = {"message" => ['The user(s) ', 'Your message ', 'Each of the following', '<']};
    state $messagesof = {
        #'notaccept'  => ['The following recipients did not receive this message:'],
        'expired' => [
            # Your message was not delivered within 0 days and 1 hours.
            # Remote host is not responding.
            'Your message was not delivered within ',
        ],
        'mailboxfull' => ['The user(s) account is temporarily over quota'],
        'onhold'  => ['Each of the following recipients was rejected by a remote mail server'],
        'suspend' => [
            # http://www.naruhodo-au.kddi.com/qa3429203.html
            # The recipient may be unpaid user...?
            'The user(s) account is disabled.',
            'The user(s) account is temporarily limited.',
        ],
    };

    my $fieldtable = Sisimai::RFC1894->FIELDTABLE;
    my $dscontents = [__PACKAGE__->DELIVERYSTATUS]; my $v = undef;
    my $emailparts = Sisimai::RFC5322->part($mbody, $boundaries);
    my $readcursor = 0;     # Points the current cursor position
    my $recipients = 0;     # The number of 'Final-Recipient' header
    my $substrings = [];    # All the values of "messagesof"
    map { push @$substrings, $messagesof->{ $_ }->@* } keys %$messagesof;

    for my $e ( split("\n", $emailparts->[0]) ) {
        # Read error messages and delivery status lines from the head of the email to the previous
        # line of the beginning of the original message.
        unless( $readcursor ) {
            # Beginning of the bounce message or message/delivery-status part
            $readcursor |= $indicators->{'deliverystatus'} if grep { index($e, $_) > -1 } $startingof->{'message'}->@*;
        }
        next if ($readcursor & $indicators->{'deliverystatus'}) == 0 || $e eq "";

        # The user(s) account is disabled.
        #
        # <***@ezweb.ne.jp>: 550 user unknown (in reply to RCPT TO command)
        #
        #  -- OR --
        # Each of the following recipients was rejected by a remote
        # mail server.
        #
        #    Recipient: <******@ezweb.ne.jp>
        #    >>> RCPT TO:<******@ezweb.ne.jp>
        #    <<< 550 <******@ezweb.ne.jp>: User unknown
        $v = $dscontents->[-1];

        if( Sisimai::String->aligned(\$e, ['<', '@', '>']) && (index($e, 'Recipient: <') > 1 || index($e, '<') == 0) ) {
            #    Recipient: <******@ezweb.ne.jp> OR <***@ezweb.ne.jp>: 550 user unknown ...
            my $p1 = index($e, '<');
            my $p2 = index($e, '>');

            if( $v->{'recipient'} ) {
                # There are multiple recipient addresses in the message body.
                push @$dscontents, __PACKAGE__->DELIVERYSTATUS;
                $v = $dscontents->[-1];
            }
            $v->{'recipient'}  = Sisimai::Address->s3s4(substr($e, $p1, $p2 - $p1));
            $v->{"diagnosis"} .= " ".$e;
            $recipients++;

        } elsif( my $f = Sisimai::RFC1894->match($e) ) {
            # $e matched with any field defined in RFC3464
            next unless my $o = Sisimai::RFC1894->field($e);
            next unless exists $fieldtable->{ $o->[0] };
            $v->{ $fieldtable->{ $o->[0] } } = $o->[2];

        } else {
            # The line does not begin with a DSN field defined in RFC3464
            next if Sisimai::String->is_8bit(\$e);
            if( index($e, " >>> ") > -1 ) {
                #    >>> RCPT TO:<******@ezweb.ne.jp>
                $v->{"command"} = Sisimai::SMTP::Command->find($e);
                $v->{"diagnosis"} .= " ".$e;

            } elsif( index($e, " <<< ") > -1 ) {
                # <<< 550 ...
                $v->{"diagnosis"} .= " ".$e;

            } else {
                # Check error message
                my $isincluded = 0;
                if( grep { index($e, $_) > -1 } @$substrings ) {
                    # Try to find that the line contains any error message text
                    $v->{"diagnosis"} .= ' '.$e;
                    $isincluded = 1;
                }
                $v->{"diagnosis"} .= " ".$e if $isincluded == 0;
            }
        } # End of error message part
    }
    return undef unless $recipients;

    for my $e ( @$dscontents ) {
        # Check each value of DeliveryMatter{}, try to detect the bounce reason.
        $e->{'diagnosis'} = Sisimai::String->sweep($e->{'diagnosis'});
        $e->{"command"} ||= Sisimai::SMTP::Command->find($e->{"diagnosis"}) || "";

        if( defined $mhead->{'x-spasign'} && $mhead->{'x-spasign'} eq 'NG' ) {
            # Content-Type: text/plain; ..., X-SPASIGN: NG (spamghetti, au by EZweb)
            # Filtered recipient returns message that include 'X-SPASIGN' header
            $e->{'reason'} = 'filtered';

        } else {
            # There is no X-SPASIGN header or the value of the header is not "NG"
            FINDREASON: for my $r ( keys %$messagesof ) {
                # Try to match with each session error message
                for my $f ( $messagesof->{ $r }->@* ) {
                    # Check each error message pattern
                    next unless index($e->{'diagnosis'}, $f) > -1;
                    $e->{'reason'} = $r;
                    last FINDREASON;
                }
            }
        }
        next if $e->{'reason'};
        next if index($e->{'recipient'}, '@ezweb.ne.jp') > 1 || index($e->{'recipient'}, '@au.com') > 1;
        $e->{"reason"} = "userunknown" if index($e->{"diagnosis"}, "<") == 0;
    }
    return {"ds" => $dscontents, "rfc822" => $emailparts->[1]};
}

1;
__END__
=encoding utf-8

=head1 NAME

Sisimai::Lhost::EZweb - bounce mail decoder class for au EZweb L<https://www.au.com/mobile/>.

=head1 SYNOPSIS

    use Sisimai::Lhost::EZweb;

=head1 DESCRIPTION

C<Sisimai::Lhost::EZweb> decodes a bounce email which created by au EZweb L<https://www.au.com/mobile/>.
Methods in the module are called from only C<Sisimai::Message>.

=head1 CLASS METHODS

=head2 C<B<description()>>

C<description()> returns description string of this module.

    print Sisimai::Lhost::EZweb->description;

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

