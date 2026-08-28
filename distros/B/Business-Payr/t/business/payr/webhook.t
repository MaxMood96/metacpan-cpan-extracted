#!perl

use strict;
use warnings;

use Test::Most;
use Test::Warnings;
use Digest::SHA qw/ hmac_sha256_hex /;
use JSON;

use_ok( 'Business::Payr::Webhook' );
use_ok( 'Business::Payr::Webhook::Payment' );

my $SECRET = 'test-webhook-secret-do-not-use-in-production';

# ---------------------------------------------------------------------------
# Helper: encode a payload hash canonically (sorted keys, compact) and
# return both the body string and its HMAC-SHA256 signature.  Using \1 and
# \0 for JSON true/false so the round-trip through JSON->canonical->encode
# produces the correct boolean literals.
# ---------------------------------------------------------------------------

sub _signed_payload {
    my (%payload) = @_;
    my $body      = JSON->new->canonical->encode( \%payload );
    my $signature = hmac_sha256_hex( $body, $SECRET );
    return ( $body, $signature );
}

# ---------------------------------------------------------------------------
# Shared test payload data (mirrors documented webhook payload examples)
# ---------------------------------------------------------------------------

my %success_payload = (
    event                 => 'payment_success',
    student_ref           => '12345',
    payment_id            => 'abc-123-def',
    amount                => 85000,
    currency              => 'GBP',
    timestamp             => '2024-09-01T12:00:00Z',
    payment_method        => 'card',
    transaction_id        => 'acq_txn_456',
    status                => 'completed',
    schedule_activated    => \1,
    schedule_id           => '01KH1G00N088163Y0H9WBJTT95',
    next_installment_date => '2024-12-15',
);

my %failed_payload = (
    event          => 'payment_failed',
    student_ref    => '12345',
    payment_id     => 'abc-123-ghi',
    amount         => 85000,
    currency       => 'GBP',
    timestamp      => '2024-09-01T12:05:00Z',
    payment_method => 'card',
    transaction_id => '',
    status         => 'failed',
    error_code     => 'card_declined',
    error_message  => 'Payment failed',
);

my %pending_payload = (
    event          => 'payment_pending',
    student_ref    => '12345',
    payment_id     => 'abc-123-jkl',
    amount         => 85000,
    currency       => 'GBP',
    timestamp      => '2024-09-01T12:03:00Z',
    payment_method => 'card',
    transaction_id => '',
    status         => 'pending',
    pending_reason => '3ds_authentication_pending',
);

# ---------------------------------------------------------------------------
# Construction and signature verification
# ---------------------------------------------------------------------------

subtest 'construction with valid payment_success signature' => sub {

    my ( $body, $sig ) = _signed_payload( %success_payload );

    isa_ok(
        my $Webhook = Business::Payr::Webhook->new(
            body      => $body,
            signature => $sig,
            secret    => $SECRET,
        ),
        'Business::Payr::Webhook',
    );

    ok( $Webhook->_payload, '->_payload is populated after construction' );
    is( ref $Webhook->_payload, 'HASH', '->_payload is a HASH ref' );
};

subtest 'construction fails with wrong signature' => sub {

    my ( $body, $sig ) = _signed_payload( %success_payload );

    throws_ok(
        sub {
            Business::Payr::Webhook->new(
                body      => $body,
                signature => 'deadbeef' x 8,   # wrong signature, correct length
                secret    => $SECRET,
            );
        },
        qr/signature verification failed/i,
        'wrong signature throws a meaningful error'
    );
};

subtest 'construction fails with tampered body' => sub {

    my ( $body, $sig ) = _signed_payload( %success_payload );

    # Tamper with the body after signing
    my $tampered = $body;
    $tampered =~ s/85000/99999/;

    throws_ok(
        sub {
            Business::Payr::Webhook->new(
                body      => $tampered,
                signature => $sig,
                secret    => $SECRET,
            );
        },
        qr/signature verification failed/i,
        'tampered body throws a meaningful error'
    );
};

subtest 'construction fails with wrong secret' => sub {

    my ( $body, $sig ) = _signed_payload( %success_payload );

    throws_ok(
        sub {
            Business::Payr::Webhook->new(
                body      => $body,
                signature => $sig,
                secret    => 'completely-wrong-secret',
            );
        },
        qr/signature verification failed/i,
        'wrong secret throws a meaningful error'
    );
};

subtest 'construction fails with non-JSON body (after forged signature)' => sub {

    my $body = 'this is not json';
    my $sig  = hmac_sha256_hex( $body, $SECRET );

    throws_ok(
        sub {
            Business::Payr::Webhook->new(
                body      => $body,
                signature => $sig,
                secret    => $SECRET,
            );
        },
        qr/could not be decoded as JSON/i,
        'non-JSON body (with valid signature) throws a meaningful error'
    );
};

subtest 'construction fails when JSON body is an array, not an object' => sub {

    my $body = '[{"event":"payment_success"}]';
    my $sig  = hmac_sha256_hex( $body, $SECRET );

    throws_ok(
        sub {
            Business::Payr::Webhook->new(
                body      => $body,
                signature => $sig,
                secret    => $SECRET,
            );
        },
        qr/not a JSON object/i,
        'JSON array body throws a meaningful error'
    );
};

# ---------------------------------------------------------------------------
# Event type predicates  - tested via ->_payload injection for clarity
# ---------------------------------------------------------------------------

subtest 'event type predicates - payment_success' => sub {

    my ( $body, $sig ) = _signed_payload( %success_payload );

    my $Webhook = Business::Payr::Webhook->new(
        body      => $body,
        signature => $sig,
        secret    => $SECRET,
    );

    ok(   $Webhook->is_payment_success, '->is_payment_success is true'  );
    ok( ! $Webhook->is_payment_failed,  '->is_payment_failed is false'  );
    ok( ! $Webhook->is_payment_pending, '->is_payment_pending is false' );

    is( $Webhook->event_type, 'payment_success', '->event_type returns correct string' );
};

subtest 'event type predicates - payment_failed' => sub {

    my ( $body, $sig ) = _signed_payload( %failed_payload );

    my $Webhook = Business::Payr::Webhook->new(
        body      => $body,
        signature => $sig,
        secret    => $SECRET,
    );

    ok( ! $Webhook->is_payment_success, '->is_payment_success is false' );
    ok(   $Webhook->is_payment_failed,  '->is_payment_failed is true'   );
    ok( ! $Webhook->is_payment_pending, '->is_payment_pending is false' );

    is( $Webhook->event_type, 'payment_failed', '->event_type returns correct string' );
};

subtest 'event type predicates - payment_pending' => sub {

    my ( $body, $sig ) = _signed_payload( %pending_payload );

    my $Webhook = Business::Payr::Webhook->new(
        body      => $body,
        signature => $sig,
        secret    => $SECRET,
    );

    ok( ! $Webhook->is_payment_success, '->is_payment_success is false' );
    ok( ! $Webhook->is_payment_failed,  '->is_payment_failed is false'  );
    ok(   $Webhook->is_payment_pending, '->is_payment_pending is true'  );

    is( $Webhook->event_type, 'payment_pending', '->event_type returns correct string' );
};

# ---------------------------------------------------------------------------
# ->resource returns a Business::Payr::Webhook::Payment object
# ---------------------------------------------------------------------------

subtest '->resource for payment_success' => sub {

    my ( $body, $sig ) = _signed_payload( %success_payload );

    my $Webhook = Business::Payr::Webhook->new(
        body      => $body,
        signature => $sig,
        secret    => $SECRET,
    );

    isa_ok(
        my $Payment = $Webhook->resource,
        'Business::Payr::Webhook::Payment',
        '->resource returns a Webhook::Payment object'
    );

    # Common fields
    is( $Payment->event,          'payment_success',            '->event'          );
    is( $Payment->student_ref,    '12345',                      '->student_ref'    );
    is( $Payment->payment_id,     'abc-123-def',                '->payment_id'     );
    is( $Payment->amount,         85000,                        '->amount'         );
    is( $Payment->currency,       'GBP',                        '->currency'       );
    is( $Payment->timestamp,      '2024-09-01T12:00:00Z',       '->timestamp'      );
    is( $Payment->payment_method, 'card',                       '->payment_method' );
    is( $Payment->transaction_id, 'acq_txn_456',                '->transaction_id' );
    is( $Payment->status,         'completed',                  '->status'         );

    # payment_success specific fields
    ok( $Payment->schedule_activated, '->schedule_activated is true' );
    is( $Payment->schedule_id,           '01KH1G00N088163Y0H9WBJTT95', '->schedule_id' );
    is( $Payment->next_installment_date, '2024-12-15',                 '->next_installment_date' );

    # Status predicates
    ok(   $Payment->completed, '->completed is true'  );
    ok( ! $Payment->failed,    '->failed is false'    );
    ok( ! $Payment->pending,   '->pending is false'   );

    # Event predicates on the Payment object
    ok(   $Payment->is_payment_success, '->is_payment_success is true'  );
    ok( ! $Payment->is_payment_failed,  '->is_payment_failed is false'  );
    ok( ! $Payment->is_payment_pending, '->is_payment_pending is false' );
};

subtest '->resource for payment_failed' => sub {

    my ( $body, $sig ) = _signed_payload( %failed_payload );

    my $Webhook = Business::Payr::Webhook->new(
        body      => $body,
        signature => $sig,
        secret    => $SECRET,
    );

    isa_ok(
        my $Payment = $Webhook->resource,
        'Business::Payr::Webhook::Payment',
        '->resource returns a Webhook::Payment object'
    );

    is( $Payment->event,          'payment_failed',       '->event'          );
    is( $Payment->status,         'failed',               '->status'         );
    is( $Payment->error_code,     'card_declined',        '->error_code'     );
    is( $Payment->error_message,  'Payment failed',       '->error_message'  );
    is( $Payment->transaction_id, '',                     '->transaction_id is empty string for failed' );

    ok( ! $Payment->completed, '->completed is false' );
    ok(   $Payment->failed,    '->failed is true'     );
    ok( ! $Payment->pending,   '->pending is false'   );

    ok( ! $Payment->is_payment_success, '->is_payment_success is false' );
    ok(   $Payment->is_payment_failed,  '->is_payment_failed is true'   );
    ok( ! $Payment->is_payment_pending, '->is_payment_pending is false' );
};

subtest '->resource for payment_pending' => sub {

    my ( $body, $sig ) = _signed_payload( %pending_payload );

    my $Webhook = Business::Payr::Webhook->new(
        body      => $body,
        signature => $sig,
        secret    => $SECRET,
    );

    isa_ok(
        my $Payment = $Webhook->resource,
        'Business::Payr::Webhook::Payment',
        '->resource returns a Webhook::Payment object'
    );

    is( $Payment->event,          'payment_pending',              '->event'          );
    is( $Payment->status,         'pending',                      '->status'         );
    is( $Payment->pending_reason, '3ds_authentication_pending',   '->pending_reason' );

    ok( ! $Payment->completed, '->completed is false' );
    ok( ! $Payment->failed,    '->failed is false'    );
    ok(   $Payment->pending,   '->pending is true'    );

    ok( ! $Payment->is_payment_success, '->is_payment_success is false' );
    ok( ! $Payment->is_payment_failed,  '->is_payment_failed is false'  );
    ok(   $Payment->is_payment_pending, '->is_payment_pending is true'  );
};

# ---------------------------------------------------------------------------
# Business::Payr::Webhook::Payment standalone construction
# ---------------------------------------------------------------------------

subtest 'Business::Payr::Webhook::Payment standalone construction' => sub {

    isa_ok(
        my $Payment = Business::Payr::Webhook::Payment->new(
            event          => 'payment_success',
            student_ref    => '99999',
            payment_id     => 'pay-standalone-001',
            amount         => 120000,
            currency       => 'GBP',
            timestamp      => '2024-10-01T09:00:00Z',
            payment_method => 'card',
            transaction_id => 'acq_standalone_001',
            status         => 'completed',
        ),
        'Business::Payr::Webhook::Payment',
        'can construct Webhook::Payment directly'
    );

    ok(   $Payment->completed,         '->completed is true'  );
    ok( ! $Payment->failed,            '->failed is false'    );
    ok( ! $Payment->pending,           '->pending is false'   );

    ok( ! defined $Payment->error_code,            '->error_code is undef when not set'            );
    ok( ! defined $Payment->error_message,         '->error_message is undef when not set'         );
    ok( ! defined $Payment->pending_reason,        '->pending_reason is undef when not set'        );
    ok( ! defined $Payment->schedule_activated,    '->schedule_activated is undef when not set'    );
    ok( ! defined $Payment->schedule_id,           '->schedule_id is undef when not set'           );
    ok( ! defined $Payment->next_installment_date, '->next_installment_date is undef when not set' );
};

subtest 'Business::Payr::Webhook::Payment construction requires mandatory fields' => sub {

    throws_ok(
        sub {
            Business::Payr::Webhook::Payment->new(
                # missing most required fields
                event => 'payment_success',
            );
        },
        qr/required/i,
        'construction with missing required fields throws an error'
    );
};

# ---------------------------------------------------------------------------
# _payload injection (mirrors TrueLayer Webhook pattern for testing convenience)
# ---------------------------------------------------------------------------

subtest '_payload injection for test convenience' => sub {

    my ( $body, $sig ) = _signed_payload( %success_payload );

    my $Webhook = Business::Payr::Webhook->new(
        body      => $body,
        signature => $sig,
        secret    => $SECRET,
    );

    # Override the payload directly (as in TrueLayer Webhook tests)
    $Webhook->_payload({
        event          => 'payment_failed',
        student_ref    => '00001',
        payment_id     => 'injected-pay-id',
        amount         => 50000,
        currency       => 'GBP',
        timestamp      => '2024-11-01T08:00:00Z',
        payment_method => 'card',
        transaction_id => '',
        status         => 'failed',
        error_code     => 'insufficient_funds',
        error_message  => 'Card declined: insufficient funds',
    });

    ok(   $Webhook->is_payment_failed,  '->is_payment_failed after injection'    );
    ok( ! $Webhook->is_payment_success, '->is_payment_success false after injection' );

    my $Payment = $Webhook->resource;
    is( $Payment->payment_id,    'injected-pay-id',                    '->payment_id from injected payload'    );
    is( $Payment->error_code,    'insufficient_funds',                 '->error_code from injected payload'    );
    is( $Payment->error_message, 'Card declined: insufficient funds',  '->error_message from injected payload' );
    ok( $Payment->failed, '->failed is true from injected payload' );
};

done_testing();

# vim: ts=4:sw=4:et
