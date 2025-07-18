package Sisimai::Reason::ExceedLimit;
use v5.26;
use strict;
use warnings;

sub text  { 'exceedlimit' }
sub description { 'Email rejected due to an email exceeded the limit' }
sub match {
    # Try to match that the given text and regular expressions
    # @param    [String] argv1  String to be matched with regular expressions
    # @return   [Integer]       0: Did not match
    #                           1: Matched
    # @since v4.0.0
    my $class = shift;
    my $argv1 = shift // return 0;

    state $index = [
        'message header size exceeds limit',
        'message too large',
    ];
    return 1 if grep { rindex($argv1, $_) > -1 } @$index;
    return 0;
}

sub true {
    # Exceed limit or not
    # @param    [Sisimai::Fact] argvs   Object to be detected the reason
    # @return   [Integer]               1: Exceeds the limit
    #                                   0: Did not exceed the limit
    # @since v4.0.0
    # @see http://www.ietf.org/rfc/rfc2822.txt
    my $class = shift;
    my $argvs = shift // return 0; return 0 unless $argvs->{'deliverystatus'};

    # Delivery status code points "exceedlimit".
    # Status: 5.2.3
    # Diagnostic-Code: SMTP; 552 5.2.3 Message size exceeds fixed maximum message size
    return 1 if $argvs->{'reason'} eq 'exceedlimit';
    return 1 if (Sisimai::SMTP::Status->name($argvs->{'deliverystatus'}) || '') eq 'exceedlimit';
    return __PACKAGE__->match(lc $argvs->{'diagnosticcode'});
}

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai::Reason::ExceedLimit - Bounce reason is C<exceedlimit> or not.

=head1 SYNOPSIS

    use Sisimai::Reason::ExceedLimit;
    print Sisimai::Reason::ExceedLimit->match; # 0

=head1 DESCRIPTION

C<Sisimai::Reason::ExceedLimit> checks the bounce reason is C<exceedlimit> or not. This class is
called only C<Sisimai::Reason> class.

This is the error that a message was rejected due to an email exceeded the limit. The value of DSN
is C<5.2.3>. This reason is almost the same as C<MesgTooBig>, we think.

    ... while talking to mx.example.org.:
    >>> MAIL From:<kijitora@example.co.jp> SIZE=16600348
    <<< 552 5.2.3 Message size exceeds fixed maximum message size (10485760)
    554 5.0.0 Service unavailable

=head1 CLASS METHODS

=head2 C<B<text()>>

C<text()> method returns the fixed string C<exceedlimit>.

    print Sisimai::Reason::ExceedLimit->text;  # exceedlimit

=head2 C<B<match(I<string>)>>

C<match()> method returns C<1> if the argument matched with patterns defined in this class.

    print Sisimai::Reason::ExceedLimit->match; # 0;

=head2 C<B<true(I<Sisimai::Fact>)>>

C<true()> method returns C<1> if the bounce reason is C<exceedlimit>. The argument must be C<Sisimai::Fact>
object and this method is called only from C<Sisimai::Reason> class.

=head1 SEE ALSO

=over

=item L<Sisimai::Reason::MesgTooBig> - Sisimai::Reason::MesgTooBig

=back

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2014-2016,2018,2020,2021,2024,2025 azumakuniyuki, All rights reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut

