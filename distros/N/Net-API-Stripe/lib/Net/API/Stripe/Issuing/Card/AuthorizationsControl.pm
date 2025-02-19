##----------------------------------------------------------------------------
## Stripe API - ~/lib/Net/API/Stripe/Issuing/Card/AuthorizationsControl.pm
## Version v0.100.0
## Copyright(c) 2019 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2019/11/02
## Modified 2020/05/15
## 
##----------------------------------------------------------------------------
package Net::API::Stripe::Issuing::Card::AuthorizationsControl;
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

sub allowed_categories { return( shift->_set_get_array( 'allowed_categories', @_ ) ); }

sub blocked_categories { return( shift->_set_get_array( 'blocked_categories', @_ ) ); }

sub currency { return( shift->_set_get_scalar( 'currency', @_ ) ); }

sub max_amount { return( shift->_set_get_number( 'max_amount', @_ ) ); }

sub max_approvals { return( shift->_set_get_scalar( 'max_approvals', @_ ) ); }

sub spending_limits { return( shift->_set_get_object_array( 'spending_limits', 'Net::API::Stripe::Issuing::Card::AuthorizationsControl::SpendingLimit', @_ ) ); }

sub spending_limits_currency { return( shift->_set_get_scalar( 'spending_limits_currency', @_ ) ); }

1;

__END__

=encoding utf8

=head1 NAME

Net::API::Stripe::Issuing::Card::AuthorizationsControl - An interface to Stripe API

=head1 SYNOPSIS

    my $auth = $stripe->card_holder->authorization_controls({
        allowed_categories => [],
        blocked_categories => [],
        spending_limits => 
        [
            {
            amount => 2000000,
            categories => '',
            interval => 'monthly',
            },
            {
            amount => 200000,
            categories => '',
            interval => 'weekly',
            },
        ],
        spending_limits_currency => 'jpy',
    });

=head1 VERSION

    v0.100.0

=head1 DESCRIPTION

This is instantiated by method B<authorization_controls> in module L<Net::API::Stripe::Issuing::Card::Holder>

=head1 CONSTRUCTOR

=head2 new( %ARG )

Creates a new L<Net::API::Stripe::Issuing::Card::AuthorizationsControl> object.

=head1 METHODS

=head2 allowed_categories array

Array of strings containing categories of authorizations permitted on this card.

=head2 blocked_categories array

Array of strings containing categories of authorizations to always decline on this card.

=head2 spending_limits array of hashes

Limit the spending with rules based on time intervals and categories.

This is an array of L<Net::API::Stripe::Issuing::Card::AuthorizationsControl::SpendingLimit> objects.

=head2 spending_limits_currency currency

Currency for the amounts within spending_limits.

=head1 API SAMPLE

    {
      "id": "ich_fake123456789",
      "object": "issuing.cardholder",
      "authorization_controls": {
        "allowed_categories": [],
        "blocked_categories": [],
        "spending_limits": [],
        "spending_limits_currency": null
      },
      "billing": {
        "address": {
          "city": "Beverly Hills",
          "country": "US",
          "line1": "123 Fake St",
          "line2": "Apt 3",
          "postal_code": "90210",
          "state": "CA"
        },
        "name": "Jenny Rosen"
      },
      "company": null,
      "created": 1540111055,
      "email": "jenny@example.com",
      "individual": null,
      "is_default": false,
      "livemode": false,
      "metadata": {},
      "name": "Jenny Rosen",
      "phone_number": "+18008675309",
      "requirements": {
        "disabled_reason": null,
        "past_due": []
      },
      "status": "active",
      "type": "individual"
    }

=head1 HISTORY

=head2 v0.1

Initial version

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 SEE ALSO

Stripe API documentation:

L<https://stripe.com/docs/api/issuing/cardholders/object>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2019-2020 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
