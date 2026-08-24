use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Deep;
use JSON::PP qw(decode_json);
use Uniform::HTMX::PAGI;

# Test 1: Exception on invalid environment constructor parameter
dies_ok { Uniform::HTMX::PAGI->new("not a hash") } 'croaks on non-hash argument';

# Setup mock PAGI environment
my %env = (
    HTTP_HX_REQUEST     => 'true',
    HTTP_HX_TARGET      => 'main-content',
    HTTP_HX_CURRENT_URL => 'http://localhost/app',
);

my $htmx = Uniform::HTMX::PAGI->new(\%env);

# Test 2: Request Inspection
ok($htmx->is_htmx, 'is_htmx detects HX-Request');
is($htmx->target, 'main-content', 'target extracts HX-Target');
is($htmx->current_url, 'http://localhost/app', 'current_url extracts HX-Current-URL');

# Test 3: Response Headers Injection into PAGI Response Array
$htmx->res_reswap('outerHTML')
->res_trigger('itemUpdated', { id => 123 });

my $pagi_res = [ 200, [ 'Content-Type' => 'text/html' ], [ '<div>Updated</div>' ] ];
my $applied  = $htmx->apply($pagi_res);

# Convert response header arrayref into key-value pairs
my %applied_headers = @{ $applied->[1] };

is($applied_headers{'Content-Type'}, 'text/html', 'Content-Type header preserved');
is($applied_headers{'HX-Reswap'}, 'outerHTML', 'HX-Reswap header injected');

# Decode HX-Trigger JSON string to verify structure independently of key ordering
my $trigger_data = decode_json($applied_headers{'HX-Trigger'});

cmp_deeply(
    $trigger_data,
    { itemUpdated => { id => 123 } },
    'HX-Trigger encodes event name and payload correctly'
);

done_testing();
