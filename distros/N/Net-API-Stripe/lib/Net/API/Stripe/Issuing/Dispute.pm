##----------------------------------------------------------------------------
## Stripe API - ~/lib/Net/API/Stripe/Issuing/Dispute.pm
## Version v0.100.0
## Copyright(c) 2019 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2019/11/02
## Modified 2020/05/15
## 
##----------------------------------------------------------------------------
## https://stripe.com/docs/api/issuing/disputes
package Net::API::Stripe::Issuing::Dispute;
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

sub id { return( shift->_set_get_scalar( 'id', @_ ) ); }

sub object { return( shift->_set_get_scalar( 'object', @_ ) ); }

sub amount { return( shift->_set_get_number( 'amount', @_ ) ); }

sub balance_transactions { return( shift->_set_get_array( 'balance_transactions', @_ ) ); }

sub created { return( shift->_set_get_datetime( 'created', @_ ) ); }

sub currency { return( shift->_set_get_scalar( 'currency', @_ ) ); }

sub disputed_transaction { return( shift->_set_get_scalar_or_object( 'disputed_transaction', 'Net::API::Stripe::Issuing::Transaction', @_ ) ); }

sub evidence { return( shift->_set_get_object( 'evidence', 'Net::API::Stripe::Issuing::Dispute::Evidence', @_ ) ); }

sub livemode { return( shift->_set_get_boolean( 'livemode', @_ ) ); }

sub metadata { return( shift->_set_get_hash( 'metadata', @_ ) ); }

sub reason { return( shift->_set_get_scalar( 'reason', @_ ) ); }

sub status { return( shift->_set_get_scalar( 'status', @_ ) ); }

sub transaction { return( shift->_set_get_scalar_or_object( 'transaction', 'Net::API::Stripe::Issuing::Transaction', @_ ) ); }

1;

__END__

=encoding utf8

=head1 NAME

Net::API::Stripe::Issuing::Dispute - A Stripe Issued Card Transaction Dispute Object

=head1 SYNOPSIS

    my $dispute = $stripe->issuing_dispute({
        amount => 2000,
        currency => 'jpy',
        disputed_transaction => $issuing_transaction_object,
        evidence => $dispute_evidence_object,
        livemode => $stripe->false,
        metadata => { transaction_id => 123 },
        reason => 'Something went wrong',
        status => 'lost',
    });

See documentation in L<Net::API::Stripe> for example to make api calls to Stripe to create those objects.

=head1 VERSION

    v0.100.0

=head1 DESCRIPTION

As a card issuer (L<https://stripe.com/docs/issuing>), you can dispute transactions (L<https://stripe.com/docs/issuing/disputes>) that you do not recognize, suspect to be fraudulent, or have some other issue.

This module looks similar to the L<Net::API::Stripe::Dispute> and has overlapping fields, but the B<event> method points to different modules, so it is by design that there are 2 <*::Dispute::Evidence> modules.

=head1 CONSTRUCTOR

=head2 new( %ARG )

Creates a new L<Net::API::Stripe::Issuing::Dispute> object.
It may also take an hash like arguments, that also are method of the same name.

=head1 METHODS

=head2 id string

Unique identifier for the object.

=head2 object string, value is "issuing.dispute"

String representing the object’s type. Objects of the same type share the same value.

=head2 amount integer

Disputed amount. Usually the amount of the disputed_transaction, but can differ (usually because of currency fluctuation or because only part of the order is disputed).

=head2 balance_transactions array

List of balance transactions associated with the dispute.

=head2 created timestamp

Time at which the object was created. Measured in seconds since the Unix epoch.

=head2 currency currency

The currency the disputed_transaction was made in.

=head2 disputed_transaction string (expandable)

The transaction being disputed.

When expanded, this is a L<Net::API::Stripe::Issuing::Transaction> object.

=head2 evidence hash

Evidence related to the dispute. This hash will contain exactly one non-null value, containing an evidence object that matches its reason

This is a L<Net::API::Stripe::Issuing::Dispute::Evidence> object.

=head2 livemode boolean

Has the value true if the object exists in live mode or the value false if the object exists in test mode.

=head2 metadata hash

Set of key-value pairs that you can attach to an object. This can be useful for storing additional information about the object in a structured format. Individual keys can be unset by posting an empty value to them. All keys can be unset by posting an empty value to metadata.

=head2 reason string

Reason for this dispute. One of other or fraudulent.

=head2 status string

Current status of dispute. One of lost, under_review, unsubmitted, or won.

=head2 transaction expandable

The transaction being disputed.

When expanded this is an L<Net::API::Stripe::Issuing::Transaction> object.

=head1 API SAMPLE

    {
      "id": "idp_fake123456789",
      "object": "issuing.dispute",
      "amount": 100,
      "created": 1571480456,
      "currency": "usd",
      "disputed_transaction": "ipi_fake123456789",
      "evidence": {
        "fraudulent": {
          "dispute_explanation": "Fraud; card reported lost on 10/19/2019",
          "uncategorized_file": null
        },
        "other": null
      },
      "livemode": false,
      "metadata": {},
      "reason": "fraudulent",
      "status": "under_review"
    }

=head1 HISTORY

=head2 v0.1

Initial version

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 SEE ALSO

Stripe API documentation:

L<https://stripe.com/docs/api/issuing/disputes>, L<https://stripe.com/docs/issuing/disputes>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2019-2020 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
