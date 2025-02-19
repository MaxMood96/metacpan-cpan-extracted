##----------------------------------------------------------------------------
## Stripe API - ~/lib/Net/API/Stripe/Order/DeliveryEstimate.pm
## Version v0.100.0
## Copyright(c) 2019 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2019/11/02
## Modified 2020/05/15
## 
##----------------------------------------------------------------------------
package Net::API::Stripe::Order::DeliveryEstimate;
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

sub date { return( shift->_set_get_datetime( 'date', @_ ) ); }

sub earliest { return( shift->_set_get_datetime( 'earliest', @_ ) ); }

sub latest { return( shift->_set_get_datetime( 'latest', @_ ) ); }

sub type { return( shift->_set_get_scalar( 'type', @_ ) ); }

1;

__END__

=encoding utf8

=head1 NAME

Net::API::Stripe::Order::DeliveryEstimate - A Stripe Order Delivery Estimate Object

=head1 SYNOPSIS

    my $delivery = $stripe->order->delivery_estimate({
        date => '2020-04-12',
        earlest => '2020-04-06',
        latest => '2020^04-30',
        type => 'range',
    });

=head1 VERSION

    v0.100.0

=head1 DESCRIPTION

The estimated delivery date for the given shipping method. Can be either a specific date or a range.

This is instantiated by method B<delivery_estimate> in module L<Net::API::Stripe::Order::ShippingMethod>

=head1 CONSTRUCTOR

=head2 new( %ARG )

Creates a new L<Net::API::Stripe::Order::DeliveryEstimate> object.
It may also take an hash like arguments, that also are method of the same name.

=head1 METHODS

=head2 date string

If type is "exact", date will be the expected delivery date in the format YYYY-MM-DD.

When set, this returns a C<DateTime> object.

=head2 earliest string

If type is "range", earliest will be be the earliest delivery date in the format YYYY-MM-DD.

When set, this returns a C<DateTime> object.

=head2 latest string

If type is "range", latest will be the latest delivery date in the format YYYY-MM-DD.

When set, this returns a C<DateTime> object.

=head2 type string

The type of estimate. Must be either "range" or "exact".

=head1 API SAMPLE

    {
      "id": "or_fake123456789",
      "object": "order",
      "amount": 1500,
      "amount_returned": null,
      "application": null,
      "application_fee": null,
      "charge": null,
      "created": 1571480453,
      "currency": "jpy",
      "customer": null,
      "email": null,
      "items": [
        {
          "object": "order_item",
          "amount": 1500,
          "currency": "jpy",
          "description": "T-shirt",
          "parent": "sk_fake123456789",
          "quantity": null,
          "type": "sku"
        }
      ],
      "livemode": false,
      "metadata": {},
      "returns": {
        "object": "list",
        "data": [],
        "has_more": false,
        "url": "/v1/order_returns?order=or_fake123456789"
      },
      "selected_shipping_method": null,
      "shipping": {
        "address": {
          "city": "Anytown",
          "country": "US",
          "line1": "1234 Main street",
          "line2": null,
          "postal_code": "123456",
          "state": null
        },
        "carrier": null,
        "name": "Jenny Rosen",
        "phone": null,
        "tracking_number": null
      },
      "shipping_methods": null,
      "status": "created",
      "status_transitions": {
        "canceled": null,
        "fulfiled": null,
        "paid": null,
        "returned": null
      },
      "updated": 1571480453
    }

=head1 HISTORY

=head2 v0.1

Initial version

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 SEE ALSO

Stripe API documentation:

L<https://stripe.com/docs/api/orders/object>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2019-2020 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
