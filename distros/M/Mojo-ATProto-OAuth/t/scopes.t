use Test2::V0;
use feature 'signatures';
no warnings 'experimental::signatures';

# Mojo::ATProto::OAuth's 'scopes' attribute (and every other place a
# scopes value is accepted - new_localhost, the 'scopes' opt on
# send_auth_request(_p)/start_auth_flow(_p)) accepts either an arrayref
# of individual scope tokens or a single space-separated string;
# whichever form is given, it's normalized to the arrayref-of-tokens
# form internally and read back as one - see Mojo::ATProto::OAuth's own
# _normalize_scopes.

use Mojo::ATProto::OAuth qw//;
use Mojo::URL;
use Mojolicious::Lite;
use Mojo::UserAgent;

subtest 'scopes attribute: constructor and setter both accept a string or an arrayref' => sub {
    is(
        Mojo::ATProto::OAuth->new(client_id => 'cid', callback_url => 'cb')->scopes,
        ['atproto'],
        'default is unaffected'
    );
    is(
        Mojo::ATProto::OAuth->new(client_id => 'cid', callback_url => 'cb', scopes => 'atproto account:email')->scopes,
        ['atproto', 'account:email'],
        'a space-separated string supplied at construction time is split into individual tokens'
    );
    is(
        Mojo::ATProto::OAuth->new(client_id => 'cid', callback_url => 'cb', scopes => ['atproto', 'account:email'])->scopes,
        ['atproto', 'account:email'],
        'an arrayref supplied at construction time is left as-is'
    );

    my $oauth = Mojo::ATProto::OAuth->new(client_id => 'cid', callback_url => 'cb');
    $oauth->scopes('atproto  account:email'); # deliberate double space - split(' ', ...) collapses runs of whitespace
    is($oauth->scopes, ['atproto', 'account:email'], 'the ->scopes(...) setter normalizes the same way, including collapsing repeated whitespace');
};

subtest 'new_localhost: a space-separated scopes string produces the same client_id query string as the equivalent arrayref' => sub {
    my $from_string = Mojo::ATProto::OAuth->new_localhost(callback_url => 'http://127.0.0.1:8080/callback', scopes => 'atproto account:email');
    my $from_array  = Mojo::ATProto::OAuth->new_localhost(callback_url => 'http://127.0.0.1:8080/callback', scopes => ['atproto', 'account:email']);

    is(Mojo::URL->new($from_string->client_id)->query->param('scope'), 'atproto account:email');
    is(Mojo::URL->new($from_array->client_id)->query->param('scope'), 'atproto account:email');
    is($from_string->scopes, ['atproto', 'account:email'], 'the constructed instance itself also carries the normalized arrayref');
};

subtest "send_auth_request(_p)'s 'scopes' opt accepts a string, overriding the client's own default" => sub {
    my $app = Mojolicious::Lite->new;
    $app->routes->post('/par' => sub ($c) { return $c->render(json => {request_uri => 'urn:ietf:params:oauth:request_uri:req-1', expires_in => 60}, status => 201) });
    my $ua = Mojo::UserAgent->new;
    $ua->server->app($app);

    my $auth_meta = {issuer => 'https://auth.example.com', pushed_authorization_request_endpoint => '/par'};
    my $oauth     = Mojo::ATProto::OAuth->new(client_id => 'cid', callback_url => 'cb', scopes => ['atproto'], ua => $ua);

    my $info = $oauth->send_auth_request($auth_meta, scopes => 'atproto account:email');
    is($info->{scopes}, ['atproto', 'account:email'], 'sync: the string opt was normalized and used in place of the client default');

    my $info_p;
    $oauth->send_auth_request_p($auth_meta, scopes => 'atproto account:email')->then(sub ($i) { $info_p = $i })->wait;
    is($info_p->{scopes}, ['atproto', 'account:email'], 'async counterpart behaves the same');
};

done_testing;
