# PURPOSE: Exercise the whole client against a real Typesense server
# LAYER:   integration (opt-in: needs TYPESENSE_TEST_URL and TYPESENSE_TEST_KEY)
# COVERS:  every resource delegate, end to end, including scoped key derivation
#
# The rest of the suite talks to an in-process mock, which proves we build the
# request we think we build - but not that Typesense accepts it. This one does.
#
#   ./dev/test.sh          # brings up a throwaway container and sets both vars
#
# or point it at a server you already have:
#
#   TYPESENSE_TEST_URL=http://127.0.0.1:8108 TYPESENSE_TEST_KEY=xyz prove -l t/

use v5.38;
use warnings;
use Test::More;

use Typesense::Client;

my $url = $ENV{TYPESENSE_TEST_URL};
my $key = $ENV{TYPESENSE_TEST_KEY};

plan skip_all => 'live tests: set TYPESENSE_TEST_URL and TYPESENSE_TEST_KEY '
               . '(or run ./dev/test.sh)'
    unless $url && $key;

my $ts = Typesense::Client->new(url => $url, api_key => $key);

## Set but unreachable is a different situation from unset, and it deserves a
## better death than a connection error raised from inside the cleanup below.
my $reachable = eval { $ts->health };
unless ($reachable) {
    my $why = $ts->last_error ? $ts->last_error->message : "$@";
    $why =~ s/ at \S+ line \d+\.?\s*\z//;    ## the file and line help nobody here
    plan skip_all => "live tests: $url is not answering ($why)";
}

## Everything this test creates carries this prefix, and is dropped both before
## and after the run: a crashed run must not poison the next one.
my $PREFIX = 'tsclient_live_';
my $COLL   = "${PREFIX}products";
my $QUERIES = "${PREFIX}queries";

sub cleanup {
    $ts->aliases->delete("${PREFIX}alias");
    $ts->analytics->delete_rule("${PREFIX}popular");
    $ts->analytics->delete_rule("${PREFIX}counter");
    $ts->collections->drop($_) for $COLL, "${COLL}_new", $QUERIES, "${PREFIX}bad";
}
cleanup();

## Only tidy up if we ever got far enough to make a mess: an END block that
## talks to an unreachable server turns a clean skip into a failure.
END { cleanup() if $reachable }

subtest 'the server is there and identifies itself' => sub {
    ok($ts->health->{ok}, 'GET /health says ok');
    my $debug = $ts->debug;
    like($debug->{version}, qr/^\d+\.\d+/, "GET /debug reports version $debug->{version}");

    ## The real server is the only place the lenient parse gets exercised
    ## against whatever Typesense actually calls itself today.
    my $v = $ts->server_version;
    isa_ok($v, 'Typesense::Client::Version');
    is("$v", $debug->{version}, 'server_version stringifies to the reported version');
    ok($v->major >= 1, "parsed a major version: " . $v->major);
    ok($v->is_at_least('1.0'), 'is_at_least works against a live version string');
    ok(exists $ts->stats->{latency_ms}, 'GET /stats.json');
    ok(exists $ts->metrics->{system_memory_used_bytes}, 'GET /metrics.json');
};

subtest 'collections: create, get, update, drop' => sub {
    my $created = $ts->collections->create({
        name   => $COLL,
        fields => [
            { name => 'name',       type => 'string'             },
            { name => 'brand',      type => 'string', facet => \1 },
            { name => 'popularity', type => 'int32'              },
        ],
        default_sorting_field => 'popularity',
    });
    is($created->{name}, $COLL, 'created');
    ## The JSON boolean matters: facet => 1 is rejected with a 400.
    ok($created->{fields}[1]{facet}, 'facet came back true, so \1 reached the server as a boolean');

    ok((grep { $_->{name} eq $COLL } @{ $ts->collections->list }), 'shows up in the listing');
    is($ts->collections->get($COLL)->{num_documents}, 0, 'starts empty');

    $ts->collections->update($COLL, { fields => [ { name => 'stock', type => 'int32', optional => \1 } ] });
    my $fields = $ts->collections->get($COLL)->{fields};
    ok((grep { $_->{name} eq 'stock' } @$fields), 'PATCH added a field');

    is($ts->collections->drop('no_such_collection_here'), undef, 'dropping what is gone returns undef');
};

subtest 'documents: CRUD, batched import, export' => sub {
    my $doc = $ts->documents->upsert($COLL, { id => '1', name => 'Laptop 14', brand => 'ACME', popularity => 10 });
    is($doc->{id}, '1', 'upsert');
    is($ts->documents->get($COLL, '1')->{name}, 'Laptop 14', 'get');

    $ts->documents->update($COLL, '1', { popularity => 42 });
    is($ts->documents->get($COLL, '1')->{popularity}, 42, 'PATCH is partial: popularity moved');
    is($ts->documents->get($COLL, '1')->{name}, 'Laptop 14', '... and name survived');

    my @docs = map { { id => "$_", name => "Laptop $_", brand => 'ACME', popularity => $_ } } 2 .. 25;
    my $r = $ts->documents->import_docs($COLL, \@docs, batch_size => 10);
    is($r->{total},  24, 'import: total');
    is($r->{ok},     24, 'import: all indexed');
    is($r->{failed},  0, 'import: none rejected');

    ## A rejected document must be counted, not hidden behind the HTTP 200.
    my $bad = $ts->documents->import_docs($COLL,
        [ { id => '99', name => 'Laptop 99', brand => 'ACME', popularity => 'not-an-int' } ]);
    is($bad->{failed}, 1, 'a bad document is reported as failed even though HTTP was 200');
    like($bad->{errors}[0], qr/int32/, '... and its error line is kept');

    is($ts->collections->get($COLL)->{num_documents}, 25, 'the server agrees on the count');

    my $all = $ts->documents->export($COLL);
    is(scalar @$all, 25, 'export decodes every JSONL line');
    like($ts->documents->export($COLL, raw => 1), qr/^\{/, 'raw => 1 returns the JSONL text');

    is($ts->documents->delete($COLL, '25')->{id}, '25', 'delete');
    is($ts->documents->delete($COLL, '25'), undef, 'deleting it again is not an error');
    is($ts->documents->delete_by_filter($COLL, 'popularity:<3')->{num_deleted}, 1, 'delete_by_filter');
};

subtest 'search and multi_search' => sub {
    my $r = $ts->search($COLL, { q => 'laptop', query_by => 'name' });
    ok($r->{found} > 0, "plain search found $r->{found}");

    ## Typo tolerance is the whole point of the engine: 'labtop' must still hit.
    ok($ts->search($COLL, { q => 'labtop', query_by => 'name' })->{found} > 0,
       'a typo still finds documents');

    my $f = $ts->search($COLL, { q => '*', query_by => 'name', facet_by => 'brand' });
    is($f->{facet_counts}[0]{field_name}, 'brand', 'faceting works on the facet field');

    my $multi = $ts->multi_search(
        [ { collection => $COLL, q => 'laptop', drop_tokens_threshold => 0 },
          { collection => $COLL, q => 'acme' } ],
        { query_by => 'name,brand' },
    );
    is(scalar @{ $multi->{results} }, 2, 'two result sets in one round trip');
    ok(!exists $multi->{results}[0]{error}, 'first branch ran') or diag explain $multi->{results}[0];
};

subtest 'aliases: the zero-downtime reindex' => sub {
    $ts->collections->create({
        name   => "${COLL}_new",
        fields => [ { name => 'name', type => 'string' } ],
    });
    $ts->documents->upsert("${COLL}_new", { id => '1', name => 'Laptop 14' });

    is($ts->aliases->set("${PREFIX}alias", $COLL)->{collection_name}, $COLL, 'alias points at the old one');
    is($ts->aliases->get("${PREFIX}alias")->{collection_name}, $COLL, 'and reads back');
    ok($ts->search("${PREFIX}alias", { q => 'laptop', query_by => 'name' })->{found} > 0,
       'searching through the alias works');

    ## The swap is what makes a reindex invisible: same name, new collection.
    $ts->aliases->set("${PREFIX}alias", "${COLL}_new");
    is($ts->aliases->get("${PREFIX}alias")->{collection_name}, "${COLL}_new", 'swapped atomically');
    ok((grep { $_->{name} eq "${PREFIX}alias" } @{ $ts->aliases->list->{aliases} }), 'shows up in the listing');

    $ts->aliases->delete("${PREFIX}alias");
    is($ts->aliases->delete("${PREFIX}alias"), undef, 'deleting a gone alias is not an error');
};

subtest 'synonyms' => sub {
    my $s = $ts->synonyms->put($COLL, 'syn1', { synonyms => [qw(laptop notebook computer)] });
    is_deeply($s->{synonyms}, [qw(laptop notebook computer)], 'multi-way stored');

    ## The point of a synonym: a word that is in no document still finds them.
    ok($ts->search($COLL, { q => 'notebook', query_by => 'name' })->{found} > 0,
       'searching "notebook" finds the laptops');

    $ts->synonyms->put($COLL, 'syn2', { root => 'laptop', synonyms => ['ultrabook'] });
    is($ts->synonyms->get($COLL, 'syn2')->{root}, 'laptop', 'one-way stored with its root');
    ok(scalar @{ $ts->synonyms->list($COLL)->{synonyms} } >= 2, 'both listed');

    $ts->synonyms->delete($COLL, 'syn2');
    is($ts->synonyms->delete($COLL, 'syn2'), undef, 'deleting a gone synonym is not an error');
};

subtest 'overrides (curation)' => sub {
    my $o = $ts->overrides->put($COLL, "${PREFIX}promo", {
        rule     => { query => 'laptop', match => 'exact' },
        includes => [ { id => '7', position => 1 } ],
        excludes => [ { id => '8' } ],
    });
    is($o->{id}, "${PREFIX}promo", 'stored');

    ## Curation is only real if it reorders actual results.
    my $r = $ts->search($COLL, { q => 'laptop', query_by => 'name' });
    is($r->{hits}[0]{document}{id}, '7', 'the pinned document comes first');
    ok(!(grep { $_->{document}{id} eq '8' } @{ $r->{hits} }), 'the excluded one is gone');

    ok(scalar @{ $ts->overrides->list($COLL)->{overrides} } >= 1, 'listed');
    $ts->overrides->delete($COLL, "${PREFIX}promo");
    is($ts->overrides->delete($COLL, "${PREFIX}promo"), undef, 'deleting a gone override is not an error');
};

subtest 'analytics rules and events' => sub {
    $ts->collections->create({
        name   => $QUERIES,
        fields => [ { name => 'q', type => 'string' }, { name => 'count', type => 'int32' } ],
    });

    my $rule = $ts->analytics->upsert_rule("${PREFIX}popular", {
        type   => 'popular_queries',
        params => {
            source       => { collections => [$COLL] },
            destination  => { collection  => $QUERIES },
            limit        => 100,
            expand_query => \1,
        },
    });
    is($rule->{type}, 'popular_queries', 'popular_queries rule accepted');
    is($ts->analytics->rule("${PREFIX}popular")->{name}, "${PREFIX}popular", 'reads back by name');
    ok((grep { $_->{name} eq "${PREFIX}popular" } @{ $ts->analytics->rules->{rules} }), 'listed');

    $ts->analytics->upsert_rule("${PREFIX}counter", {
        type   => 'counter',
        params => {
            source      => { collections => [$COLL],
                             events => [ { type => 'click', weight => 1, name => "${PREFIX}click" } ] },
            destination => { collection => $COLL, counter_field => 'popularity' },
        },
    });
    ok($ts->analytics->click("${PREFIX}click", { doc_id => '7', user_id => 'u1' })->{ok},
       'a click event is accepted');

    ## The other half of that pairing: the server must accept the same
    ## identifier as a header on the search, or events can only be attributed
    ## by IP address.
    my $attributed = $ts->search($COLL, { q => 'laptop', query_by => 'name' },
                                 headers => { 'x-typesense-user-id' => 'u1' });
    ok($attributed->{found} > 0, 'a search carrying x-typesense-user-id is served normally');

    ## Aggregation lands in an ordinary collection, so top_queries is a search.
    ## It is flushed on the server's own interval, so assert the shape, not the
    ## contents: a fresh server has nothing aggregated yet.
    ok(exists $ts->analytics->top_queries($QUERIES, limit => 5)->{found},
       'top_queries searches the destination collection');

    $ts->analytics->delete_rule("${PREFIX}popular");
    is($ts->analytics->delete_rule("${PREFIX}popular"), undef, 'deleting a gone rule is not an error');
};

subtest 'API keys, and a scoped key derived without the server' => sub {
    my $k = $ts->keys->create({
        description => "${PREFIX}search only",
        actions     => ['documents:search'],
        collections => [$COLL],
    });
    ok(length $k->{value}, 'create returns the key in the clear, this once');
    ok(defined $k->{id}, 'and an id');
    ok((grep { $_->{id} == $k->{id} } @{ $ts->keys->list->{keys} }), 'listed (by prefix only)');

    ## The real test of scoped(): the server must accept a key we built here,
    ## locally, and honour the filter baked into it.
    my $scoped = $ts->keys->scoped($k->{value}, { filter_by => 'popularity:>20' });
    my $browser = Typesense::Client->new(url => $url, api_key => $scoped);
    my $r = $browser->search($COLL, { q => '*', query_by => 'name' });
    ok($r->{found} > 0, 'the derived key is accepted by the server');
    ok((!grep { $_->{document}{popularity} <= 20 } @{ $r->{hits} }),
       'and the embedded filter is enforced on every hit');

    ## Same key, no second client: the admin client borrows it per request.
    my $borrowed = $ts->search($COLL, { q => '*', query_by => 'name' },
                               headers => { 'X-TYPESENSE-API-KEY' => $scoped });
    ok((!grep { $_->{document}{popularity} <= 20 } @{ $borrowed->{hits} }),
       'a per-request scoped key is honoured, filter and all');

    $ts->keys->delete($k->{id});
    is($ts->keys->delete($k->{id}), undef, 'deleting a gone key is not an error');
};

subtest 'errors carry the real server message' => sub {
    my $r = eval { $ts->collections->get('no_such_collection_here') };
    my $err = $@;
    isa_ok($err, 'Typesense::Client::Error');
    is($err->code, 404, 'code');
    ok($err->is_not_found, 'is_not_found');
    is($err->endpoint, 'GET /collections/no_such_collection_here', 'endpoint');

    eval { $ts->collections->create({ name => "${PREFIX}bad", fields => [ { name => 'x', type => 'nope' } ] }) };
    is($@->code, 400, 'a bad field type is a 400');
    ok(length $@->message, "with the server's own message: " . $@->message);

    my $soft = Typesense::Client->new(url => $url, api_key => $key, fail_open => 1);
    is($soft->collections->get('no_such_collection_here'), undef, 'fail_open returns undef');
    is($soft->last_error->code, 404, '... and stores the error');
};

done_testing();
