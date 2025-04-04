use warnings;
use Test::More;
use strict;
use IO::String;
use JSON qw/from_json to_json/;

require 't/test-lib.pm';
my $maintests = 29;

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
                totp2fDigits           => 6,
                totp2fTTL              => -1,
                totp2fEncryptSecret    => 1,
                formTimeout            => 120,
                requireToken           => 1,
            }
        }
    );
    my $res;

    # Try to authenticate
    # -------------------
    ok( $res = $client->_get( '/', accept => 'text/html' ), 'Get Menu', );
    my ( $host, $url, $query ) =
      expectForm( $res, '#', undef, 'user', 'password', 'token' );

    $query =~ s/user=/user=dwho/;
    $query =~ s/password=/password=dwho/;
    ok(
        $res = $client->_post(
            '/',
            IO::String->new($query),
            length => length($query),
            accept => 'text/html',
        ),
        'Auth query'
    );
    my $id = expectCookie($res);
    expectRedirection( $res, 'http://auth.example.com/' );

    # TOTP form
    ok(
        $res = $client->_get(
            '/2fregisters',
            cookie => "lemonldap=$id",
            accept => 'text/html',
        ),
        'Form registration'
    );
    expectRedirection( $res, qr#/2fregisters/totp$# );
    ok(
        $res = $client->_get(
            '/2fregisters/totp',
            cookie => "lemonldap=$id",
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
            cookie => "lemonldap=$id",
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
            cookie => "lemonldap=$id",
            custom => {
                HTTP_X_CSRF_CHECK => 1,
            },
        ),
        'Post code'
    );
    eval { $res = JSON::from_json( $res->[2]->[0] ) };
    ok( not($@), 'Content is JSON' )
      or explain( $res->[2]->[0], 'JSON content' );
    ok( $res->{result} == 1, 'Key is registered' );

    # Try to sign-in
    $client->logout($id);

    ok( $res = $client->_get( '/', accept => 'text/html' ), 'Get Menu', );
    ( $host, $url, $query ) =
      expectForm( $res, '#', undef, 'user', 'password', 'token' );

    $query =~ s/user=/user=dwho/;
    $query =~ s/password=/password=dwho/;
    ok(
        $res = $client->_post(
            '/',
            IO::String->new($query),
            length => length($query),
            accept => 'text/html',
        ),
        'Auth query'
    );
    ( $host, $url, $query ) =
      expectForm( $res, undef, '/totp2fcheck', 'token' );

    # Generate TOTP with LLNG
    ok( $code = Lemonldap::NG::Common::TOTP::_code( undef, $key, 0, 30, 6 ),
        'LLNG Code' );

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

    # Try to sign-in with an expired OTT
    ok( $res = $client->_get( '/', accept => 'text/html' ), 'Get Menu', );
    ( $host, $url, $query ) =
      expectForm( $res, '#', undef, 'user', 'password', 'token' );

    $query =~ s/user=/user=dwho/;
    $query =~ s/password=/password=dwho/;
    ok(
        $res = $client->_post(
            '/',
            IO::String->new($query),
            length => length($query),
            accept => 'text/html',
        ),
        'Auth query'
    );
    ( $host, $url, $query ) =
      expectForm( $res, undef, '/totp2fcheck', 'token' );

    # Generate TOTP with LLNG
    ok( $code = Lemonldap::NG::Common::TOTP::_code( undef, $key, 0, 30, 6 ),
        'LLNG Code' );
    $query =~ s/code=/code=$code/;

    # Skipping time until form token expiration
    Time::Fake->offset("+5m");

    ok(
        $res = $client->_post(
            '/totp2fcheck', IO::String->new($query),
            length => length($query),
            accept => 'text/html',
        ),
        'Post code'
    );

    ok( $res->[2]->[0] =~ /<span trmsg="82"><\/span>/, 'Token expired' )
      or print STDERR Dumper( $res->[2]->[0] );
    unlike(
        $res->[2]->[0],
        qr/input id="userfield"/,
        'Login form is not displayed'
    );

    # Try to sign-in
    ok( $res = $client->_get( '/', accept => 'text/html' ), 'Get Menu', );
    ( $host, $url, $query ) =
      expectForm( $res, '#', undef, 'user', 'password', 'token' );

    $query =~ s/user=/user=dwho/;
    $query =~ s/password=/password=dwho/;
    ok(
        $res = $client->_post(
            '/',
            IO::String->new($query),
            length => length($query),
            accept => 'text/html',
        ),
        'Auth query'
    );
    ( $host, $url, $query ) =
      expectForm( $res, undef, '/totp2fcheck', 'token' );

    # Verify that TOTP secret is encrypted
    my $session    = getPSession("dwho");
    my $_2fDevices = $session->data->{_2fDevices};
    ok( $_2fDevices, "TOTP persistent data found" );
    $_2fDevices = from_json($_2fDevices);
    is( @{$_2fDevices}, 1, "Only one device found" );
    my $secret = $_2fDevices->[0]->{_secret};
    like( $secret, qr/^\{llngcrypt\}/, "TOTP secret is encrypted" );

}
count($maintests);

clean_sessions();

done_testing( count() );

