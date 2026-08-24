use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Deep;

BEGIN {
    use_ok('Uniform::HTMX::PSGI');
}

# 1. Setup a valid mock PSGI standard environment hash layout
my $mock_env = {
    'REQUEST_METHOD'  => 'POST',
    'PATH_INFO'       => '/submit-form',
    'HTTP_HX_REQUEST' => 'true',
    'HTTP_HX_TARGET'  => 'modal-body-container',
};

my $hx = Uniform::HTMX::PSGI->new($mock_env);

# 2. Verify Inheritance and Input Routing
isa_ok($hx, 'Uniform::HTMX', 'PSGI connector correctly inherits from abstract core base');
is($hx->is_htmx, 1, 'Correctly reads inbound connection context from standard HTTP_ keys');
is($hx->target, 'modal-body-container', 'Successfully resolves CGI environment prefixes to htmx variables');

# 3. Verify Outbound State Compiling (Updated for v0.16)
$hx->res_retarget('#global-error')
->res_reswap('innerHTML');

# Mock a standard PSGI response array
my $psgi_res = [ 200, [ 'Content-Type' => 'text/html' ], [ 'Error rendering form' ] ];
my $modified_res = $hx->apply($psgi_res);

my %headers = @{ $modified_res->[1] };
is($headers{'HX-Retarget'}, '#global-error', 'Correctly flushes HX-Retarget into PSGI arrayref');
is($headers{'HX-Reswap'}, 'innerHTML', 'Correctly flushes HX-Reswap into PSGI arrayref');

# 4. Verify Exception Scoping Bounds
dies_ok {
    Uniform::HTMX::PSGI->new("Not a hash ref string");
} 'Fails cleanly if structural context parameter is not a valid HASH reference';

# 5. Explicit Response Object Mapping

# Mock a tiny inline object that mimics Plack::Response's header API
package Mock::Plack::Response::Headers {
    sub new { bless { storage => {} }, shift }
    sub header {
        my ($self, $k, $v) = @_;
        $self->{storage}->{$k} = $v;
    }
}
package Mock::Plack::Response {
    sub new { bless { h => Mock::Plack::Response::Headers->new }, shift }
    sub headers { $_[0]->{h} }
}
package main;

my $mock_res = Mock::Plack::Response->new;

# Call apply passing our mock response object
$hx->res_trigger('CustomEvent')->apply($mock_res);

is(
    $mock_res->headers->{storage}->{'HX-Trigger'},
   'CustomEvent',
   'apply() successfully routes modifications straight to explicit response objects'
);

done_testing();
