# PURPOSE: Verify the HTTP core of Typesense::Client (headers, verbs, errors)
# LAYER:   unit (in-process Mojolicious server, no external network)
# COVERS:  Typesense::Client, Typesense::Client::Error

use v5.38;
use warnings;
use Test::More;
use Mojolicious;
use Mojo::Server::Daemon;
use Mojo::IOLoop;
use Mojo::JSON qw(encode_json);

use Typesense::Client;

## A real server in the same process: exercises the whole request (method,
## path, API key header, body) without depending on the network.
our %seen;
our $mode = 'ok';

my $app = Mojolicious->new;
$app->log->level('fatal');
$app->routes->any('/*rest' => sub ($c) {
    %seen = (
        method => $c->req->method,
        path   => '/' . $c->stash('rest'),
        key    => $c->req->headers->header('X-TYPESENSE-API-KEY') // '',
        user   => $c->req->headers->header('x-typesense-user-id')   // '',
        query  => $c->req->url->query->to_string,
        body   => $c->req->body,
    );
    return $c->render(status => 404, json => { message => 'Not Found' }) if $mode eq 'e404';
    return $c->render(status => 422, json => { message => 'Bad field' })  if $mode eq 'e422';
    return $c->render(status => 500, data => 'plain boom')                if $mode eq 'e500';
    return $c->render(data => "{\"success\":true}\n{\"success\":false,\"error\":\"dup\"}\n")
        if $mode eq 'jsonl';
    return $c->render(json => { ok => 1 });
});

my $daemon = Mojo::Server::Daemon->new(
    app => $app, listen => ['http://127.0.0.1'], silent => 1)->start;
my $port = $daemon->ports->[0];

sub client (%extra) {
    return Typesense::Client->new(
        url     => "http://127.0.0.1:$port",
        api_key => 'secret-key',
        ## the UA shares the daemon's ioloop: the Test::Mojo pattern
        ua      => Mojo::UserAgent->new(ioloop => Mojo::IOLoop->singleton)->request_timeout(10),
        bulk_ua => Mojo::UserAgent->new(ioloop => Mojo::IOLoop->singleton)->request_timeout(10),
        %extra,
    );
}

subtest 'request shape' => sub {
    my $ts = client();
    is_deeply($ts->health, { ok => 1 }, 'decodes the JSON response');
    is($seen{method}, 'GET',        'verb');
    is($seen{path},   '/health',    'path');
    is($seen{key},    'secret-key', 'X-TYPESENSE-API-KEY header');
};

subtest 'the trailing slash of the url is normalised' => sub {
    my $ts = Typesense::Client->new(url => "http://127.0.0.1:$port///", api_key => 'k',
        ua => Mojo::UserAgent->new(ioloop => Mojo::IOLoop->singleton));
    is($ts->url, "http://127.0.0.1:$port", 'no trailing slashes');
};

subtest 'sorted query string (cacheable responses)' => sub {
    my $ts = client();
    $ts->search('products', { q => 'labtop', query_by => 'name', filter_by => 'x:=1' });
    is($seen{path}, '/collections/products/documents/search', 'search path');
    is($seen{query}, 'filter_by=x%3A%3D1&q=labtop&query_by=name',
       'alphabetical keys, not hash order');
};

subtest 'extra headers ride along with the API key' => sub {
    my $ts = client();
    $ts->search('products', { q => 'laptop', query_by => 'name' },
                headers => { 'x-typesense-user-id' => 'session-42' });
    is($seen{user}, 'session-42', 'search passes headers through to the request');
    is($seen{key},  'secret-key', '... and the API key is still there');

    ## The caller's headers are merged last on purpose: it is how one client
    ## sends a per-tenant scoped key without being rebuilt.
    $ts->search('products', { q => 'a', query_by => 'name' },
                headers => { 'X-TYPESENSE-API-KEY' => 'scoped-key' });
    is($seen{key}, 'scoped-key', 'a caller header overrides the constructor key');

    $ts->multi_search([ { collection => 'products', q => 'a' } ], {},
                      headers => { 'x-typesense-user-id' => 'session-9' });
    is($seen{user}, 'session-9', 'multi_search takes them too');
};

subtest 'errors as exceptions' => sub {
    my $ts = client();
    local $mode = 'e422';
    my $r = eval { $ts->collections->create({ name => 'x' }) };
    ok(!defined $r, 'returns nothing');
    my $err = $@;
    isa_ok($err, 'Typesense::Client::Error');
    is($err->code, 422, 'HTTP code');
    is($err->message, 'Bad field', 'message from the server');
    is($err->endpoint, 'POST /collections', 'endpoint that failed');
    like("$err", qr/Bad field \(HTTP 422\)/, 'stringifies with the detail');
    ok(!$err->is_connection_error, 'not a connection error');
};

subtest 'error with no JSON body' => sub {
    my $ts = client();
    local $mode = 'e500';
    eval { $ts->health };
    is($@->code, 500, 'code');
    ok(length $@->message, 'falls back to the HTTP status message');
};

subtest 'fail_open returns undef and stores the error' => sub {
    my $ts = client(fail_open => 1);
    local $mode = 'e422';
    my $r = $ts->health;
    is($r, undef, 'undef instead of dying');
    isa_ok($ts->last_error, 'Typesense::Client::Error');
    is($ts->last_error->code, 422, 'the error stays reachable');

    $mode = 'ok';
    ok($ts->health, 'the next call works');
    is($ts->last_error, undef, 'and last_error is cleared');
};

subtest 'unreachable server' => sub {
    ## Port 1: closed on any machine, with no wait for a DNS timeout
    my $ts = Typesense::Client->new(url => 'http://127.0.0.1:1', api_key => 'k',
        fail_open => 1,
        ua => Mojo::UserAgent->new(ioloop => Mojo::IOLoop->singleton, connect_timeout => 1));
    is($ts->health, undef, 'undef');
    is($ts->last_error->code, 0, 'code 0 = no HTTP response');
    ok($ts->last_error->is_connection_error, 'is_connection_error');
};

subtest 'a 404 on DELETE is not an error' => sub {
    my $ts = client();
    local $mode = 'e404';
    my $r = eval { $ts->collections->drop('ghost') };
    is($@, '', 'deleting something that is not there does not throw')
        or diag "died: $@";
    is($r, undef, 'returns undef');

    ## but a 404 on GET is an error
    my $g = eval { $ts->collections->get('ghost') };
    isa_ok($@, 'Typesense::Client::Error');
    ok($@->is_not_found, 'is_not_found');
};

done_testing();
