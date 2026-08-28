#!perl

use strict;
use warnings;
use feature qw/ signatures postderef /;

use Test::MockObject;
use Test::Most;
use Test::Warnings;
no warnings qw/ experimental::signatures experimental::postderef /;

use_ok( 'Business::Payr::Request' );

isa_ok(
    my $Request = Business::Payr::Request->new(
        _ua       => my $ua = Test::MockObject->new,
        api_token => 'test-server-api-token',
        api_host  => 'sandbox-api.mypayr.co.uk',
    ),
    'Business::Payr::Request'
);

is( $Request->api_token, 'test-server-api-token',    '->api_token' );
is( $Request->api_host,  'sandbox-api.mypayr.co.uk', '->api_host' );

# ---------------------------------------------------------------------------
# Set up a reusable mocked UA that tracks which response to serve via %status.
# Tests mutate %status before each call to simulate different API responses.
# ---------------------------------------------------------------------------

my %status = (
    code => 200,
    body => '{"message":"Users onboarded successfully"}',
    type => 'application/json',
);

$ua->mock( build_tx => sub ( $self, $method, $url, $headers, @ ) {

    is( ref $headers, 'HASH', 'headers are a hashref' );

    # Authorization header must always be "Token <api_token>"
    like(
        $headers->{Authorization},
        qr/\AToken /,
        'Authorization header uses Token scheme'
    );

    like(
        $headers->{Authorization},
        qr/test-server-api-token\z/,
        'Authorization header contains correct api_token'
    );

    # Content-Type must be set on all requests with a body
    is(
        $headers->{'Content-Type'},
        'application/json; charset=UTF-8',
        'Content-Type header is JSON'
    );

    my $response = Test::MockObject->new;
    $response->mock( result => sub {
        my $result = Test::MockObject->new;

        $result->mock( is_success => sub ( $self ) {
            $self->code =~ /\A2/;
        } );
        $result->mock( is_error => sub ( $self ) {
            $self->code =~ /\A[45]/;
        } );

        my $headers_mock = Test::MockObject->new;
        $headers_mock->set_always( content_type => $status{type} );
        $result->set_always( headers => $headers_mock );

        while ( my ( $method, $return ) = each %status ) {
            $result->set_always( $method, $return );
        }

        return $result;
    } );

    return $response;
} );

$ua->mock( start => sub ( $self, $tx ) { return $tx } );

# ---------------------------------------------------------------------------
# Happy-path tests
# ---------------------------------------------------------------------------

subtest '->api_post success' => sub {

    %status = (
        code => 201,
        body => '{"message":"Users onboarded successfully"}',
        type => 'application/json',
    );

    lives_ok(
        sub {
            cmp_deeply(
                $Request->api_post( '/onboarding/', { email => '[email protected]' } ),
                { message => 'Users onboarded successfully' },
                'api_post returns decoded JSON hashref'
            );
        },
        '->api_post lives on success'
    );
};

subtest '->api_post with no body' => sub {

    %status = (
        code => 200,
        body => '{"token":"newtoken123","old_token_expiry":"2024-01-22T14:30:00Z"}',
        type => 'application/json',
    );

    lives_ok(
        sub {
            my $res = $Request->api_post( '/rotate-token/' );
            is( $res->{token}, 'newtoken123', 'response token present' );
        },
        '->api_post without body lives on success'
    );
};

subtest '->api_post 204 No Content' => sub {

    %status = (
        code => 204,
        body => undef,
        type => undef,
    );

    lives_ok(
        sub {
            my $res = $Request->api_post( '/onboarding/', {} );
            ok( !defined $res, 'returns undef for 204 No Content' );
        },
        '->api_post 204 No Content lives and returns undef'
    );
};

# ---------------------------------------------------------------------------
# Failure tests
# ---------------------------------------------------------------------------

subtest 'failures' => sub {

    subtest '301 redirect loop' => sub {

        %status = (
            code    => 301,
            body    => '',
            type    => undef,
            message => 'Moved Permanently',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/\APayr POST .* failed > 5 levels of redirect/,
            '301 redirect loop throws a meaningful error'
        );
    };

    subtest 'no MIME type' => sub {

        %status = (
            code    => 200,
            body    => 'some plain text',
            type    => undef,
            message => 'OK',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 200 with no MIME type/,
            'missing Content-Type throws a meaningful error'
        );
    };

    subtest 'wrong MIME type' => sub {

        %status = (
            code    => 200,
            body    => 'some plain text',
            type    => 'text/plain',
            message => 'OK',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 200 text\/plain not JSON, status line: OK/,
            'non-JSON Content-Type throws a meaningful error'
        );
    };

    subtest 'empty body' => sub {

        %status = (
            code => 200,
            body => '',
            type => 'application/json',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 200 with an empty body/,
            'empty body throws a meaningful error'
        );
    };

    subtest 'malformed JSON' => sub {

        %status = (
            code => 200,
            body => 'this is not json at all',
            type => 'application/json',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 200 with malformed JSON/,
            'malformed JSON throws a meaningful error'
        );
    };

    subtest 'JSON array (not a hash)' => sub {

        %status = (
            code => 200,
            body => '[{"a":1},{"b":2}]',
            type => 'application/json',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 200 JSON ARRAY\(/,
            'JSON array response throws a meaningful error'
        );
    };

    subtest 'authentication error - detail key' => sub {

        %status = (
            code => 401,
            body => '{"detail":"Invalid token."}',
            type => 'application/json',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 401: Invalid token\./,
            '401 with detail key throws a meaningful error'
        );
    };

    subtest 'authentication error - credentials not provided' => sub {

        %status = (
            code => 401,
            body => '{"detail":"Authentication credentials were not provided."}',
            type => 'application/json',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 401: Authentication credentials were not provided\./,
            '401 missing credentials throws a meaningful error'
        );
    };

    subtest 'processing error - error key' => sub {

        %status = (
            code => 400,
            body => '{"error":"Failed to download agreement document from provided URL"}',
            type => 'application/json',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 400: Failed to download agreement document/,
            '400 with error key throws a meaningful error'
        );
    };

    subtest 'field-level validation errors' => sub {

        %status = (
            code => 400,
            body => '{"email":["This field is required."],"user_id":["This field is required."]}',
            type => 'application/json',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 400: .*This field is required/,
            '400 field-level validation errors throw a meaningful error'
        );
    };

    subtest 'nested validation errors (within tenant array)' => sub {

        %status = (
            code => 400,
            body => '{"tenant":[{"frequency":["\"weekly\" is not a valid choice."]}]}',
            type => 'application/json',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 400: .*tenant\.frequency.*is not a valid choice/,
            '400 nested tenant validation errors throw a meaningful error'
        );
    };

    subtest 'unknown JSON keys - fallback error' => sub {

        %status = (
            code    => 500,
            body    => '{"unexpected_key":"some_value","another_key":"data"}',
            type    => 'application/json',
            message => 'Internal Server Error',
        );

        throws_ok(
            sub { $Request->api_post( '/onboarding/', {} ) },
            qr/Payr POST .* returned 500 with JSON keys 'another_key', 'unexpected_key' and status line: Internal Server Error/,
            'unknown JSON error keys produce a meaningful fallback error'
        );
    };

    subtest '403 Forbidden' => sub {

        %status = (
            code    => 403,
            body    => '{"detail":"You do not have permission to perform this action."}',
            type    => 'application/json',
            message => 'Forbidden',
        );

        throws_ok(
            sub { $Request->api_post( '/rotate-token/' ) },
            qr/Payr POST .* returned 403: You do not have permission/,
            '403 Forbidden throws a meaningful error'
        );
    };
};

done_testing();

# vim: ts=4:sw=4:et
