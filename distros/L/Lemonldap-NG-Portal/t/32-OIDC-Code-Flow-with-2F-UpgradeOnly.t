use warnings;
use Test::More;
use strict;
use IO::String;
use LWP::UserAgent;
use LWP::Protocol::PSGI;
use MIME::Base64;

BEGIN {
    require 't/test-lib.pm';
    require 't/oidc-lib.pm';
}

my $debug = 'error';
my ( $op, $rp, $res );

my $access_token;

LWP::Protocol::PSGI->register(
    sub {
        my $req = Plack::Request->new(@_);
        ok( $req->uri =~ m#http://auth.((?:o|r)p).com(.*)#, ' REST request' );
        my $host = $1;
        my $url  = $2;
        my ( $res, $client );
        count(1);
        if ( $host eq 'op' ) {
            pass("  Request from RP to OP,     endpoint $url");
            $client = $op;
        }
        elsif ( $host eq 'rp' ) {
            pass('  Request from OP to RP');
            $client = $rp;
        }
        else {
            fail('  Aborting REST request (external)');
            return [ 500, [], [] ];
        }
        if ( $req->method =~ /^post$/i ) {
            my $s = $req->content;
            ok(
                $res = $client->_post(
                    $url, IO::String->new($s),
                    length => length($s),
                    type   => $req->header('Content-Type'),
                ),
                '  Execute request'
            );
        }
        else {
            ok(
                $res = $client->_get(
                    $url,
                    custom => {
                        HTTP_AUTHORIZATION => $req->header('Authorization'),
                    }
                ),
                '  Execute request'
            );
        }
        ok( $res->[0] == 200, '  Response is 200' );
        ok( getHeader( $res, 'Content-Type' ) =~ m#^application/json#,
            '  Content is JSON' )
          or explain( $res->[1], 'Content-Type => application/json' );
        count(4);
        if ( $res->[2]->[0] =~ /"access_token":"(.*?)"/ ) {
            $access_token = $1;
            pass "Found access_token $access_token";
            count(1);
        }
        return $res;
    }
);

# Initialization
ok( $op = register( 'op', sub { op() } ), 'OP portal' );

ok( $res = $op->_get('/oauth2/jwks'), 'Get JWKS,     endpoint /oauth2/jwks' );
expectOK($res);
my $jwks = $res->[2]->[0];

ok(
    $res = $op->_get('/.well-known/openid-configuration'),
    'Get metadata, endpoint /.well-known/openid-configuration'
);
expectOK($res);
my $metadata = $res->[2]->[0];
count(3);

###### FIRST TEST #####################
# Authenticate to OP at low level, then
# upgrade with 2FA

# Authenticate to OP, 2FA not required
my $query = "user=french&password=french";
ok(
    $res = $op->_post(
        '/',
        IO::String->new($query),
        accept => 'text/html',
        length => length($query),
    ),
    "Post authentication with no target auth level",
);
count(1);
my $idpId = expectCookie($res);

&Lemonldap::NG::Handler::Main::cfgNum( 0, 0 );
ok( $rp = register( 'rp', sub { rp( $jwks, $metadata ) } ), 'RP portal' );
count(1);

# Query RP for auth
ok( $res = $rp->_get( '/', accept => 'text/html' ), 'Unauth SP request' );
count(1);
( my $url, $query ) =
  expectRedirection( $res, qr#http://auth.op.com(/oauth2/authorize)\?(.*)$# );

# Push request to OP
ok(
    $res = $op->_get(
        $url,
        query  => $query,
        accept => 'text/html',
        cookie => "lemonldap=$idpId",
    ),
    "Push request to OP,         endpoint $url"
);
count(1);
expectOK($res);
my $pdata = expectCookie( $res, 'lemonldappdata' );

# OP should offer to upgrade the session
( my $host, $url, $query ) =
  expectForm( $res, undef, '/upgradesession', 'confirm', 'url' );

ok(
    $res = $op->_post(
        '/upgradesession',
        IO::String->new($query),
        length => length($query),
        accept => 'text/html',
        cookie => "lemonldap=$idpId;lemonldappdata=$pdata",
    ),
    'Post code'
);
count(1);

$pdata = expectCookie( $res, 'lemonldappdata' );

# Prompt for 2FA
( $host, $url, $query ) =
  expectForm( $res, undef, '/ext2fcheck?skin=bootstrap', 'token', 'code',
    'checkLogins' );

ok(
    $res->[2]->[0] =~
qr%<input name="code" value="" type="text" class="form-control" id="extcode" trplaceholder="code" autocomplete="one-time-code" />%,
    'Found EXTCODE input'
) or print STDERR Dumper( $res->[2]->[0] );
count(1);

$query =~ s/code=/code=123456/;

ok(
    $res = $op->_post(
        '/ext2fcheck',
        IO::String->new($query),
        length => length($query),
        accept => 'text/html',
        cookie => "lemonldap=$idpId;lemonldappdata=$pdata",
    ),
    'Post code'
);
count(1);

$pdata = expectCookie( $res, 'lemonldappdata' );
($url) = expectRedirection( $res, qr#http://auth.op.com(/?/oauth2.*)# );

ok(
    $res = $op->_get(
        "$url",
        accept => 'text/html',
        cookie => "lemonldap=$idpId; lemonldappdata=$pdata",
    ),
    "Follow redirection to Oauth2 issuer"
);
count(1);

$pdata = expectCookie( $res, 'lemonldappdata' );
is( $pdata, '', "Pdata was cleared" );
count(1);

( $host, $url, $query ) =
  expectForm( $res, undef, qr#/oauth2/authorize.*#, 'confirm' );

ok(
    $res = $op->_post(
        '/oauth2/authorize',
        IO::String->new($query),
        accept => 'text/html',
        cookie => "lemonldap=$idpId",
        length => length($query),
    ),
    "Post confirmation,          endpoint $url"
);
count(1);

($query) = expectRedirection( $res, qr#^http://auth.rp.com/?\?(.*)$# );

# Push OP response to RP

ok( $res = $rp->_get( '/', query => $query, accept => 'text/html' ),
    'Call openidconnectcallback on RP' );
count(1);
my $spId = expectCookie($res);

ok( $res = $rp->_get( '/', cookie => "lemonldap=$spId" ), 'Get / on SP' );
count(1);
expectOK($res);
expectAuthenticatedAs( $res, 'french' );

###### SECOND TEST #####################
# Authenticate to secure RP immediately

# Query RP for auth
ok( $res = $rp->_get( '/', accept => 'text/html' ), 'Unauth SP request' );
count(1);
( $url, $query ) =
  expectRedirection( $res, qr#http://auth.op.com(/oauth2/authorize)\?(.*)$# );

# Push request to OP
ok( $res = $op->_get( $url, query => $query, accept => 'text/html' ),
    "Push request to OP,         endpoint $url" );
count(1);
expectOK($res);
$pdata = expectCookie( $res, 'lemonldappdata' );

# Try to authenticate to OP
$query = "user=french&password=french&$query";
ok(
    $res = $op->_post(
        $url,
        IO::String->new($query),
        accept => 'text/html',
        length => length($query),
        cookie => "lemonldappdata=$pdata",
    ),
    "Post authentication,        endpoint $url"
);
count(1);

$pdata = expectCookie( $res, 'lemonldappdata' );

( $host, $url, $query ) =
  expectForm( $res, undef, '/ext2fcheck?skin=bootstrap', 'token', 'code',
    'checkLogins' );

ok(
    $res->[2]->[0] =~
qr%<input name="code" value="" type="text" class="form-control" id="extcode" trplaceholder="code" autocomplete="one-time-code" />%,
    'Found EXTCODE input'
) or print STDERR Dumper( $res->[2]->[0] );
count(1);

$query =~ s/code=/code=123456/;

ok(
    $res = $op->_post(
        '/ext2fcheck',
        IO::String->new($query),
        length => length($query),
        accept => 'text/html',
        cookie => "lemonldappdata=$pdata",
    ),
    'Post code'
);
count(1);

$idpId = expectCookie($res);
$pdata = expectCookie( $res, 'lemonldappdata' );
($url) = expectRedirection( $res, qr#http://auth.op.com(/?/oauth2)# );

ok(
    $res = $op->_get(
        "$url",
        accept => 'text/html',
        cookie => "lemonldap=$idpId; lemonldappdata=$pdata",
    ),
    "Follow redirection to Oauth2 issuer"
);
count(1);

$pdata = expectCookie( $res, 'lemonldappdata' );
is( $pdata, '', "Pdata was cleared" );
count(1);

($query) = expectRedirection( $res, qr#^http://auth.rp.com/?\?(.*)$# );

# Push OP response to RP

ok( $res = $rp->_get( '/', query => $query, accept => 'text/html' ),
    'Call openidconnectcallback on RP' );
count(1);
$spId = expectCookie($res);

ok( $res = $rp->_get( '/', cookie => "lemonldap=$spId" ), 'Get / on SP' );
count(1);
expectOK($res);
expectAuthenticatedAs( $res, 'french' );

clean_sessions();
done_testing( count() );

sub op {
    return LLNG::Manager::Test->new(
        {
            ini => {
                logLevel                        => $debug,
                domain                          => 'idp.com',
                portal                          => 'http://auth.op.com/',
                authentication                  => 'Demo',
                userDB                          => 'Same',
                issuerDBOpenIDConnectActivation => 1,
                sfOnlyUpgrade                   => 1,
                ext2fActivation                 => 1,
                ext2fAuthnLevel                 => 5,
                ext2fCodeActivation             => '123456',
                ext2FSendCommand                => 't/sendOTP.pl -uid dwho',
                ext2FValidateCommand => 't/vrfyOTP.pl -uid dwho -code $code',
                restSessionServer    => 1,
                oidcRPMetaDataExportedVars => {
                    rp => {
                        email       => "mail",
                        family_name => "cn",
                        name        => "cn"
                    }
                },
                oidcServiceAllowHybridFlow            => 1,
                oidcServiceAllowImplicitFlow          => 1,
                oidcServiceAllowAuthorizationCodeFlow => 1,
                oidcRPMetaDataOptions                 => {
                    rp => {
                        oidcRPMetaDataOptionsDisplayName       => "RP",
                        oidcRPMetaDataOptionsIDTokenExpiration => 3600,
                        oidcRPMetaDataOptionsClientID          => "rpid",
                        oidcRPMetaDataOptionsIDTokenSignAlg    => "HS512",
                        oidcRPMetaDataOptionsBypassConsent     => 0,
                        oidcRPMetaDataOptionsClientSecret      => "rpsecret",
                        oidcRPMetaDataOptionsUserIDAttr        => "",
                        oidcRPMetaDataOptionsAccessTokenExpiration  => 3600,
                        oidcRPMetaDataOptionsAuthnLevel             => 5,
                        oidcRPMetaDataOptionsPostLogoutRedirectUris =>
                          "http://auth.rp.com/?logout=1",
                        oidcRPMetaDataOptionsRedirectUris =>
                          'http://auth.rp.com/?openidconnectcallback=1',
                    }
                },
                oidcOPMetaDataOptions           => {},
                oidcOPMetaDataJSON              => {},
                oidcOPMetaDataJWKS              => {},
                oidcServiceMetaDataAuthnContext => {
                    'loa-4' => 4,
                    'loa-1' => 1,
                    'loa-5' => 5,
                    'loa-2' => 2,
                    'loa-3' => 3
                },
                oidcServicePrivateKeySig => oidc_key_op_private_sig,
                oidcServicePublicKeySig  => oidc_cert_op_public_sig,
            }
        }
    );
}

sub rp {
    my ( $jwks, $metadata ) = @_;
    return LLNG::Manager::Test->new(
        {
            ini => {
                logLevel                   => $debug,
                domain                     => 'rp.com',
                portal                     => 'http://auth.rp.com/',
                authentication             => 'OpenIDConnect',
                userDB                     => 'Same',
                restSessionServer          => 1,
                oidcOPMetaDataExportedVars => {
                    op => {
                        cn   => "name",
                        uid  => "sub",
                        sn   => "family_name",
                        mail => "email"
                    }
                },
                oidcOPMetaDataOptions => {
                    op => {
                        oidcOPMetaDataOptionsCheckJWTSignature => 1,
                        oidcOPMetaDataOptionsJWKSTimeout       => 0,
                        oidcOPMetaDataOptionsClientSecret      => "rpsecret",
                        oidcOPMetaDataOptionsScope        => "openid profile",
                        oidcOPMetaDataOptionsStoreIDToken => 0,
                        oidcOPMetaDataOptionsMaxAge       => 30,
                        oidcOPMetaDataOptionsDisplay      => "",
                        oidcOPMetaDataOptionsClientID     => "rpid",
                        oidcOPMetaDataOptionsConfigurationURI =>
                          "https://auth.op.com/.well-known/openid-configuration"
                    }
                },
                oidcOPMetaDataJWKS => {
                    op => $jwks,
                },
                oidcOPMetaDataJSON => {
                    op => $metadata,
                }
            }
        }
    );
}
