use Test2::V0;
use feature 'signatures';
no warnings 'experimental::signatures';

# Same embedded-mock-app technique t/flow.t uses (no real socket - see
# t/par.t for why). Here the mock stands in for a user's own PDS, not
# an auth server - exercising Mojo::ATProto::OAuth::ResourceClient's own
# DPoP-nonce-rotation/access-token-refresh retry dance, not the OAuth
# handshake itself (already covered by flow.t).

use Mojo::ATProto::OAuth                       qw//;
use Mojo::ATProto::OAuth::DPoP                  qw//;
use Mojo::ATProto::OAuth::ResourceClient       qw//;
use Mojo::ATProto::OAuth::SessionStore::Memory qw//;
use Mojolicious::Lite;
use Mojo::UserAgent;

sub make_session ($store, %overrides) {
    my $dpop_key = Mojo::ATProto::OAuth::DPoP->generate_keypair;
    my $session  = {
        account_did                => 'did:plc:testuser',
        session_id                 => 'session-1',
        # Relative (no host) so Mojo::UserAgent resolves it against the
        # embedded test server via ->server->app - same technique
        # t/flow.t and t/par.t use for their own endpoint URLs, and for
        # the same reason (no real DNS/socket in this dev environment).
        host_url                   => '',
        auth_server_url            => 'https://auth.example.com',
        auth_server_token_endpoint => 'https://auth.example.com/token',
        scopes                     => ['atproto'],
        access_token               => 'access-1',
        refresh_token              => 'refresh-1',
        dpop_authserver_nonce      => 'authserver-nonce-1',
        dpop_host_nonce            => 'host-nonce-1',
        dpop_private_key_pem       => Mojo::ATProto::OAuth::DPoP->export_private_pem($dpop_key),
        %overrides,
    };
    $store->save_session($session);
    return $session;
}

sub make_oauth ($store, $ua) {
    return Mojo::ATProto::OAuth->new(
        client_id    => 'https://pib.example.com/oauth/client-metadata.json',
        callback_url => 'https://pib.example.com/oauth/callback',
        ua           => $ua,
        store        => $store,
    );
}

subtest '$oauth->client is a lazily-built, memoized ResourceClient wired to that oauth instance' => sub {
    my $store  = Mojo::ATProto::OAuth::SessionStore::Memory->new;
    my $oauth  = make_oauth($store, Mojo::UserAgent->new);
    my $client = $oauth->client;
    isa_ok($client, ['Mojo::ATProto::OAuth::ResourceClient']);
    ref_is($client->oauth, $oauth, 'wired to the oauth instance it was built from');
    ref_is($oauth->client, $client, 'the same instance is returned on subsequent calls, not rebuilt each time');
};

subtest 'plain authenticated GET, sync and async' => sub {
    my $seen_headers;
    my $app = Mojolicious::Lite->new;
    $app->routes->get('/xrpc/app.bsky.actor.getProfile' => sub ($c) {
        $seen_headers = {authorization => $c->req->headers->header('Authorization'), dpop => $c->req->headers->header('DPoP')};
        return $c->render(json => {did => 'did:plc:testuser', handle => 'alice.example.com'});
    });
    my $ua = Mojo::UserAgent->new;
    $ua->server->app($app);

    my $store  = Mojo::ATProto::OAuth::SessionStore::Memory->new;
    my $oauth  = make_oauth($store, $ua);
    make_session($store);
    my $client = Mojo::ATProto::OAuth::ResourceClient->new(oauth => $oauth);

    my $result = $client->request('did:plc:testuser', 'session-1', 'get', '/xrpc/app.bsky.actor.getProfile');
    is($result, {did => 'did:plc:testuser', handle => 'alice.example.com'}, 'decoded JSON body returned');
    is($seen_headers->{authorization}, 'DPoP access-1', 'access token sent as a DPoP-scheme Authorization header');
    ok(length($seen_headers->{dpop} // ''), 'a DPoP proof header was sent');

    my $result_p;
    $client->request_p('did:plc:testuser', 'session-1', 'get', '/xrpc/app.bsky.actor.getProfile')->then(sub ($r) { $result_p = $r })->wait;
    is($result_p, {did => 'did:plc:testuser', handle => 'alice.example.com'}, 'async counterpart returns the same decoded JSON body');
};

subtest 'POST with a JSON body' => sub {
    my $seen_body;
    my $app = Mojolicious::Lite->new;
    $app->routes->post('/xrpc/com.atproto.repo.putRecord' => sub ($c) {
        $seen_body = $c->req->json;
        return $c->render(json => {uri => 'at://did:plc:testuser/app.bsky.feed.post/abc', cid => 'bafycid'});
    });
    my $ua = Mojo::UserAgent->new;
    $ua->server->app($app);

    my $store  = Mojo::ATProto::OAuth::SessionStore::Memory->new;
    my $oauth  = make_oauth($store, $ua);
    make_session($store);
    my $client = Mojo::ATProto::OAuth::ResourceClient->new(oauth => $oauth);

    my $result = $client->request('did:plc:testuser', 'session-1', 'post', '/xrpc/com.atproto.repo.putRecord', {repo => 'did:plc:testuser', collection => 'app.bsky.feed.post', rkey => 'abc'});
    is($seen_body, {repo => 'did:plc:testuser', collection => 'app.bsky.feed.post', rkey => 'abc'}, 'body sent as JSON');
    is($result->{uri}, 'at://did:plc:testuser/app.bsky.feed.post/abc');
};

subtest 'DPoP nonce rotation: 401 + fresh nonce is retried transparently, and the new nonce is persisted' => sub {
    my $attempts = 0;
    my $app = Mojolicious::Lite->new;
    $app->routes->get('/xrpc/app.bsky.actor.getProfile' => sub ($c) {
        $attempts++;
        if ($attempts == 1) {
            $c->res->headers->header('DPoP-Nonce' => 'fresh-host-nonce');
            return $c->render(json => {error => 'use_dpop_nonce'}, status => 401);
        }
        return $c->render(json => {ok => 1});
    });
    my $ua = Mojo::UserAgent->new;
    $ua->server->app($app);

    my $store  = Mojo::ATProto::OAuth::SessionStore::Memory->new;
    my $oauth  = make_oauth($store, $ua);
    make_session($store);
    my $client = Mojo::ATProto::OAuth::ResourceClient->new(oauth => $oauth);

    my $result = $client->request('did:plc:testuser', 'session-1', 'get', '/xrpc/app.bsky.actor.getProfile');
    is($result, {ok => 1}, 'second attempt succeeded after the nonce retry');
    is($attempts, 2, 'exactly one retry happened');
    is($store->get_session('did:plc:testuser', 'session-1')->{dpop_host_nonce}, 'fresh-host-nonce', 'the fresh nonce was persisted back to the store');
};

subtest 'nonce is persisted even on a successful response, not just a 401' => sub {
    my $app = Mojolicious::Lite->new;
    $app->routes->get('/xrpc/app.bsky.actor.getProfile' => sub ($c) {
        $c->res->headers->header('DPoP-Nonce' => 'rotated-on-success');
        return $c->render(json => {ok => 1});
    });
    my $ua = Mojo::UserAgent->new;
    $ua->server->app($app);

    my $store  = Mojo::ATProto::OAuth::SessionStore::Memory->new;
    my $oauth  = make_oauth($store, $ua);
    make_session($store);
    my $client = Mojo::ATProto::OAuth::ResourceClient->new(oauth => $oauth);

    $client->request('did:plc:testuser', 'session-1', 'get', '/xrpc/app.bsky.actor.getProfile');
    is($store->get_session('did:plc:testuser', 'session-1')->{dpop_host_nonce}, 'rotated-on-success', 'proactively rotated nonce is persisted');
};

subtest 'access token expiry: 401 with no fresh nonce triggers a refresh and one retry' => sub {
    no warnings 'redefine';
    my $refresh_calls = 0;
    local *Mojo::ATProto::OAuth::refresh_tokens = sub ($self, $session) {
        $refresh_calls++;
        $session->{access_token} = 'access-2';
        $self->store->save_session($session);
        return $session;
    };

    my $seen_tokens = [];
    my $app = Mojolicious::Lite->new;
    $app->routes->get('/xrpc/app.bsky.actor.getProfile' => sub ($c) {
        my ($token) = ($c->req->headers->header('Authorization') // '') =~ /^DPoP (.+)$/;
        push @$seen_tokens, $token;
        return $c->render(json => {error => 'invalid_token'}, status => 401) if $token eq 'access-1';
        return $c->render(json => {ok => 1});
    });
    my $ua = Mojo::UserAgent->new;
    $ua->server->app($app);

    my $store  = Mojo::ATProto::OAuth::SessionStore::Memory->new;
    my $oauth  = make_oauth($store, $ua);
    make_session($store);
    my $client = Mojo::ATProto::OAuth::ResourceClient->new(oauth => $oauth);

    my $result = $client->request('did:plc:testuser', 'session-1', 'get', '/xrpc/app.bsky.actor.getProfile');
    is($result, {ok => 1}, 'succeeded after refreshing');
    is($refresh_calls, 1, 'refresh_tokens was called exactly once');
    is($seen_tokens, ['access-1', 'access-2'], 'the retried request used the refreshed access token');
};

subtest 'bounded retries: a persistently-failing session dies cleanly instead of looping' => sub {
    no warnings 'redefine';
    my $refresh_calls = 0;
    local *Mojo::ATProto::OAuth::refresh_tokens = sub ($self, $session) { $refresh_calls++; return $session };

    my $requests = 0;
    my $app = Mojolicious::Lite->new;
    $app->routes->get('/xrpc/app.bsky.actor.getProfile' => sub ($c) { $requests++; return $c->render(json => {error => 'invalid_token'}, status => 401) });
    my $ua = Mojo::UserAgent->new;
    $ua->server->app($app);

    my $store  = Mojo::ATProto::OAuth::SessionStore::Memory->new;
    my $oauth  = make_oauth($store, $ua);
    make_session($store);
    my $client = Mojo::ATProto::OAuth::ResourceClient->new(oauth => $oauth);

    like(dies { $client->request('did:plc:testuser', 'session-1', 'get', '/xrpc/app.bsky.actor.getProfile') }, qr/request failed \(HTTP 401\): session could not be refreshed/, 'dies with the expected message once retries are exhausted');
    is($requests, 2, 'exactly one refresh retry was attempted (no nonce header ever offered, so no nonce retries happened)');
    is($refresh_calls, 1, 'refresh_tokens was only called once, not looped');
};

subtest 'a non-401 error response surfaces the xrpc error field alongside the message' => sub {
    my $app = Mojolicious::Lite->new;
    $app->routes->post('/xrpc/com.atproto.repo.putRecord' => sub ($c) {
        return $c->render(json => {error => 'InvalidSwap', message => 'record was updated since swapRecord was read'}, status => 400);
    });
    my $ua = Mojo::UserAgent->new;
    $ua->server->app($app);

    my $store  = Mojo::ATProto::OAuth::SessionStore::Memory->new;
    my $oauth  = make_oauth($store, $ua);
    make_session($store);
    my $client = Mojo::ATProto::OAuth::ResourceClient->new(oauth => $oauth);

    like(
        dies { $client->request('did:plc:testuser', 'session-1', 'post', '/xrpc/com.atproto.repo.putRecord', {}) },
        qr/request failed \(HTTP 400, xrpc_error=InvalidSwap\): record was updated since swapRecord was read/,
        'die message carries both the machine-readable error and the human-readable message'
    );
};

done_testing;
