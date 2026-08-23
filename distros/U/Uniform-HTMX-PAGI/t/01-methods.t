use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Deep;

use Uniform::HTMX::PAGI;

# =========================================================================
# TEST GROUP 1: Inbound Processing & Nested List Flattening
# =========================================================================
my $mock_scope = {
    type    => 'http',
    path    => '/async-stream-endpoint',
    headers => [
        [ 'hx-request' => 'true' ],
        [ 'HX-Target'  => 'dashboard-grid-panel' ],
        # Simulating matching keys to verify your multi-value last-scalar-wins reduction rule
        [ 'hx-trigger' => 'first-clicked-id' ],
        [ 'hx-trigger' => 'winning-last-id' ],
    ],
};

my $hx = Uniform::HTMX::PAGI->new($mock_scope);

isa_ok($hx, 'Uniform::HTMX', 'PAGI connector correctly inherits from abstract core base');
is($hx->is_htmx, 1, 'Successfully reads incoming connection context from PAGI array structures');
is($hx->target, 'dashboard-grid-panel', 'Normalizes mixed case keys inside multi-tier arrays flawlessly');
is($hx->trigger_id, 'winning-last-id', 'Array reduction engine successfully isolates winning trailing duplicate fields');

# =========================================================================
# TEST GROUP 2: Outbound Context Marshalling
# =========================================================================
$hx->res_retarget('#realtime-error-banner')
->res_reswap('outerHTML')
->apply;

my $compiled_outbound = $mock_scope->{'htmx.outbound'};

cmp_deeply(
    $compiled_outbound,
    bag(
        [ 'HX-Retarget' => '#realtime-error-banner' ],
        [ 'HX-Reswap'   => 'outerHTML' ],
    ),
    'Successfully maps and flushes headers back down into standard PAGI array-of-arrays specifications'
);

# =========================================================================
# TEST GROUP 3: Security Exception Bounds
# =========================================================================
dies_ok {
    Uniform::HTMX::PAGI->new({ type => 'websocket' });
} 'Throws strict validation error if connection scope does not declare http types';

done_testing();
