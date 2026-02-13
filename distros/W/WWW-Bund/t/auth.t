use strict;
use warnings;
use Test::More;
use Test::Exception;

use WWW::Bund::Auth;

my $auth = WWW::Bund::Auth->new;

# default is none
{
    my $config = $auth->get('autobahn');
    is($config->{type}, 'none', 'default auth is none');

    my $headers = $auth->headers_for('autobahn');
    is_deeply($headers, {}, 'no headers for none auth');
}

# set api_key auth
{
    $auth->set('jobsuche',
        type    => 'api_key',
        env_var => 'JOBSUCHE_API_KEY',
    );

    my $config = $auth->get('jobsuche');
    is($config->{type}, 'api_key', 'api_key auth set');
    is($config->{env_var}, 'JOBSUCHE_API_KEY', 'env_var set');

    # Without env var set, headers_for should die
    local $ENV{JOBSUCHE_API_KEY};
    delete $ENV{JOBSUCHE_API_KEY};
    throws_ok { $auth->headers_for('jobsuche') } qr/not set/, 'dies when env var missing';

    # With env var set
    local $ENV{JOBSUCHE_API_KEY} = 'test-token-123';
    my $headers = $auth->headers_for('jobsuche');
    is($headers->{Authorization}, 'Bearer test-token-123', 'Bearer token in Authorization header');
}

# custom header name
{
    $auth->set('custom_api',
        type        => 'api_key',
        env_var     => 'CUSTOM_KEY',
        header_name => 'X-API-Key',
    );

    local $ENV{CUSTOM_KEY} = 'my-key';
    my $headers = $auth->headers_for('custom_api');
    is($headers->{'X-API-Key'}, 'my-key', 'custom header name works');
}

# validation
{
    throws_ok { $auth->set('bad', type => 'api_key') } qr/env_var required/, 'api_key requires env_var';
    throws_ok { $auth->set('bad', type => 'oauth2') } qr/oauth_url required/, 'oauth2 requires oauth_url';
    throws_ok { $auth->set('bad', type => 'invalid') } qr/Unknown auth type/, 'unknown type rejected';
}

done_testing;
