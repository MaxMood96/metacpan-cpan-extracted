use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use Test::Exception;
use JSON::MaybeXS;

use Uniform::HTMX;

# =========================================================================
# TEST GROUP 1: Basic driver() construction and request inspection
# =========================================================================
my $driver = Uniform::HTMX->driver(
    extract => sub {
        my ($scope) = @_;
        return %{ $scope->{headers} };
    },
    apply => sub {
        my ($self, $scope, $out_headers, @extra) = @_;
        return { headers => $out_headers, extra => \@extra };
    },
);

is(ref($driver), 'CODE', 'driver() returns a plain coderef');

my $scope = { headers => { 'HX-Request' => 'true', 'HX-Target' => '#panel' } };
my $hx = $driver->($scope);

isa_ok($hx, 'Uniform::HTMX', 'driver()-built instance is-a Uniform::HTMX');
is($hx->is_htmx, 1, 'driver()-built instance correctly reads is_htmx');
is($hx->target, '#panel', 'driver()-built instance correctly reads target');

# =========================================================================
# TEST GROUP 2: Response manipulation flows through to apply()
# =========================================================================
$hx->res_trigger('saved', { id => 7 });
my $result = $hx->apply('extra-arg-1', 'extra-arg-2');

my $decoded = decode_json($result->{headers}->{'HX-Trigger'});
is_deeply(
    $decoded,
    { saved => { id => 7 } },
    'apply() receives the accumulated outbound headers, JSON intact'
);
is_deeply(
    $result->{extra},
    [ 'extra-arg-1', 'extra-arg-2' ],
    'apply() forwards extra arguments past $self and $scope through to the apply coderef'
);

# =========================================================================
# TEST GROUP 3: Independent instances do not share state
# =========================================================================
my $scope2 = { headers => { 'HX-Request' => 'false' } };
my $hx2 = $driver->($scope2);

is($hx2->is_htmx, 0, 'Second driver()-built instance reads its own headers independently');
is(
    scalar(keys %{ $hx2->_out }), 0,
    'Second driver()-built instance has no outbound headers leaked from the first'
);

# =========================================================================
# TEST GROUP 4: Required arguments are enforced
# =========================================================================
throws_ok {
    Uniform::HTMX->driver(apply => sub { });
} qr/requires a 'extract' coderef/, 'driver() rejects a missing extract coderef';

throws_ok {
    Uniform::HTMX->driver(extract => sub { });
} qr/requires a 'apply' coderef/, 'driver() rejects a missing apply coderef';

# =========================================================================
# TEST GROUP 5: driver() composes with subclass hook overrides
# =========================================================================
package Mock::Uniform::HTMX::Custom;
use parent 'Uniform::HTMX';

sub _encode_json {
    my ($self, $data) = @_;
    my $json = Uniform::HTMX::encode_json($data);
    $json =~ tr/"/'/;    # trivial marker proving the override actually ran
    return $json;
}
package main;

my $custom_driver = Mock::Uniform::HTMX::Custom->driver(
    extract => sub { return %{ $_[0] } },
    apply   => sub { return $_[2] },
);

my $custom_hx = $custom_driver->({ 'HX-Request' => 'true' });
isa_ok($custom_hx, 'Mock::Uniform::HTMX::Custom', 'driver() called on a subclass builds an instance of that subclass');

$custom_hx->res_trigger('x', { a => 1 });
my $custom_out = $custom_hx->apply;
like(
    $custom_out->{'HX-Trigger'}, qr/'/,
    'driver() built on a subclass inherits that subclass hook overrides (_encode_json)'
);

done_testing();
