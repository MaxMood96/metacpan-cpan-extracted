package Business::Payr::Webhook::Payment;

=head1 NAME

Business::Payr::Webhook::Payment - class representing a Payr webhook
payment event, as received from the Payr webhook notification system.

=head1 SYNOPSIS

    my $Webhook = Business::Payr::Webhook->new(
        body      => $raw_request_body,
        signature => $x_payr_signature_header,
        secret    => $webhook_secret,
    );

    my $Payment = $Webhook->resource;

    if ( $Payment->completed ) {
        printf "Payment %s completed: %s %s\n",
            $Payment->payment_id,
            $Payment->currency,
            $Payment->amount;
    }

    if ( $Payment->failed ) {
        warn "Payment failed: " . $Payment->error_message;
    }

    if ( $Payment->pending ) {
        warn "Payment pending: " . $Payment->pending_reason;
    }

=head1 DESCRIPTION

A C<Business::Payr::Webhook::Payment> object is returned by
L<Business::Payr::Webhook/resource> after a webhook payload has been
verified and parsed. It provides typed access to all documented fields
across the three Payr payment event types (C<payment_success>,
C<payment_failed>, C<payment_pending>), as well as convenience status
and event-type predicate methods.

=cut

use strict;
use warnings;
use feature qw/ signatures /;

use Moose;
no warnings qw/ experimental::signatures /;

use namespace::autoclean;

=head1 ATTRIBUTES

The following attributes are common to all three payment event types.

=over

=item event (Str, required)

The event type string. One of C<payment_success>, C<payment_failed>,
or C<payment_pending>.

=item student_ref (Str, required)

Your external student / tenant reference, as supplied at onboarding.

=item payment_id (Str, required)

The Payr-assigned payment identifier.

=item amount (Int, required)

The payment amount in B<minor units> (pence). For example, C<85000>
represents £850.00.

=item currency (Str, required)

The ISO 4217 currency code (e.g. C<"GBP">).

=item timestamp (Str, required)

ISO 8601 timestamp of the event (e.g. C<"2024-09-01T12:00:00Z">).

=item payment_method (Str, required)

The payment method used (e.g. C<"card">).

=item transaction_id (Str, required)

The acquirer transaction ID. May be an empty string for failed or
pending events where no acquirer transaction was created.

=item status (Str, required)

The payment status. One of C<"completed">, C<"failed">, or C<"pending">.

=back

The following attributes are present only for C<payment_success> events.

=over

=item schedule_activated (Bool)

Whether a payment installment schedule was activated by this payment.

=item schedule_id (Str)

The schedule ID, present when C<schedule_activated> is C<true>.

=item next_installment_date (Str)

The next installment due date (C<YYYY-MM-DD>), or C<undef> if none.

=back

The following attributes are present only for C<payment_failed> events.

=over

=item error_code (Str)

A machine-readable error code (e.g. C<"card_declined">).

=item error_message (Str)

A human-readable description of the failure.

=back

The following attribute is present only for C<payment_pending> events.

=over

=item pending_reason (Str)

A string describing why the payment is pending (e.g.
C<"3ds_authentication_pending">).

=back

=cut

# --- Common fields (all event types) ---

has [ qw/ event student_ref payment_id currency timestamp payment_method transaction_id status / ] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'amount' => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

# --- event-specific optional fields (payment_success / payment_failed / payment_pending) ---

has 'schedule_activated' => (
    is       => 'ro',
    isa      => 'Maybe[Bool]',
    required => 0,
);

has [ qw/ schedule_id next_installment_date error_code error_message pending_reason / ] => (
    is       => 'ro',
    isa      => 'Maybe[Str]',
    required => 0,
);

=head1 METHODS

=head2 Status Methods

=head3 completed

=head3 failed

=head3 pending

Check whether the payment is in a given status:

    if ( $Payment->completed ) { ... }
    if ( $Payment->failed )    { ... }
    if ( $Payment->pending )   { ... }

Each returns C<1> if the C<status> attribute matches, C<0> otherwise.

=cut

sub completed { shift->_is_status( 'completed' ) }
sub failed    { shift->_is_status( 'failed'    ) }
sub pending   { shift->_is_status( 'pending'   ) }

sub _is_status ( $self, $status ) {
    return ( $self->status // '' ) eq $status ? 1 : 0;
}

=head2 Event Type Methods

=head3 is_payment_success

=head3 is_payment_failed

=head3 is_payment_pending

Check which type of payment event this object represents:

    if ( $Payment->is_payment_success ) { ... }
    if ( $Payment->is_payment_failed  ) { ... }
    if ( $Payment->is_payment_pending ) { ... }

Each returns C<1> if the C<event> attribute matches, C<0> otherwise.

=cut

sub is_payment_success { shift->_is_event( 'payment_success' ) }
sub is_payment_failed  { shift->_is_event( 'payment_failed'  ) }
sub is_payment_pending { shift->_is_event( 'payment_pending' ) }

sub _is_event ( $self, $event ) {
    return ( $self->event // '' ) eq $event ? 1 : 0;
}

=head1 SEE ALSO

L<Business::Payr::Webhook>

L<Business::Payr>

=head1 AUTHORS

Lee Johnson - C<leejo@cpan.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation,
features, bug fixes, or anything else then please raise an issue / pull request:

    https://github.com/payprop/business-payr

=cut

__PACKAGE__->meta->make_immutable;

1;

# vim: ts=4:sw=4:et
