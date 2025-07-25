package Sisimai::Reason::MailboxFull;
use v5.26;
use strict;
use warnings;

sub text  { 'mailboxfull' }
sub description { "Email rejected due to a recipient's mailbox is full" }
sub match {
    # Try to match that the given text and regular expressions
    # @param    [String] argv1  String to be matched with regular expressions
    # @return   [Integer]       0: Did not match
    #                           1: Matched
    # @since v4.0.0
    my $class = shift;
    my $argv1 = shift // return 0;

    state $index = [
        '452 insufficient disk space',
        'account disabled temporarly for exceeding receiving limits',
        'account is exceeding their quota',
        'account is over quota',
        'account is temporarily over quota',
        'boite du destinataire pleine',
        'delivery failed: over quota',
        'disc quota exceeded',
        'diskspace quota',
        'does not have enough space',
        'exceeded storage allocation',
        'exceeding its mailbox quota',
        'full mailbox',
        'is over disk quota',
        'is over quota temporarily',
        'mail file size exceeds the maximum size allowed for mail delivery',
        'mail quota exceeded',
        'mailbox exceeded the local limit',
        'mailbox full',
        'mailbox has exceeded its disk space limit',
        'mailbox is full',
        'mailbox over quota',
        'mailbox quota usage exceeded',
        'mailbox size limit exceeded',
        'maildir over quota',
        'maildir delivery failed: userdisk quota ',
        'maildir delivery failed: domaindisk quota ',
        'mailfolder is full',
        'no space left on device',
        'not enough disk space',
        'not enough storage space in',
        'not sufficient disk space',
        'over the allowed quota',
        'quota exceeded',
        'quota violation for',
        'recipient reached disk quota',
        'recipient rejected: mailbox would exceed maximum allowed storage',
        'the recipient mailbox has exceeded its disk space limit',
        "the user's space has been used up",
        'the user you are trying to reach is over quota',
        'too much mail data',   # @docomo.ne.jp
        'user has exceeded quota, bouncing mail',
        'user has too many messages on the server',
        'user is over quota',
        'user is over the quota',
        'user over quota',
        'user over quota. (#5.1.1)',    # qmail-toaster
        'was automatically rejected: quota exceeded',
        'would be over the allowed quota',
    ];
    return 1 if grep { rindex($argv1, $_) > -1 } @$index;
    return 0;
}

sub true {
    # The envelope recipient's mailbox is full or not
    # @param    [Sisimai::Fact] argvs   Object to be detected the reason
    # @return   [Integer]               1: is mailbox full
    #                                   0: is not mailbox full
    # @since v4.0.0
    # @see http://www.ietf.org/rfc/rfc2822.txt
    my $class = shift;
    my $argvs = shift // return 0; return 0 unless $argvs->{'deliverystatus'};

    # Delivery status code points "mailboxfull".
    # Status: 4.2.2
    # Diagnostic-Code: SMTP; 450 4.2.2 <***@example.jp>... Mailbox Full
    return 1 if $argvs->{'reason'} eq 'mailboxfull';
    return 1 if (Sisimai::SMTP::Status->name($argvs->{'deliverystatus'}) || '') eq 'mailboxfull';
    return __PACKAGE__->match(lc $argvs->{'diagnosticcode'});
}

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai::Reason::MailboxFull - Bounce reason is C<mailboxfull> or not.

=head1 SYNOPSIS

    use Sisimai::Reason::MailboxFull;
    print Sisimai::Reason::MailboxFull->match('400 4.2.3 Mailbox full');   # 1

=head1 DESCRIPTION

C<Sisimai::Reason::MailboxFull> checks the bounce reason is C<mailboxfull> or not. This class is
called only C<Sisimai::Reason> class.

This is the error that the recipient's mailbox is full. Sisimai will set C<mailboxfull> to the reason
of the email bounce if the value of C<Status:> field in a bounce email is C<4.2.2> or C<5.2.2>.

    Action: failed
    Status: 5.2.2
    Diagnostic-Code: smtp;550 5.2.2 <kijitora@example.jp>... Mailbox Full

=head1 CLASS METHODS

=head2 C<B<text()>>

C<text()> method returns the fixed string C<mailboxfull>.

    print Sisimai::Reason::MailboxFull->text;  # mailboxfull

=head2 C<B<match(I<string>)>>

C<match()> method returns C<1> if the argument matched with patterns defined in this class.

    print Sisimai::Reason::MailboxFull->match('400 4.2.3 Mailbox full');   # 1

=head2 C<B<true(I<Sisimai::Fact>)>>

C<true()> method returns C<1> if the bounce reason is C<mailboxfull>. The argument must be C<Sisimai::Fact>
object and this method is called only from C<Sisimai::Reason> class.

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2014-2018,2020,2021,2024,2025 azumakuniyuki, All rights reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut

