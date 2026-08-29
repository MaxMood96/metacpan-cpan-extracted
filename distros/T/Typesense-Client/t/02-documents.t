# PURPOSE: Verify JSONL bulk import, batching and export decoding
# LAYER:   unit (in-process Mojolicious server)
# COVERS:  Typesense::Client::Documents

use v5.38;
use warnings;
use Test::More;
use Mojolicious;
use Mojo::Server::Daemon;
use Mojo::IOLoop;
use Mojo::JSON qw(encode_json);

use Typesense::Client;

our @bodies;
our $mode = 'mixed';

my $app = Mojolicious->new;
$app->log->level('fatal');
$app->routes->post('/collections/:c/documents/import' => sub ($c) {
    push @bodies, { body => $c->req->body, action => $c->req->url->query->param('action') };
    my @lines = split /\n/, $c->req->body;
    my $n = scalar @lines;
    ## Typesense answers 200 even when lines are rejected: one result line per
    ## document, each with its own flag.
    return $c->render(data => join("\n", ('{"success":true}') x $n)) if $mode eq 'allok';
    my @out = ('{"success":true}') x $n;
    $out[0] = '{"success":false,"error":"Field `x` has been declared as int32"}';
    return $c->render(data => join("\n", @out));
});
$app->routes->get('/collections/:c/documents/export' => sub ($c) {
    return $c->render(data => qq({"id":"1","n":"a"}\n{"id":"2","n":"b"}\n));
});

my $daemon = Mojo::Server::Daemon->new(
    app => $app, listen => ['http://127.0.0.1'], silent => 1)->start;
my $port = $daemon->ports->[0];

my $ts = Typesense::Client->new(
    url => "http://127.0.0.1:$port", api_key => 'k',
    ua      => Mojo::UserAgent->new(ioloop => Mojo::IOLoop->singleton)->request_timeout(10),
    bulk_ua => Mojo::UserAgent->new(ioloop => Mojo::IOLoop->singleton)->request_timeout(10),
);

subtest 'JSONL and per-document summary' => sub {
    @bodies = ();
    my $r = $ts->documents->import_docs('p', [ { id => 1 }, { id => 2 }, { id => 3 } ]);
    is($r->{total},  3, 'total');
    is($r->{ok},     2, 'succeeded');
    is($r->{failed}, 1, 'failed - HTTP 200 alone does not mean it was indexed');
    like($r->{errors}[0], qr/int32/, 'keeps the error line');
    is(scalar @bodies, 1, 'a single round trip');
    is($bodies[0]{action}, 'upsert', 'default action');
    my @sent = split /\n/, $bodies[0]{body};
    is(scalar @sent, 3, 'one JSON line per document');
    unlike($bodies[0]{body}, qr/\[|\]/, 'JSONL, not a JSON array');
};

subtest 'batches' => sub {
    @bodies = ();
    local $mode = 'allok';
    my @docs = map { { id => $_ } } 1 .. 10;
    my $r = $ts->documents->import_docs('p', \@docs, batch_size => 4);
    is(scalar @bodies, 3, '10 documents in batches of 4 = 3 round trips');
    is($r->{ok}, 10, 'sum of every batch');
    is($r->{failed}, 0, 'none fail');
};

subtest 'an empty list does not call the server' => sub {
    @bodies = ();
    my $r = $ts->documents->import_docs('p', []);
    is(scalar @bodies, 0, 'no request');
    is_deeply($r, { total => 0, ok => 0, failed => 0, errors => [] }, 'zeroed summary');
};

subtest 'configurable action' => sub {
    @bodies = ();
    local $mode = 'allok';
    $ts->documents->import_docs('p', [ { id => 1 } ], action => 'create');
    is($bodies[0]{action}, 'create', 'action=create');
};

subtest 'export' => sub {
    my $docs = $ts->documents->export('p');
    is_deeply($docs, [ { id => '1', n => 'a' }, { id => '2', n => 'b' } ], 'decodes JSONL');
    my $raw = $ts->documents->export('p', raw => 1);
    like($raw, qr/^\{"id":"1"/, 'raw returns the text as it arrived');
};

done_testing();
