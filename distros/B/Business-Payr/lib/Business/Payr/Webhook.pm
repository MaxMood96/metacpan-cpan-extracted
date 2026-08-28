package Business::Payr::Webhook;

=head1 NAME

Business::Payr::Webhook - class for verifying and parsing Payr webhook
notifications.

=head1 SYNOPSIS

    use Business::Payr::Webhook;

    # In your webhook endpoint handler:
    my $Webhook = Business::Payr::Webhook->new(
        body      => $raw_request_body,        # raw POST body string
        signature => $x_payr_signature_header, # X-Payr-Signature header value
        secret    => $webhook_secret,          # your Payr webhook secret
    );

    # Signature is verified during construction - an exception is thrown
    # if the signature does not match. Always wrap in eval / try:

    my $Payment = eval { $Webhook->resource };
    if ( $@ ) {
        warn "Webhook verification failed: $@";
        return http_response( 400 );
    }

    if ( $Payment->is_payment_success ) {
        my $amount_gbp = $Payment->amount / 100;
        printf "Received %.2f %s for student %s\n",
            $amount_gbp, $Payment->currency, $Payment->student_ref;

        if ( $Payment->schedule_activated ) {
            printf "Schedule %s activated; next instalment: %s\n",
                $Payment->schedule_id, $Payment->next_installment_date // 'N/A';
        }
    }
    elsif ( $Payment->is_payment_failed ) {
        warn sprintf "Payment %s failed (%s): %s\n",
            $Payment->payment_id,
            $Payment->error_code    // 'unknown',
            $Payment->error_message // 'no detail';
    }
    elsif ( $Payment->is_payment_pending ) {
        warn "Payment " . $Payment->payment_id
            . " is pending: " . ( $Payment->pending_reason // 'unknown reason' );
    }

=head1 DESCRIPTION

C<Business::Payr::Webhook> handles the receipt, cryptographic verification,
and parsing of webhook notifications sent by the Payr platform.

All webhooks are signed with HMAC-SHA256 using a secret shared between Payr
and your platform. The signature is carried in the C<X-Payr-Signature> HTTP
header. Verification is performed automatically during object construction; an
exception is thrown if the signature is missing, incorrect, or the payload
cannot be parsed.

B<Important:> You should always pass the B<raw request body> string as the
C<body> argument, before any deserialisation. Re-serialising a parsed
structure may produce different byte sequences and will cause verification to
fail.

Contact B<support@mypayr.co.uk> to configure your webhook endpoint URL and
receive your webhook secret.

=head1 SIGNATURE VERIFICATION DETAILS

Payr signs webhook payloads as follows:

=over

=item 1.

The JSON payload is serialised with compact separators (no spaces) and
lexicographically sorted keys.

=item 2.

An HMAC-SHA256 digest of the serialised payload is computed using the shared
webhook secret.

=item 3.

The hex-encoded digest is placed in the C<X-Payr-Signature> HTTP header.

=back

This module computes the same digest over the raw request body and compares
it against the header value using a constant-time comparison to prevent
timing attacks.

=head1 DEBUGGING

Set C<MOJO_CLIENT_DEBUG=1> for user agent and transport debug output when
fetching JWKS or other remote resources.

=cut

use strict;
use warnings;
use feature qw/ signatures /;

use Moose;
no warnings qw/ experimental::signatures /;

use namespace::autoclean;

use Carp                          qw/ croak confess /;
use Digest::SHA                   qw/ hmac_sha256_hex /;
use String::Compare::ConstantTime qw/ equals /;
use JSON;

use Business::Payr::Webhook::Payment;

=head1 ATTRIBUTES

=over

=item body (Str, required)

The raw (undecoded) HTTP request body string exactly as received from Payr.
Do B<not> deserialise and re-serialise this value before passing it in; the
signature is computed over the original byte sequence.

=item signature (Str, required)

The value of the C<X-Payr-Signature> HTTP header included in the webhook
request. This is a hex-encoded HMAC-SHA256 digest.

=item secret (Str, required)

Your Payr webhook signing secret. Keep this value secure and never expose it
in client-side code or version control. Contact B<support@mypayr.co.uk> to
obtain or rotate your secret.

=back

=cut

has [ qw/ body signature secret / ] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

# Parsed payload hashref, populated during BUILD.
# Exposed as rw so that tests can inject a pre-baked payload without
# going through full JSON parsing (mirrors the TrueLayer Webhook pattern).
has '_payload' => (
    is       => 'rw',
    isa      => 'HashRef',
    required => 0,
);

=head1 METHODS

=head2 BUILD

Called automatically by Moose after construction. Verifies the HMAC-SHA256
signature and decodes the JSON payload. Throws an exception if either step
fails.

You do not need to call this method directly.

=cut

sub BUILD ( $self, $args ) {
    $self->_verify_signature;
    $self->_decode_payload;
}

sub _verify_signature ( $self ) {

    my $expected = hmac_sha256_hex( $self->body, $self->secret );

    unless ( equals( $expected, $self->signature ) ) {
        croak "Payr webhook signature verification failed: "
            . "X-Payr-Signature header does not match the computed HMAC-SHA256 "
            . "digest. Ensure you are passing the raw (unmodified) request body "
            . "and the correct webhook secret.";
    }

    return $self;
}

sub _decode_payload ( $self ) {

    my $payload = eval { JSON->new->decode( $self->body ) };

    if ( $@ || ! defined $payload ) {
        croak "Payr webhook payload could not be decoded as JSON: $@";
    }

    unless ( ref $payload eq 'HASH' ) {
        croak "Payr webhook payload is not a JSON object";
    }

    $self->_payload( $payload );
    return $self;
}

=head2 event_type

Returns the C<event> field from the decoded webhook payload.

    my $type = $Webhook->event_type;
    # "payment_success", "payment_failed", or "payment_pending"

=cut

sub event_type ( $self ) {
    return $self->_payload->{event} // '';
}

=head2 is_payment_success

Returns C<1> if this webhook represents a C<payment_success> event, C<0>
otherwise.

    if ( $Webhook->is_payment_success ) { ... }

=cut

sub is_payment_success ( $self ) {
    return $self->event_type eq 'payment_success' ? 1 : 0;
}

=head2 is_payment_failed

Returns C<1> if this webhook represents a C<payment_failed> event, C<0>
otherwise.

    if ( $Webhook->is_payment_failed ) { ... }

=cut

sub is_payment_failed ( $self ) {
    return $self->event_type eq 'payment_failed' ? 1 : 0;
}

=head2 is_payment_pending

Returns C<1> if this webhook represents a C<payment_pending> event, C<0>
otherwise.

    if ( $Webhook->is_payment_pending ) { ... }

=cut

sub is_payment_pending ( $self ) {
    return $self->event_type eq 'payment_pending' ? 1 : 0;
}

=head2 resource

Parses the verified webhook payload and returns a
L<Business::Payr::Webhook::Payment> object populated with all fields from
the payload.

    my $Payment = $Webhook->resource;

Throws an exception if the payload has already been cleared or if required
fields are missing.

=cut

sub resource ( $self ) {

    my $payload = $self->_payload
        or confess "Payr::Webhook->resource called but no payload is available";

    return Business::Payr::Webhook::Payment->new( $payload->%* );
}

=head1 SEE ALSO

L<Business::Payr::Webhook::Payment>

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
