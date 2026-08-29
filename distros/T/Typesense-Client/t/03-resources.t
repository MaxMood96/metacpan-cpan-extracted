# PURPOSE: Verify resource delegates: multi_search, synonyms, analytics, scoped keys
# LAYER:   unit (in-process Mojolicious server + local derivation)
# COVERS:  Typesense::Client::{Synonyms,Overrides,Analytics,Keys}, multi_search

use v5.38;
use warnings;
use Test::More;
use Mojolicious;
use Mojo::Server::Daemon;
use Mojo::IOLoop;
use Mojo::JSON qw(encode_json decode_json);
use MIME::Base64 qw(decode_base64);
use Digest::SHA qw(hmac_sha256_base64);

use Typesense::Client;

our %seen;

my $app = Mojolicious->new;
$app->log->level('fatal');
$app->routes->any('/*rest' => sub ($c) {
    %seen = (
        method => $c->req->method,
        path   => '/' . $c->stash('rest'),
        query  => $c->req->url->query->to_string,
        json   => (eval { decode_json($c->req->body) } // undef),
    );
    ## /debug is the one route with a shape of its own: server_version reads it.
    return $c->render(json => { version => '28.0', state => 1 })
        if $c->stash('rest') eq 'debug';
    $c->render(json => { ok => 1, hits => [], found => 0 });
});
my $daemon = Mojo::Server::Daemon->new(
    app => $app, listen => ['http://127.0.0.1'], silent => 1)->start;
my $port = $daemon->ports->[0];

my $ts = Typesense::Client->new(
    url => "http://127.0.0.1:$port", api_key => 'k',
    ua => Mojo::UserAgent->new(ioloop => Mojo::IOLoop->singleton)->request_timeout(10));

subtest 'multi_search: common in the query, branches in the body' => sub {
    $ts->multi_search(
        [ { collection => 'p', q => 'a', drop_tokens_threshold => 0 },
          { collection => 'p', q => 'b' } ],
        { query_by => 'name', per_page => 24 },
    );
    is($seen{method}, 'POST', 'POST');
    is($seen{path}, '/multi_search', 'path');
    is($seen{query}, 'per_page=24&query_by=name', 'the common ones go in the query string');
    is(scalar @{ $seen{json}{searches} }, 2, 'two searches in the body');
    is($seen{json}{searches}[0]{drop_tokens_threshold}, 0,
       'a per-branch parameter travels in its branch - the common one would win');
};

subtest 'synonyms' => sub {
    $ts->synonyms->put('p', 'g1', { synonyms => [qw(laptop notebook)] });
    is($seen{method}, 'PUT', 'PUT');
    is($seen{path}, '/collections/p/synonyms/g1', 'path');
    is_deeply($seen{json}{synonyms}, [qw(laptop notebook)], 'body');

    $ts->synonyms->put('p', 'g2', { root => 'laptop', synonyms => ['ultrabook'] });
    is($seen{json}{root}, 'laptop', 'one-way with root');

    $ts->synonyms->list('p');
    is($seen{path}, '/collections/p/synonyms', 'listing');
};

subtest 'curation' => sub {
    $ts->overrides->put('p', 'promo', {
        rule => { query => 'black friday', match => 'exact' },
        includes => [ { id => '1024', position => 1 } ],
    });
    is($seen{path}, '/collections/p/overrides/promo', 'path');
    is($seen{json}{includes}[0]{position}, 1, 'pinned position');
};

subtest 'analytics rules and events' => sub {
    $ts->analytics->upsert_rule('popular', {
        type => 'popular_queries',
        params => { source => { collections => ['p'] },
                    destination => { collection => 'pq' }, limit => 1000 },
    });
    is($seen{method}, 'PUT', 'PUT');
    is($seen{path}, '/analytics/rules/popular', 'rule path');
    is($seen{json}{type}, 'popular_queries', 'type');

    $ts->analytics->click('product_click', { doc_id => '42', user_id => 'cart-9' });
    is($seen{path}, '/analytics/events', 'event path');
    is($seen{json}{type}, 'click', 'event type');
    is($seen{json}{name}, 'product_click', 'name - must match the counter rule');
    is($seen{json}{data}{doc_id}, '42', 'doc_id');
    is($seen{json}{data}{user_id}, 'cart-9', 'user_id, or Typesense aggregates by IP');

    $ts->analytics->top_queries('pq', limit => 5);
    is($seen{path}, '/collections/pq/documents/search',
       'aggregated queries are read by searching their own collection');
    like($seen{query}, qr/sort_by=count%3Adesc/, 'sorted by counter');
};

subtest 'scoped key: derived locally' => sub {
    my $search_key = 'abcd1234search';
    my %params = ( filter_by => 'customer_id:=7', expires_at => 1800000000 );

    my $scoped = $ts->keys->scoped($search_key, \%params);
    ok(length $scoped, 'returns something');
    is($seen{path}, '/collections/pq/documents/search',
       'and it did NOT call the server (the path is still the previous one)');

    ## The structure Typesense expects: base64(digest . prefix4 . payload)
    my $raw = decode_base64($scoped);
    my $payload = substr($raw, 44 + 4);
    is_deeply(decode_json($payload), \%params, 'the payload travels intact');
    is(substr($raw, 44, 4), 'abcd', 'the first 4 characters of the key');

    my $digest = hmac_sha256_base64($payload, $search_key);
    $digest .= '=' x ((4 - length($digest) % 4) % 4);
    is(substr($raw, 0, 44), $digest, 'HMAC-SHA256 signature with base64 padding');
};

subtest 'server_version wraps GET /debug' => sub {
    my $v = $ts->server_version;
    is($seen{path}, '/debug', 'reads /debug');
    isa_ok($v, 'Typesense::Client::Version');
    is("$v", '28.0', 'stringifies to the reported version');
    ok($v->is_at_least('28.0'), 'and compares');
};

done_testing();
