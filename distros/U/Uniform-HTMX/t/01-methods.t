use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../Uniform-Base/lib"; # Ensure your local Uniform-Base lib is accessible during development

use Test::More;
use Test::Exception;
use Test::Deep;
use JSON::MaybeXS;

use Uniform::HTMX;

# --- Setup a clean inline test driver ---
package Mock::Uniform::HTMX;
use parent 'Uniform::HTMX';

sub new {
    my ($class, $mock_raw_headers) = @_;
    my $self = bless { in => {}, out => {} }, $class;
    $self->{in} = $self->_normalize_headers($mock_raw_headers);
    return $self;
}
package main;

# =========================================================================
# TEST GROUP 1: Standard Inbound Parsing
# =========================================================================
my $standard_headers = {
    'HX-Request' => 'true',
    'HX-Target'  => 'main-layout-panel',
};
my $hx = Mock::Uniform::HTMX->new($standard_headers);

isa_ok($hx, 'Uniform::HTMX', 'Mock instance correctly inherits abstract baseline');
is($hx->is_htmx, 1, 'is_htmx identifies a valid "true" state');
is($hx->target, 'main-layout-panel', 'target reads standard fields correctly');

# =========================================================================
# TEST GROUP 2: Advanced Normalization & Priority Ranking
# =========================================================================
my $messy_headers = {
    '  hx_target  ' => 'messy-box',
    'HTTP-HX-BOOSTED' => 'true',
};
my $hx_messy = Mock::Uniform::HTMX->new($messy_headers);
is($hx_messy->target, 'messy-box', 'Trims whitespace and normalizes underscores to hyphens');
is($hx_messy->is_boosted, 1, 'Strips HTTP_ environment prefixes cleanly');

my $array_headers = {
    'hx-trigger' => [ 'ignored-first-id', 'winning-last-id' ],
};
my $hx_array = Mock::Uniform::HTMX->new($array_headers);
is($hx_array->trigger_id, 'winning-last-id', 'Array values are successfully reduced to the last element');

my $conflict_headers = {
    'HTTP_HX_TARGET' => 'loser-env-variable',
    'HX-Target'      => 'winner-real-header',
};
my $hx_conflict = Mock::Uniform::HTMX->new($conflict_headers);
is($hx_conflict->target, 'winner-real-header', 'Real HTTP header definitions cleanly override environment variables');

# =========================================================================
# TEST GROUP 3: Outbound Response Logic & Serialization
# =========================================================================
$hx->res_retarget('#error-box')
->res_reswap('outerHTML')
->res_trigger('showAlert', { type => 'error', msg => 'Action failed' });

is($hx->{out}->{'HX-Retarget'}, '#error-box', 'Updates target modification layer');
is($hx->{out}->{'HX-Reswap'}, 'outerHTML', 'Updates swap strategy modification layer');

my $decoded_payload = decode_json($hx->{out}->{'HX-Trigger'});
cmp_deeply(
    $decoded_payload,
    { showAlert => { type => 'error', msg => 'Action failed' } },
    'Handles complex JSON serialization maps gracefully without key-ordering dependence'
);

# =========================================================================
# TEST GROUP 4: Strict Security & Exception Boundaries
# =========================================================================

# UPGRADED CHECK: Asserts that an object-oriented Uniform::Exceptions reference is thrown
throws_ok {
    Mock::Uniform::HTMX->new("Invalid String Input");
} 'Uniform::Exceptions', 'Throws structured object exception when inputs are not a HASH reference';

dies_ok {
    $hx->res_reswap("innerHTML\r\nInjected-Header: evil-payload");
} 'Security guard catches and blocks carrier return (\r) injections';

dies_ok {
    $hx->res_reswap("innerHTML\nInjected-Header: evil-payload");
} 'Security guard catches and blocks newline (\n) injections';

# =========================================================================
# TEST GROUP 5: Advanced Incoming Event Triggers
# =========================================================================
my $hx_plain_trigger = Mock::Uniform::HTMX->new({ 'HX-Trigger' => 'login-form-id' });
is($hx_plain_trigger->trigger_event, 'login-form-id', 'trigger_event falls back to a plain string if it is not JSON');

my $hx_json_trigger = Mock::Uniform::HTMX->new({ 'HX-Trigger' => '{"showDetails":{"row":5,"status":"active"}}' });
my $expected_structure = { showDetails => { row => 5, status => 'active' } };
my $test_description   = 'trigger_event successfully parses and decodes structured htmx client event maps';

cmp_deeply(
    $hx_json_trigger->trigger_event,
    $expected_structure,
    $test_description
);

done_testing();
