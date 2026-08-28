#!perl

use strict;
use warnings;

use Test::Most;
use Test::Warnings;

use_ok( 'Business::Payr::PaymentSession' );

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

subtest 'construction with required attributes' => sub {

    isa_ok(
        my $Session = Business::Payr::PaymentSession->new(
            url => 'https://sandbox.mypayr.co.uk/third-party?token=abc123&session_id=def456',
        ),
        'Business::Payr::PaymentSession',
    );

    is(
        $Session->url,
        'https://sandbox.mypayr.co.uk/third-party?token=abc123&session_id=def456',
        '->url stores the full session URL'
    );
};

subtest 'construction fails without url' => sub {

    throws_ok(
        sub { Business::Payr::PaymentSession->new() },
        qr/required/i,
        'construction without url throws an error'
    );
};

# ---------------------------------------------------------------------------
# ->iframe_html  - default dimensions
# ---------------------------------------------------------------------------

subtest '->iframe_html default dimensions' => sub {

    my $Session = Business::Payr::PaymentSession->new(
        url => 'https://sandbox.mypayr.co.uk/third-party?token=tok1&session_id=sid1',
    );

    my $html = $Session->iframe_html;

    ok( defined $html && length $html, '->iframe_html returns a non-empty string' );

    like(
        $html,
        qr{<iframe\b},
        '->iframe_html opens with an <iframe> tag'
    );

    like(
        $html,
        qr{</iframe>},
        '->iframe_html closes with </iframe>'
    );

    like(
        $html,
        qr{src="https://sandbox\.mypayr\.co\.uk/third-party\?token=tok1&session_id=sid1"},
        '->iframe_html src attribute contains the session URL'
    );

    like(
        $html,
        qr{width="100%"},
        '->iframe_html default width is 100%'
    );

    like(
        $html,
        qr{height="700"},
        '->iframe_html default height is 700'
    );

    like(
        $html,
        qr{frameborder="0"},
        '->iframe_html sets frameborder="0"'
    );

    like(
        $html,
        qr{allow="payment"},
        '->iframe_html sets allow="payment"'
    );
};

# ---------------------------------------------------------------------------
# ->iframe_html  - custom dimensions
# ---------------------------------------------------------------------------

subtest '->iframe_html custom width and height' => sub {

    my $Session = Business::Payr::PaymentSession->new(
        url => 'https://mypayr.co.uk/third-party?token=prodtok&session_id=prodsid',
    );

    my $html = $Session->iframe_html( width => '80%', height => 900 );

    like(
        $html,
        qr{width="80%"},
        '->iframe_html respects custom width'
    );

    like(
        $html,
        qr{height="900"},
        '->iframe_html respects custom height'
    );

    # The URL must still be present unchanged
    like(
        $html,
        qr{src="https://mypayr\.co\.uk/third-party\?token=prodtok&session_id=prodsid"},
        '->iframe_html src is unchanged when custom dimensions are given'
    );
};

subtest '->iframe_html custom width only' => sub {

    my $Session = Business::Payr::PaymentSession->new(
        url => 'https://sandbox.mypayr.co.uk/third-party?token=t&session_id=s',
    );

    my $html = $Session->iframe_html( width => '50%' );

    like( $html, qr{width="50%"},  '->iframe_html custom width applied' );
    like( $html, qr{height="700"}, '->iframe_html height still defaults to 700' );
};

subtest '->iframe_html custom height only' => sub {

    my $Session = Business::Payr::PaymentSession->new(
        url => 'https://sandbox.mypayr.co.uk/third-party?token=t&session_id=s',
    );

    my $html = $Session->iframe_html( height => 1200 );

    like( $html, qr{width="100%"},  '->iframe_html width still defaults to 100%' );
    like( $html, qr{height="1200"}, '->iframe_html custom height applied' );
};

# ---------------------------------------------------------------------------
# ->iframe_html  - URL preservation
# ---------------------------------------------------------------------------

subtest '->iframe_html preserves URL query parameters' => sub {

    my $url = 'https://sandbox.mypayr.co.uk/third-party'
            . '?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
            . '&session_id=01ARZ3NDEKTSV4RRFFQ69G5FAV';

    my $Session = Business::Payr::PaymentSession->new( url => $url );
    my $html    = $Session->iframe_html;

    like(
        $html,
        qr{\Qsrc="$url"\E},
        '->iframe_html preserves full URL including all query parameters'
    );
};

subtest '->iframe_html production URL' => sub {

    my $Session = Business::Payr::PaymentSession->new(
        url => 'https://mypayr.co.uk/third-party?token=live_tok&session_id=live_sid',
    );

    my $html = $Session->iframe_html;

    like(
        $html,
        qr{src="https://mypayr\.co\.uk/third-party},
        '->iframe_html works with production URL'
    );
};

done_testing();

# vim: ts=4:sw=4:et
