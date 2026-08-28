package Business::Payr;

=head1 NAME

Business::Payr - Perl library for interacting with the Payr API
(https://docs.payr.com/)

=head1 VERSION

v0.02

=head1 SYNOPSIS

    my $Payr = Business::Payr->new(

        # required constructor argument
        api_token => $payr_server_api_token,

        # optional constructor arguments (with defaults shown)
        api_host   => 'api.mypayr.co.uk',
        iframe_host => 'mypayr.co.uk',
    );

    # For sandbox / testing use the sandbox hosts:
    my $Payr = Business::Payr->new(
        api_token   => $payr_sandbox_api_token,
        api_host    => 'sandbox-api.mypayr.co.uk',
        iframe_host => 'sandbox.mypayr.co.uk',
    );

    # Onboard a user with their tenancy details and KYC documents
    $Payr->onboard_user( \%user_args );

    # Create a payment session for an already-onboarded user
    my $Session = $Payr->create_payment_session( '[email protected]' );

    # Embed the payment iframe in your page
    print $Session->iframe_html;

    # Rotate the server API token (do this periodically for security)
    my $rotation = $Payr->rotate_token;
    my $new_token     = $rotation->{token};
    my $old_expiry    = $rotation->{old_token_expiry};

    # Handle incoming webhooks
    use Business::Payr::Webhook;

    my $Webhook = Business::Payr::Webhook->new(
        body      => $raw_request_body,
        signature => $x_payr_signature_header,
        secret    => $webhook_secret,
    );

    my $Payment = $Webhook->resource;

    if ( $Payment->completed ) {
        # Payment was successful
    }

=head1 DESCRIPTION

L<Business::Payr> is a client library for interacting with the Payr
third-party integration API (L<https://docs.payr.com/>). It handles the
necessary authentication and transport logic, allowing you to focus on just
the endpoints you want to call.

Payr enables your users to pay their rent by card through an embedded payment
interface. With this library you can:

=over

=item *

B<Onboard users> with their tenancy details and KYC documents

=item *

B<Create payment sessions> for seamless rent payments

=item *

B<Rotate your server API token> for improved security

=item *

B<Verify and parse webhooks> for real-time payment notifications (see
L<Business::Payr::Webhook>)

=back

The initial version of this distribution supports those steps described at
L<https://docs.payr.com/> and others will be added as necessary (pull
requests also welcome).

=head1 DEBUGGING

Set C<MOJO_CLIENT_DEBUG=1> for user agent and transport debug output.

=cut

use strict;
use warnings;
use feature qw/ signatures postderef /;

use Moose;
extends 'Business::Payr::Request';
no warnings qw/ experimental::signatures experimental::postderef /;

use namespace::autoclean;

use Business::Payr::PaymentSession;
use Carp qw/ croak /;

$Business::Payr::VERSION = '0.02';

=head1 METHODS

=head2 onboard_user

Onboard one or more users to the Payr platform with their tenancy details and
KYC documents. Calls the C</thirdparty/onboarding/> endpoint.

    # Single user
    $Payr->onboard_user( \%user_args );

    # Batch onboarding
    $Payr->onboard_user( [ \%user_one, \%user_two ] );

C<$user_args> should be a hash reference (single user) or array reference of
hash references (multiple users) containing the fields described at
L<https://docs.payr.com/onboarding>.

Required user fields: C<user_id>, C<email>, C<first_name>, C<last_name>,
C<phone_number>, C<date_of_birth>, C<tenant> (array), and B<either>
C<kyc> (object) B<or> C<agent_id> (integer).

The C<kyc> field is optional. When it is not provided, C<agent_id> must be
supplied instead - this is an integer reference to the agency associated with
the tenancy, similar in type to C<user_id>. Supplying neither will result in
an exception being thrown before any API call is made.

If a user already exists (matched by C<user_id>), their information is
updated. If a tenancy already exists (matched by C<user_id>,
C<start_rent_date>, C<payment_reference>, and C<address_1>), only
C<end_rent_date>, C<amount>, and C<frequency> can be updated.

Returns C<1> on success. Throws an exception on failure with a descriptive
error message including any field-level validation errors returned by the API.

=cut

sub onboard_user (
    $self,
    $user_args,
) {
    # Validate each user record before making the API call - this provides
    # clearer error messages than relying solely on the API's 400 responses.
    my @users = ref $user_args eq 'ARRAY' ? @{$user_args} : ( $user_args );
    $self->_validate_onboard_args( $_ ) for @users;

    $self->api_post( '/onboarding/', $user_args );
    return 1;
}

sub _validate_onboard_args ( $self, $user ) {

    unless ( exists $user->{kyc} || exists $user->{agent_id} ) {
        croak "onboard_user: each user must supply either 'kyc' (object) "
            . "or 'agent_id' (integer), but neither was found";
    }

    if ( exists $user->{agent_id} ) {
        my $agent_id = $user->{agent_id};
        unless (
            defined $agent_id
            && $agent_id =~ /\A[0-9]+\z/
            && $agent_id > 0
        ) {
            croak "onboard_user: 'agent_id' must be a positive integer, got: "
                . ( defined $agent_id ? "'$agent_id'" : 'undef' );
        }
    }

    return $self;
}

=head2 create_payment_session

Creates a temporary payment session token for an already-onboarded user.
Calls the C</thirdparty/user-login/> endpoint.

    my $Session = $Payr->create_payment_session( '[email protected]' );

The user identified by C<$email> must have been previously onboarded via
L</onboard_user>, otherwise a C<400> error is thrown.

Returns a L<Business::Payr::PaymentSession> object. The session URL embedded
in that object is valid for B<15 minutes>. Pass it to L<Business::Payr::PaymentSession/iframe_html>
to generate the HTML snippet required to embed the Payr payment interface:

    print $Session->iframe_html;

    # Or with custom dimensions:
    print $Session->iframe_html( width => '80%', height => 800 );

Any issues here will result in an exception being thrown.

=cut

sub create_payment_session (
    $self,
    $email,
) {
    my $response = $self->api_post(
        '/user-login/',
        { email => $email },
    );

    return Business::Payr::PaymentSession->new(
        url => $response->{url},
    );
}

=head2 rotate_token

Generates a new server API token, replacing the current one. Calls the
C</thirdparty/rotate-token/> endpoint. The old token remains valid for a
grace period of 7-15 days, allowing you to update your systems without
downtime.

    my $rotation = $Payr->rotate_token;

    my $new_token  = $rotation->{token};
    my $old_expiry = $rotation->{old_token_expiry};

Returns a hash reference with the following keys:

=over

=item token

The new server API token string. Update your configuration to use this
value before the old token's grace period expires.

=item old_token_expiry

An ISO 8601 datetime string indicating when the previous token will stop
working (e.g. C<"2024-01-22T14:30:00Z">).

=back

Any issues here will result in an exception being thrown.

=cut

sub rotate_token ( $self ) {
    my $response = $self->api_post( '/rotate-token/' );
    return {
        token            => $response->{token},
        old_token_expiry => $response->{old_token_expiry},
    };
}

=head1 SEE ALSO

L<Business::Payr::Request>

L<Business::Payr::PaymentSession>

L<Business::Payr::Webhook>

L<Business::Payr::Webhook::Payment>

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
