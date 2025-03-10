##----------------------------------------------------------------------------
## Stripe API - ~/lib/Net/API/Stripe/Fraud.pm
## Version v0.101.0
## Copyright(c) 2019 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2019/11/02
## Modified 2022/10/29
## 
##----------------------------------------------------------------------------
package Net::API::Stripe::Fraud;
BEGIN
{
    use strict;
    use warnings;
    use parent qw( Net::API::Stripe::Generic );
    use vars qw( $VERSION );
    our( $VERSION ) = 'v0.101.0';
};

use strict;
use warnings;

sub id { return( shift->_set_get_scalar( 'id', @_ ) ); }

sub object { return( shift->_set_get_scalar( 'object', @_ ) ); }

sub actionable { return( shift->_set_get_boolean( 'actionable', @_ ) ); }

sub charge { return( shift->_set_get_scalar_or_object( 'charge', 'Net::API::Stripe::Charge', @_ ) ); }

sub created { return( shift->_set_get_datetime( 'created', @_ ) ); }

sub fraud_type { return( shift->_set_get_scalar( 'fraud_type', @_ ) ); }

sub livemode { return( shift->_set_get_boolean( 'livemode', @_ ) ); }

sub payment_intent { return( shift->_set_get_scalar_or_object( 'payment_intent', 'Net::API::Stripe::Payment::Intent', @_ ) ); }

1;

__END__

=encoding utf8

=head1 NAME

Net::API::Stripe::Fraud - A Stripe Early Fraud Warning Object

=head1 SYNOPSIS

    my $fraud = $stripe->fraud({
        actionable => $stripe->true,
        # Could also be a Net::API::Stripe::Charge object if expanded
        charge => 'ch_fake124567890',
        fraud_type => 'unauthorized_use_of_card',
        livemode => $stripe->false,
    });

See documentation in L<Net::API::Stripe> for example to make api calls to Stripe to create those objects.

=head1 VERSION

    v0.101.0

=head1 DESCRIPTION

An early fraud warning indicates that the card issuer has notified us that a charge may be fraudulent.

=head1 CONSTRUCTOR

=head2 new( %ARG )

Creates a new L<Net::API::Stripe::Fraud> object.
It may also take an hash like arguments, that also are method of the same name.

=head1 METHODS

=head2 id string

Unique identifier for the object.

=head2 object string, value is "radar.early_fraud_warning"

String representing the object’s type. Objects of the same type share the same value.

=head2 actionable boolean

An EFW is actionable if it has not received a dispute and has not been fully refunded. You may wish to proactively refund a charge that receives an EFW, in order to avoid receiving a dispute later.

=head2 charge string (expandable)

ID of the charge this early fraud warning is for, optionally expanded.

When expanded, this is a L<Net::API::Stripe::Charge> object.

=head2 created timestamp

Time at which the object was created. Measured in seconds since the Unix epoch.

=head2 fraud_type string

The type of fraud labelled by the issuer. One of card_never_received, fraudulent_card_application, made_with_counterfeit_card, made_with_lost_card, made_with_stolen_card, misc, unauthorized_use_of_card.

=head2 livemode boolean

Has the value true if the object exists in live mode or the value false if the object exists in test mode.

=head2 payment_intent expandable

ID of the Payment Intent this early fraud warning is for, optionally expanded.

When expanded this is an L<Net::API::Stripe::Payment::Intent> object.

=head1 API SAMPLE

    {
      "id": "issfr_123456789",
      "object": "radar.early_fraud_warning",
      "actionable": true,
      "charge": "ch_1234",
      "created": 123456789,
      "fraud_type": "misc",
      "livemode": false
    }

=head1 HISTORY

=head2 v0.1

Initial version

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 SEE ALSO

Stripe API documentation:

L<https://stripe.com/docs/api/radar/early_fraud_warnings/object>, L<https://stripe.com/docs/disputes#early-fraud-warnings-formerly-issuer-fraud-records>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2019-2020 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
