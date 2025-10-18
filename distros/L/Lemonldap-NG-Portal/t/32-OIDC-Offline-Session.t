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

my $debug = "error";

sub runTest {
    my ( $op, $jwt, $refresh_rotation, $adminLogout, $inactive ) = @_;
    Time::Fake->reset;

    LWP::Protocol::PSGI->register(
        sub {
            my $req = Plack::Request->new(@_);
            ok( $req->uri =~ m#http://auth.((?:o|r)p).com(.*)#,
                ' REST request' );
            my $host = $1;
            my $url  = $2;
            my ( $res, $client );
            if ( $req->method =~ /^post$/i ) {
                my $s = $req->content;
                ok(
                    $res = $op->_post(
                        $url,
                        IO::String->new($s),
                        length => length($s),
                        type   => $req->header('Content-Type'),
                        custom => {
                            HTTP_AUTHORIZATION => $req->header('Authorization'),
                        }
                    ),
                    '  Execute request',
                );
            }
            else {
                ok(
                    $res = $op->_get(
                        $url,
                        custom => {
                            HTTP_AUTHORIZATION => $req->header('Authorization'),
                        }
                    ),
                    '  Execute request'
                );
            }
            return $res;
        }
    );

    my $query;
    my $res;

    my $idpId = $op->login( 'french', { lmAuth => '1_Demo' } );

    # Inital first name
    $Lemonldap::NG::Portal::UserDB::Demo::demoAccounts{french}->{cn} =
      'Frédéric Accents';

    my $code = codeAuthorize(
        $op, $idpId,
        {
            response_type => "code",

            # Include a weird scope name, to make sure they work (#2168)
            scope => "openid profile email offline_access !weird:scope.name~",
            client_id    => "rpid",
            state        => "af0ifjsldkj",
            redirect_uri => "http://test/"
        }
    );

    my $json = expectJSON( codeGrant( $op, "rpid", $code, "http://test/" ) );
    my $access_token = $json->{access_token};
    if ($jwt) {
        expectJWT(
            $access_token,
            name => "Frédéric Accents",
            sub  => "customfrench"
        );
    }
    my $refresh_token = $json->{refresh_token};

    # Make sure refresh token session has no _lastSeen to avoid purge
    ok( !getSamlSession($refresh_token)->{data}->{_lastSeen} );

    my $id_token = $json->{id_token};
    ok( $access_token,  "Got access token" );
    ok( $refresh_token, "Got refresh token" );
    ok( $id_token,      "Got ID token" );

    my $id_token_payload = id_token_payload($id_token);
    my $auth_time        = $id_token_payload->{auth_time};
    ok( $auth_time, "Authentication date found in token" );
    is(
        $id_token_payload->{name},
        'Frédéric Accents',
        'Found claim in ID token'
    );
    is( $id_token_payload->{sub}, 'customfrench', 'Found sub in ID token' );

    $json = expectJSON( getUserinfo( $op, $access_token ) );

    ok( $json->{'name'} eq "Frédéric Accents", 'Got User Info' );
    ok( $json->{'sub'} eq "customfrench",      'Got User Info' );

    $op->logout($idpId);

    # Refresh access token after logging out

    $json = expectJSON( refreshGrant( $op, 'rpid', $refresh_token ) );

    if ($refresh_rotation) {
        my $old_refresh_token = $refresh_token;
        ok( $refresh_token = $json->{refresh_token},
            "Refresh token was updated" );
        expectReject( refreshGrant( $op, "rpid", $old_refresh_token ),
            400, "invalid_request" );
    }
    else {
        ok( !defined $json->{refresh_token}, "Refresh token not present" );
    }

    # Make sure refresh token session has no _lastSeen to avoid purge
    ok( !getSamlSession($refresh_token)->{data}->{_lastSeen} );

    $access_token = $json->{access_token};
    if ($jwt) {
        expectJWT(
            $access_token,
            name => "Frédéric Accents",
            sub  => "customfrench"
        );
    }
    $id_token = $json->{id_token};
    ok( $access_token, "Got refreshed Access token" );
    ok( $id_token,     "Got refreshed ID token" );

    $id_token_payload = id_token_payload($id_token);
    is(
        $id_token_payload->{name},
        'Frédéric Accents',
        'Found claim in ID token'
    );
    is( $id_token_payload->{sub}, 'customfrench', 'Found sub in ID token' );

    $json = expectJSON( getUserinfo( $op, $access_token ) );

    ok( $json->{name} eq "Frédéric Accents", "Correct user info" );
    ok( $json->{'sub'} eq "customfrench",    'Got User Info' );

    # Make sure offline session is still valid long after natural session
    # expiration time

    Time::Fake->offset("+10d");

    # Change attribute value
    $Lemonldap::NG::Portal::UserDB::Demo::demoAccounts{french}->{cn} =
      'Frédéric Freedom';

    $json = expectJSON( refreshGrant( $op, 'rpid', $refresh_token ) );

    if ($refresh_rotation) {
        my $old_refresh_token = $refresh_token;
        ok( $refresh_token = $json->{refresh_token},
            "Refresh token was updated" );
        expectReject( refreshGrant( $op, "rpid", $old_refresh_token ),
            400, "invalid_request" );
    }
    else {
        ok( !defined $json->{refresh_token}, "Refresh token not present" );
    }

    # Make sure refresh token session has no _lastSeen to avoid purge
    ok( !getSamlSession($refresh_token)->{data}->{_lastSeen} );

    $access_token = $json->{access_token};
    if ($jwt) {
        expectJWT(
            $access_token,
            name => "Frédéric Freedom",
            sub  => "customfrench"
        );
    }
    $id_token = $json->{id_token};
    ok( $access_token, "Got refreshed Access token" );
    ok( $id_token,     "Got refreshed ID token" );

    $id_token_payload = id_token_payload($id_token);
    is( $id_token_payload->{auth_time},
        $auth_time, 'Original auth_time retained' );
    is(
        $id_token_payload->{name},
        'Frédéric Freedom',
        'Found claim in ID token'
    );
    ok( ( grep { $_ eq "rpid" } @{ $id_token_payload->{aud} } ),
        'Check that clientid is in audience' );
    ok( (
            grep { $_ eq "http://my.extra.audience/test" }
              @{ $id_token_payload->{aud} }
        ),
        'Check for additional audiences'
    );
    ok( ( grep { $_ eq "urn:extra2" } @{ $id_token_payload->{aud} } ),
        'Check for additional audiences' );

    $json = expectJSON( getUserinfo( $op, $access_token ) );

    is( $json->{name},  "Frédéric Freedom", "Correct user info" );
    is( $json->{'sub'}, "customfrench",     'Got User Info' );

    ## Test introspection of refreshed token #2171
    $json = expectJSON( introspect( $op, 'rpid', $access_token ) );

    is( $json->{active},    1,      'Token is active' );
    is( $json->{client_id}, 'rpid', 'Introspection contains client_id' );
    is( $json->{sub},       'customfrench', 'Introspection contains sub' );

    # #2168
    ok(
        ( grep { $_ eq "!weird:scope.name~" } ( split /\s+/, $json->{scope} ) ),
        "Scope contains weird scope name"
    );

    if ($adminLogout) {
        require t::SessionExplorer;
        my $se;
        ok( $se = t::SessionExplorer->new( $op->p->conf ),
            'Create SessionExplorer object' );
        expectOK(
            $se->adminLogout(
                query => "sessionType=offline&sessionId="
                  . (
                    $ENV{LLNG_HASHED_SESSION_STORE}
                    ? id2storage($refresh_token)
                    : $refresh_token
                  )
            )
        );
    }
    elsif ($inactive) {
        Time::Fake->offset('+24d');
        expectReject( refreshGrant( $op, 'rpid', $refresh_token ) );
    }
    else {
        $query = "token=$refresh_token&token_hint=refresh_token";
        ok(
            $op->_post(
                '/oauth2/revoke',
                IO::String->new($query),
                length => length($query),
                query  => 'logout=1',
                custom => { HTTP_AUTHORIZATION => "Basic cnBpZDpycGlk" }
            ),
            'Refresh_token logout'
        );
    }
    Time::Fake->offset('+6s');
    $json = expectReject( refreshGrant( $op, 'rpid', $refresh_token ),
        400, "invalid_request" );
    Time::Fake->reset;
}

sub runTestRemoveUser {
    my ( $op, $refresh_rotation ) = @_;
    Time::Fake->reset;

    my $query;
    my $res;

    $Lemonldap::NG::Portal::UserDB::Demo::demoAccounts{goner} = {
        uid  => 'goner',
        cn   => 'James Goner',
        mail => 'goner@badwolf.org',
    };

    my $idpId = login( $op, 'goner' );

    my $code = codeAuthorize(
        $op, $idpId,
        {
            response_type => "code",

            scope        => "openid email offline_access",
            client_id    => "rpid",
            state        => "af0ifjsldkj",
            redirect_uri => "http://test/"
        }
    );

    my $json = expectJSON( codeGrant( $op, "rpid", $code, "http://test/" ) );
    my $refresh_token = $json->{refresh_token};
    ok( $refresh_token, "Got refresh token" );

    $op->logout($idpId);

    # Refresh access token after logging out
    $json = expectJSON( refreshGrant( $op, 'rpid', $refresh_token ) );
    ok( $json->{access_token}, "Found access token" );

    if ($refresh_rotation) {
        my $old_refresh_token = $refresh_token;
        ok( $refresh_token = $json->{refresh_token},
            "Refresh token was updated" );
        expectReject( refreshGrant( $op, "rpid", $old_refresh_token ),
            400, "invalid_request" );
    }
    else {
        ok( !defined $json->{refresh_token}, "Refresh token not present" );
    }

    # Remove user from storage
    delete $Lemonldap::NG::Portal::UserDB::Demo::demoAccounts{goner};
    $json = expectReject( refreshGrant( $op, 'rpid', $refresh_token ),
        400, "invalid_grant" );
}

my $baseConfig = {
    ini => {
        logLevel                        => $debug,
        domain                          => 'op.com',
        portal                          => 'http://auth.op.com/',
        authentication                  => 'Demo',
        timeoutActivity                 => 3600,
        adminLogoutServerSecret         => 'qwerty',
        userDB                          => 'Same',
        issuerDBOpenIDConnectActivation => 1,
        oidcRPMetaDataExportedVars      => {
            rp => {
                email       => "mail",
                family_name => "cn",
                name        => "cn"
            }
        },
        oidcRPMetaDataMacros => {
            rp => {
                custom_sub => '"custom".$uid',
            }
        },
        oidcRPMetaDataOptions => {
            rp => {
                oidcRPMetaDataOptionsDisplayName         => "RP",
                oidcRPMetaDataOptionsClientID            => "rpid",
                oidcRPMetaDataOptionsAllowOffline        => 1,
                oidcRPMetaDataOptionsIDTokenSignAlg      => "HS512",
                oidcRPMetaDataOptionsAccessTokenSignAlg  => "RS512",
                oidcRPMetaDataOptionsAccessTokenClaims   => 1,
                oidcRPMetaDataOptionsClientSecret        => "rpid",
                oidcRPMetaDataOptionsUserIDAttr          => "custom_sub",
                oidcRPMetaDataOptionsBypassConsent       => 1,
                oidcRPMetaDataOptionsIDTokenForceClaims  => 1,
                oidcRPMetaDataOptionsAdditionalAudiences =>
                  "http://my.extra.audience/test urn:extra2",
                oidcRPMetaDataOptionsRedirectUris => 'http://test/',
                oidcRPMetaDataOptionsRtActivity   => 1036800,          # 12 days
            }
        },
        oidcServicePrivateKeySig => oidc_key_op_private_sig,
        oidcServicePublicKeySig  => oidc_cert_op_public_sig,
    }
};

subtest "Run tests with base config" => sub {
    my $op = LLNG::Manager::Test->new($baseConfig);
    runTest($op);
};

subtest "Session explorer logout using refresh_token" => sub {
  SKIP: {
        eval { require Lemonldap::NG::Manager::Sessions };
        skip 'No manager found', 1 if $@;
        my $op = LLNG::Manager::Test->new($baseConfig);
        runTest( $op, 0, 0, 1 );
    }
};

subtest "Inactive refresh_token" => sub {
    my $op = LLNG::Manager::Test->new($baseConfig);
    runTest( $op, 0, 0, 0, 1 );
};

subtest "Removed user's offline sessions are no longer valid" => sub {
    my $op = LLNG::Manager::Test->new($baseConfig);
    runTestRemoveUser($op);
};

subtest "Run tests with JWT access tokens" => sub {
    $baseConfig->{ini}->{oidcRPMetaDataOptions}->{rp}
      ->{oidcRPMetaDataOptionsAccessTokenJWT} = 1;
    my $op = LLNG::Manager::Test->new($baseConfig);
    runTest( $op, 1 );
};

subtest "Run tests with refresh token rotation" => sub {
    $baseConfig->{ini}->{oidcRPMetaDataOptions}->{rp}
      ->{oidcRPMetaDataOptionsRefreshTokenRotation} = 1;
    my $op = LLNG::Manager::Test->new($baseConfig);
    runTest( $op, 1, 1 );
};

subtest "Using choice authentication method" => sub {
    $baseConfig->{ini}->{authentication} = "Choice";
    $baseConfig->{ini}->{authChoiceModules}->{'1_Demo'} = 'Demo;Demo;Null';
    my $op = LLNG::Manager::Test->new($baseConfig);
    runTest( $op, 1, 1 );
};

clean_sessions();
done_testing();

