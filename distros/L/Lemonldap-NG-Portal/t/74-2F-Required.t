use warnings;
use Test::More;
use strict;
use IO::String;

require 't/test-lib.pm';
my $maintests = 18;

SKIP: {
    eval { require Convert::Base32 };
    if ($@) {
        skip 'Convert::Base32 is missing', $maintests;
    }
    require Lemonldap::NG::Common::TOTP;

    my $client = LLNG::Manager::Test->new( {
            ini => {
                logLevel               => 'error',
                totp2fSelfRegistration => 1,
                totp2fActivation       => 1,
                totp2fAuthnLevel       => 5,
                sfRequired             => 1,
                tokenUseGlobalStorage  => 1,
            }
        }
    );
    my $res;

    # Try to authenticate
    # -------------------
    ok(
        $res = $client->_post(
            '/',
            IO::String->new('user=dwho&password=dwho'),
            length => 23
        ),
        'Auth query'
    );
    expectRedirection( $res, qr'http://auth.example.com/+2fregisters/?' );
    my $pdata = 'lemonldappdata=' . expectCookie( $res, 'lemonldappdata' );
    ok( $res = $client->_get( '/2fregisters', cookie => $pdata ),
        'Follow redirection to /2fregisters' );
    ok( $res->[2]->[0] =~ m#/2fregisters/totp#, 'Found TOTP link' );

    # TOTP form
    ok(
        $res = $client->_get(
            '/2fregisters/totp',
            cookie => $pdata,
            accept => 'text/html',
        ),
        'Form registration'
    );
    ok( $res->[2]->[0] =~ /totpregistration\.(?:min\.)?js/, 'Found TOTP js' );

    # JS query
    ok(
        $res = $client->_post(
            '/2fregisters/totp/getkey',
            IO::String->new(''),
            cookie => $pdata,
            length => 0,
            custom => {
                HTTP_X_CSRF_CHECK => 1,
            },
        ),
        'Get new key'
    );
    eval { $res = JSON::from_json( $res->[2]->[0] ) };
    ok( not($@), 'Content is JSON' )
      or explain( $res->[2]->[0], 'JSON content' );
    my ( $key, $token );
    ok( $key   = $res->{secret}, 'Found secret' );
    ok( $token = $res->{token},  'Found token' );
    $key = Convert::Base32::decode_base32($key);

    # Post code
    my $code;
    ok( $code = Lemonldap::NG::Common::TOTP::_code( undef, $key, 0, 30, 6 ),
        'Code' );
    ok( $code =~ /^\d{6}$/, 'Code contains 6 digits' );
    my $s = "code=$code&token=$token";
    ok(
        $res = $client->_post(
            '/2fregisters/totp/verify',
            IO::String->new($s),
            length => length($s),
            cookie => $pdata,
            custom => {
                HTTP_X_CSRF_CHECK => 1,
            },
        ),
        'Post code'
    );
    $pdata = 'lemonldappdata=' . expectCookie( $res, 'lemonldappdata' );
    eval { $res = JSON::from_json( $res->[2]->[0] ) };
    ok( not($@), 'Content is JSON' )
      or explain( $res->[2]->[0], 'JSON content' );
    ok( $res->{result} == 1, 'Key is registered' );

    ok(
        $res = $client->_get(
            '/2fregisters',
            accept => "text/html",
            query  => "continue=1",
            cookie => $pdata,
        ),
        "Continue login"
    );

    # Make sure we are redirected to the portal with a correctly updated session
    expectRedirection( $res, qr'^http://auth.example.com/$' );
    my $id      = expectCookie($res);
    my $session = getSession($id);
    is( $session->{data}->{_2f},                 "totp" );
    is( $session->{data}->{authenticationLevel}, "5" );
    like( $session->{data}->{_2fDevices}, qr/TOTP/ );
    count(3);

    # Try to sign in normally
    ok(
        $res = $client->_post(
            '/',
            IO::String->new('user=dwho&password=dwho'),
            length => 23,
            accept => 'text/html',
        ),
        'Auth query'
    );
    my ( $host, $url, $query ) =
      expectForm( $res, undef, '/totp2fcheck', 'token' );
    ok( $code = Lemonldap::NG::Common::TOTP::_code( undef, $key, 0, 30, 6 ),
        'Code' );
    $query =~ s/code=/code=$code/;
    ok(
        $res = $client->_post(
            '/totp2fcheck', IO::String->new($query),
            length => length($query),
        ),
        'Post code'
    );
    $id = expectCookie($res);
    $client->logout($id);
}
count($maintests);

clean_sessions();

done_testing( count() );

