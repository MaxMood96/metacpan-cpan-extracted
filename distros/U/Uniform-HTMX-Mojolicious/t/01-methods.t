
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Deep;

use Uniform::HTMX::Mojolicious;

# =========================================================================
# MOCK MOJO ENVIRONMENT SETUP
# =========================================================================
package Mock::Mojo::Headers {
    sub new {
        my ($class, $data) = @_;
        return bless { storage => $data || {} }, $class;
    }
    sub names {
        my ($self) = @_;
        return [ keys %{$self->{storage}} ];
    }
    sub header {
        my ($self, $k, $v) = @_;
        $self->{storage}->{$k} = $v if defined $v;
        return $self->{storage}->{$k};
    }
}

package Mock::Mojo::Req {
    sub new {
        my ($class, $data) = @_;
        return bless { h => Mock::Mojo::Headers->new($data) }, $class;
    }
    sub headers { $_[0]->{h} }
}

package Mock::Mojo::Res {
    sub new {
        my ($class) = @_;
        return bless { h => Mock::Mojo::Headers->new }, $class;
    }
    sub headers { $_[0]->{h} }
}

package Mock::Mojo::Controller {
    sub new {
        my ($class, $mock_inbound) = @_;
        return bless {
            req => Mock::Mojo::Req->new($mock_inbound),
            res => Mock::Mojo::Res->new,
        }, $class;
    }
    sub req { $_[0]->{req} }
    sub res { $_[0]->{res} }
}

package main;

# =========================================================================
# TEST GROUP 1: Inbound Processing & Inheritance
# =========================================================================
my $mock_c = Mock::Mojo::Controller->new({
    'HTTP_HX_REQUEST' => 'true',
    'HX-Target'       => 'live-grid-panel',
});

my $hx = Uniform::HTMX::Mojolicious->new($mock_c);

isa_ok($hx, 'Uniform::HTMX', 'Mojolicious connector correctly inherits from abstract core base');
is($hx->is_htmx, 1, 'Correctly evaluates request parameters via Mojo structures');
is($hx->target, 'live-grid-panel', 'Resolves CGI proxy variable casing variants flawlessly');

# =========================================================================
# TEST GROUP 2: Outbound Context Mapping
# =========================================================================
$hx->res_retarget('#global-error-alert')
->res_reswap('innerHTML')
->apply;

my $applied_headers = $mock_c->res->headers->{storage};

cmp_deeply(
    $applied_headers,
    {
        'HX-Retarget' => '#global-error-alert',
        'HX-Reswap'   => 'innerHTML',
    },
    'Successfully pushes changes straight onto the Mojo response header stack'
);

# =========================================================================
# TEST GROUP 3: Type Exceptions
# =========================================================================
dies_ok {
    Uniform::HTMX::Mojolicious->new("Plain string controller token fallback check");
} 'Throws an exception if context structure mismatches framework signatures';

done_testing();
