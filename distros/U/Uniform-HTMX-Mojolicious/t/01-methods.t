use strict;
use warnings;
use Test::More;
use Test::Exception;
use JSON::PP qw(decode_json);
use Mojolicious::Controller;
use Mojo::Transaction::HTTP;
use Uniform::HTMX::Mojolicious;

# Test 1: Exception on invalid controller argument
dies_ok { Uniform::HTMX::Mojolicious->new("not an object") } 'croaks on non-hash argument';

# Setup mock Mojolicious controller attached to an HTTP transaction
my $tx = Mojo::Transaction::HTTP->new;
my $c  = Mojolicious::Controller->new(tx => $tx);

$c->req->headers->header('HX-Request'     => 'true');
$c->req->headers->header('HX-Target'      => 'main-content');
$c->req->headers->header('HX-Current-URL' => 'http://localhost/app');

my $htmx = Uniform::HTMX::Mojolicious->new($c);

# Test 2: Request Inspection
ok($htmx->is_htmx, 'is_htmx detects HX-Request');
is($htmx->target, 'main-content', 'target extracts HX-Target');
is($htmx->current_url, 'http://localhost/app', 'current_url extracts HX-Current-URL');

# Test 3: Response Headers Injection
$htmx->res_reswap('outerHTML')
->res_trigger('itemUpdated', { id => 123 });

$htmx->apply($c);

my $res_headers = $c->res->headers;
is($res_headers->header('HX-Reswap'), 'outerHTML', 'HX-Reswap header injected into Mojo response');

# Decode HX-Trigger JSON string
my $trigger_data = decode_json($res_headers->header('HX-Trigger'));
is_deeply($trigger_data, { itemUpdated => { id => 123 } }, 'HX-Trigger encodes event payload correctly');

done_testing();
