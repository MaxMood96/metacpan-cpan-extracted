##----------------------------------------------------------------------------
## Stripe API - ~/lib/Net/API/Stripe/Payment/Source/CodeVerification.pm
## Version v0.100.0
## Copyright(c) 2019 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2019/11/02
## Modified 2020/05/15
## 
##----------------------------------------------------------------------------
package Net::API::Stripe::Payment::Source::CodeVerification;
BEGIN
{
    use strict;
    use warnings;
    use parent qw( Net::API::Stripe::Generic );
    use vars qw( $VERSION );
    our( $VERSION ) = 'v0.100.0';
};

use strict;
use warnings;

sub attempts_remaining { return( shift->_set_get_scalar( 'attempts_remaining', @_ ) ); }

sub status { return( shift->_set_get_scalar( 'status', @_ ) ); }

1;

__END__

=encoding utf8

=head1 NAME

Net::API::Stripe::Payment::Source::CodeVerification - A Stripe Code Verification Object

=head1 SYNOPSIS

    my $code = $stripe->source->code_verification({
        attempts_remaining => 2,
        status => 'pending',
    });

=head1 VERSION

    v0.100.0

=head1 DESCRIPTION

Information related to the code verification flow. Present if the source is authenticated by a verification code (flow is code_verification).

This is part of the L<Net::API::Stripe::Payment::Source> object

=head1 CONSTRUCTOR

=head2 new( %ARG )

Creates a new L<Net::API::Stripe::Payment::Source::CodeVerification> object.
It may also take an hash like arguments, that also are method of the same name.

=head1 METHODS

=head2 attempts_remaining integer

The number of attempts remaining to authenticate the source object with a verification code.

=head2 status string

The status of the code verification, either pending (awaiting verification, attempts_remaining should be greater than 0), succeeded (successful verification) or failed (failed verification, cannot be verified anymore as attempts_remaining should be 0).

=head1 API SAMPLE

    {
      "id": "src_fake123456789",
      "object": "source",
      "ach_credit_transfer": {
        "account_number": "test_52796e3294dc",
        "routing_number": "110000000",
        "fingerprint": "kabvkbmvbmbv",
        "bank_name": "TEST BANK",
        "swift_code": "TSTEZ122"
      },
      "amount": null,
      "client_secret": "src_client_secret_fake123456789",
      "created": 1571314413,
      "currency": "jpy",
      "flow": "receiver",
      "livemode": false,
      "metadata": {},
      "owner": {
        "address": null,
        "email": "jenny.rosen@example.com",
        "name": null,
        "phone": null,
        "verified_address": null,
        "verified_email": null,
        "verified_name": null,
        "verified_phone": null
      },
      "receiver": {
        "address": "121042882-38381234567890123",
        "amount_charged": 0,
        "amount_received": 0,
        "amount_returned": 0,
        "refund_attributes_method": "email",
        "refund_attributes_status": "missing"
      },
      "statement_descriptor": null,
      "status": "pending",
      "type": "ach_credit_transfer",
      "usage": "reusable"
    }

=head1 HISTORY

=head2 v0.1

Initial version

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 SEE ALSO

Stripe API documentation:

L<https://stripe.com/docs/api/sources/object>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2019-2020 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
