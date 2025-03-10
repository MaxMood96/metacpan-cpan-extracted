##----------------------------------------------------------------------------
## Stripe API - ~/lib/Net/API/Stripe/Issuing/Authorization/RequestHistory.pm
## Version v0.201.0
## Copyright(c) 2020 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2019/11/02
## Modified 2020/11/29
## All rights reserved
## 
## This program is free software; you can redistribute  it  and/or  modify  it
## under the same terms as Perl itself.
##----------------------------------------------------------------------------
package Net::API::Stripe::Issuing::Authorization::RequestHistory;
BEGIN
{
    use strict;
    use warnings;
    use parent qw( Net::API::Stripe::Generic );
    use vars qw( $VERSION );
    our( $VERSION ) = 'v0.201.0';
};

use strict;
use warnings;

sub amount { return( shift->_set_get_number( 'amount', @_ ) ); }

sub amount_details { return( shift->_set_get_class( 'amount_details',
{
    atm_fee => { type => "number" }
}, @_ ) ); }

sub approved { return( shift->_set_get_boolean( 'approved', @_ ) ); }

sub authorized_amount { return( shift->_set_get_number( 'authorized_amount', @_ ) ); }

sub authorized_currency { return( shift->_set_get_scalar( 'authorized_currency', @_ ) ); }

sub created { return( shift->_set_get_datetime( 'created', @_ ) ); }

sub currency { return( shift->_set_get_scalar( 'currency', @_ ) ); }

sub held_amount { return( shift->_set_get_number( 'held_amount', @_ ) ); }

sub held_currency { return( shift->_set_get_scalar( 'held_currency', @_ ) ); }

sub merchant_amount { return( shift->_set_get_number( 'merchant_amount', @_ ) ); }

sub merchant_currency { return( shift->_set_get_scalar( 'merchant_currency', @_ ) ); }

sub reason { return( shift->_set_get_scalar( 'reason', @_ ) ); }

1;

__END__

=encoding utf8

=head1 NAME

Net::API::Stripe::Issuing::Authorization::RequestHistory - A Stripe Authorization History Request Object

=head1 SYNOPSIS

    my $req_history = $stripe->authorization->req_history({
        approved => $stripe->true,
        authorized_amount => 2000,
        authorized_currency => 'jpy',
        created => '2020-04-12',
        held_amount => 1000,
        held_currency => 'jpy',
        reason => 'webhook_declined',
    });

=head1 VERSION

    v0.201.0

=head1 DESCRIPTION

This is instantiated by method B<request_history> in module L<Net::API::Stripe::Issuing::Authorization>

=head1 CONSTRUCTOR

=head2 new( %ARG )

Creates a new L<Net::API::Stripe::Issuing::Authorization::RequestHistory> object.
It may also take an hash like arguments, that also are method of the same name.

=head1 METHODS

=head2 amount integer

The authorization amount in your card's currency and in the L<smallest currency unit|https://stripe.com/docs/currencies#zero-decimal>. Stripe held this amount from your account to fund the authorization if the request was approved.

=head2 amount_details hash

Detailed breakdown of amount components. These amounts are denominated in C<currency> and in the L<smallest currency unit|https://stripe.com/docs/currencies#zero-decimal>.

It has the following properties:

=over 4

=item I<atm_fee> integer

The fee charged by the ATM for the cash withdrawal.

=back

=head2 approved boolean

Whether this request was approved.

=head2 authorized_amount integer

The amount that was authorized at the time of this request

=head2 authorized_currency string

The currency that was presented to the cardholder for the authorization. Three-letter ISO currency code, in lowercase. Must be a supported currency.

=head2 created timestamp

Time at which the object was created. Measured in seconds since the Unix epoch.

=head2 currency string

Three-letter L<ISO currency code|https://www.iso.org/iso-4217-currency-codes.html>, in lowercase. Must be a L<supported currency|https://stripe.com/docs/currencies>.

=head2 held_amount integer

The amount Stripe held from your account to fund the authorization, if the request was approved

=head2 held_currency string

The currency of the held amount

=head2 merchant_amount integer

The amount that was authorized at the time of this request. This amount is in the C<merchant_currency> and in the L<smallest currency unit|https://stripe.com/docs/currencies#zero-decimal>.

=head2 merchant_currency string

The currency that was collected by the merchant and presented to the cardholder for the authorization. Three-letter L<ISO currency code|https://www.iso.org/iso-4217-currency-codes.html>, in lowercase. Must be a L<supported currency|https://stripe.com/docs/currencies>.

=head2 reason string

One of authentication_failed, authorization_controls, card_active, card_inactive, insufficient_funds, account_compliance_disabled, account_inactive, suspected_fraud, webhook_approved, webhook_declined, or webhook_timeout.

=head1 API SAMPLE

    {
      "id": "iauth_fake123456789",
      "object": "issuing.authorization",
      "approved": true,
      "authorization_method": "online",
      "authorized_amount": 500,
      "authorized_currency": "usd",
      "balance_transactions": [],
      "card": null,
      "cardholder": null,
      "created": 1540642827,
      "held_amount": 0,
      "held_currency": "usd",
      "is_held_amount_controllable": false,
      "livemode": false,
      "merchant_data": {
        "category": "taxicabs_limousines",
        "city": "San Francisco",
        "country": "US",
        "name": "Rocket Rides",
        "network_id": "1234567890",
        "postal_code": "94107",
        "state": "CA",
        "url": null
      },
      "metadata": {},
      "pending_authorized_amount": 0,
      "pending_held_amount": 0,
      "request_history": [],
      "status": "reversed",
      "transactions": [
        {
          "id": "ipi_fake123456789",
          "object": "issuing.transaction",
          "amount": -100,
          "authorization": "iauth_fake123456789",
          "balance_transaction": null,
          "card": "ic_fake123456789",
          "cardholder": null,
          "created": 1540642827,
          "currency": "usd",
          "dispute": null,
          "livemode": false,
          "merchant_amount": null,
          "merchant_currency": null,
          "merchant_data": {
            "category": "taxicabs_limousines",
            "city": "San Francisco",
            "country": "US",
            "name": "Rocket Rides",
            "network_id": "1234567890",
            "postal_code": "94107",
            "state": "CA",
            "url": null
          },
          "metadata": {},
          "type": "capture"
        },
        {
          "id": "ipi_fake123456789",
          "object": "issuing.transaction",
          "amount": -100,
          "authorization": "iauth_fake123456789",
          "balance_transaction": null,
          "card": "ic_fake123456789",
          "cardholder": null,
          "created": 1540642827,
          "currency": "usd",
          "dispute": null,
          "livemode": false,
          "merchant_amount": null,
          "merchant_currency": null,
          "merchant_data": {
            "category": "taxicabs_limousines",
            "city": "San Francisco",
            "country": "US",
            "name": "Rocket Rides",
            "network_id": "1234567890",
            "postal_code": "94107",
            "state": "CA",
            "url": null
          },
          "metadata": {},
          "type": "capture"
        }
      ],
      "verification_data": {
        "address_line1_check": "not_provided",
        "address_zip_check": "match",
        "authentication": "none",
        "cvc_check": "match"
      },
      "wallet_provider": null
    }

=head1 HISTORY

=head2 v0.1

Initial version

=head2 v0.2

Change helper method for B<approved> from B<_set_get_scalar> to B<_set_get_boolean>

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 SEE ALSO

Stripe API documentation:

L<https://stripe.com/docs/api>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2019-2020 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
