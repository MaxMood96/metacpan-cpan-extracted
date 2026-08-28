# NAME

Business::Payr - Perl library for interacting with the Payr API ( https://docs.payr.com/ )

# VERSION

v0.01

# SYNOPSIS

```perl
my $Payr = Business::Payr->new(

    # required constructor argument
    api_token => $payr_server_api_token,

    # optional constructor arguments (with defaults shown)
    api_host    => 'api.mypayr.co.uk',
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

# Onboard multiple users in a single call
$Payr->onboard_user( [ \%user_one, \%user_two ] );

# Create a payment session for an already-onboarded user
my $Session = $Payr->create_payment_session( 'john.smith@example.com' );

# Embed the Payr payment iframe in your page
print $Session->iframe_html;

# Or with custom dimensions
print $Session->iframe_html( width => '80%', height => 800 );

# Access the raw session URL directly
my $url = $Session->url;

# Rotate the server API token (do this periodically for security)
my $rotation   = $Payr->rotate_token;
my $new_token  = $rotation->{token};
my $old_expiry = $rotation->{old_token_expiry};

# Handle incoming webhooks
use Business::Payr::Webhook;

my $Webhook = Business::Payr::Webhook->new(
    body      => $raw_request_body,        # raw POST body string
    signature => $x_payr_signature_header, # X-Payr-Signature header value
    secret    => $webhook_secret,          # your Payr webhook secret
);

# Signature is verified during construction - wrap in eval / try
my $Payment = eval { $Webhook->resource };
if ( $@ ) {
    warn "Webhook verification failed: $@";
    return http_response( 400 );
}

if ( $Payment->completed ) {
    printf "Payment %s completed: %.2f %s for student %s\n",
        $Payment->payment_id,
        $Payment->amount / 100,
        $Payment->currency,
        $Payment->student_ref;

    if ( $Payment->schedule_activated ) {
        printf "Schedule %s activated; next instalment: %s\n",
            $Payment->schedule_id,
            $Payment->next_installment_date // 'N/A';
    }
}
elsif ( $Payment->failed ) {
    warn sprintf "Payment %s failed (%s): %s\n",
        $Payment->payment_id,
        $Payment->error_code    // 'unknown',
        $Payment->error_message // 'no detail';
}
elsif ( $Payment->pending ) {
    warn "Payment " . $Payment->payment_id
        . " is pending: " . ( $Payment->pending_reason // 'unknown reason' );
}
```

# DESCRIPTION

`Business::Payr` is a client library for interacting with the Payr third-party
integration API. It handles the necessary authentication and transport logic,
allowing you to focus on just the endpoints you want to call.

Payr enables your users to pay their rent by card through an embedded payment
interface. With this library you can:

- **Onboard users** with their tenancy details and KYC documents
- **Create payment sessions** for seamless rent payments
- **Embed the payment iframe** directly into your platform
- **Rotate your server API token** for improved security
- **Verify and parse webhooks** for real-time payment notifications

The initial version of this distribution supports those steps described at
https://docs.payr.com/ and others will be added as necessary (pull
requests also welcome).

# ENVIRONMENTS

| Environment | API Base URL                                      | Iframe URL                    |
|-------------|---------------------------------------------------|-------------------------------|
| Sandbox     | `https://sandbox-api.mypayr.co.uk/thirdparty`     | `https://sandbox.mypayr.co.uk` |
| Production  | `https://api.mypayr.co.uk/thirdparty`             | `https://mypayr.co.uk`        |

Always test thoroughly in the sandbox environment before moving to production.

# DEBUGGING

Set `MOJO_CLIENT_DEBUG=1` for user agent and transport debug output.

# METHODS

## onboard_user

Onboard one or more users to the Payr platform with their tenancy details and
KYC documents. Calls the `/thirdparty/onboarding/` endpoint.

```perl
# Single user
$Payr->onboard_user( \%user_args );

# Batch onboarding
$Payr->onboard_user( [ \%user_one, \%user_two ] );
```

`$user_args` should be a hash reference (single user) or array reference of
hash references (multiple users) containing the fields described at
https://docs.payr.com/onboarding.

Required user fields: `user_id`, `email`, `first_name`, `last_name`,
`phone_number`, `date_of_birth`, `tenant` (array), `kyc` (object).

If a user already exists (matched by `user_id`), their information is updated.
If a tenancy already exists (matched by `user_id`, `start_rent_date`,
`payment_reference`, and `address_1`), only `end_rent_date`, `amount`, and
`frequency` can be updated.

Returns `1` on success. Throws an exception on failure with a descriptive error
message including any field-level validation errors returned by the API.

## create_payment_session

Creates a temporary payment session token for an already-onboarded user.
Calls the `/thirdparty/user-login/` endpoint.

```perl
my $Session = $Payr->create_payment_session( 'john.smith@example.com' );
```

The user identified by `$email` must have been previously onboarded via
`onboard_user`, otherwise a `400` error is thrown.

Returns a `Business::Payr::PaymentSession` object. The session URL embedded
in that object is valid for **15 minutes**. Pass it to `->iframe_html` to
generate the HTML snippet required to embed the Payr payment interface.

Any issues here will result in an exception being thrown.

## rotate_token

Generates a new server API token, replacing the current one. Calls the
`/thirdparty/rotate-token/` endpoint. The old token remains valid for a grace
period of 7–15 days, allowing you to update your systems without downtime.

```perl
my $rotation = $Payr->rotate_token;

my $new_token  = $rotation->{token};
my $old_expiry = $rotation->{old_token_expiry};
```

Returns a hash reference with keys `token` (the new token string) and
`old_token_expiry` (ISO 8601 datetime string). Any issues will result in an
exception being thrown.

# SEE ALSO

[Business::Payr::Request](lib/Business/Payr/Request.pm)

[Business::Payr::PaymentSession](lib/Business/Payr/PaymentSession.pm)

[Business::Payr::Webhook](lib/Business/Payr/Webhook.pm)

[Business::Payr::Webhook::Payment](lib/Business/Payr/Webhook/Payment.pm)

# AUTHORS

Lee Johnson - `leejo@cpan.org`

# LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation,
features, bug fixes, or anything else then please raise an issue / pull request:

```
https://github.com/payprop/business-payr
```
