#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

use IO::K8s::Traefik::V1alpha1::IngressRoute;
use IO::K8s::GatewayAPI::V1::HTTPRoute;
use IO::K8s::GatewayAPI::V1::GRPCRoute;
use IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta;

# --- Traefik IngressRoute ---

subtest 'traefik: add_hostname' => sub {
    my $ir = IO::K8s::Traefik::V1alpha1::IngressRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
        spec => {},
    );

    $ir->add_hostname('example.com', 'www.example.com');
    my $routes = $ir->spec->{routes};
    ok($routes, 'routes created');
    like($routes->[0]{match}, qr/Host\(`example\.com`\)/, 'host match rule');
    like($routes->[0]{match}, qr/Host\(`www\.example\.com`\)/, 'second host');
};

subtest 'traefik: add_backend' => sub {
    my $ir = IO::K8s::Traefik::V1alpha1::IngressRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
        spec => { routes => [{ match => 'Host(`example.com`)', kind => 'Rule', services => [] }] },
    );

    $ir->add_backend('api-v1', port => 8080, weight => 90);
    $ir->add_backend('api-v2', port => 8080, weight => 10);
    my $services = $ir->spec->{routes}[0]{services};
    is(scalar @$services, 2, 'two backends');
    is($services->[0]{name}, 'api-v1', 'first backend name');
    is($services->[0]{weight}, 90, 'first backend weight');
    is($services->[1]{name}, 'api-v2', 'second backend name');
};

subtest 'traefik: add_path_match' => sub {
    my $ir = IO::K8s::Traefik::V1alpha1::IngressRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
        spec => { routes => [{}] },
    );

    $ir->add_path_match('/api', type => 'Prefix');
    is($ir->spec->{routes}[0]{match}, 'PathPrefix(`/api`)', 'prefix path match');
};

subtest 'traefik: add_header_match' => sub {
    my $ir = IO::K8s::Traefik::V1alpha1::IngressRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
        spec => { routes => [{ match => 'Host(`example.com`)' }] },
    );

    $ir->add_header_match('X-Version' => 'v2');
    like($ir->spec->{routes}[0]{match}, qr/Header\(`X-Version`, `v2`\)/, 'header match appended');
    like($ir->spec->{routes}[0]{match}, qr/Host\(`example\.com`\)/, 'original match preserved');
};

# --- Gateway API HTTPRoute ---

subtest 'gateway: add_hostname' => sub {
    my $hr = IO::K8s::GatewayAPI::V1::HTTPRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
        spec => {},
    );

    $hr->add_hostname('example.com', 'api.example.com');
    is_deeply($hr->spec->{hostnames}, ['example.com', 'api.example.com'], 'hostnames set');
};

subtest 'gateway: add_backend' => sub {
    my $hr = IO::K8s::GatewayAPI::V1::HTTPRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
        spec => {},
    );

    $hr->add_backend('api-v1', port => 8080, weight => 90);
    $hr->add_backend('api-v2', port => 8080, weight => 10);
    my $backends = $hr->spec->{rules}[0]{backendRefs};
    is(scalar @$backends, 2, 'two backends');
    is($backends->[0]{name}, 'api-v1', 'first backend');
    is($backends->[0]{weight}, 90, 'first weight');
    is($backends->[1]{port}, 8080, 'second port');
};

subtest 'gateway: add_path_match' => sub {
    my $hr = IO::K8s::GatewayAPI::V1::HTTPRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
        spec => {},
    );

    $hr->add_path_match('/api', type => 'Prefix');
    my $matches = $hr->spec->{rules}[0]{matches};
    is($matches->[0]{path}{type}, 'Prefix', 'path type');
    is($matches->[0]{path}{value}, '/api', 'path value');
};

subtest 'gateway: add_header_match' => sub {
    my $hr = IO::K8s::GatewayAPI::V1::HTTPRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
        spec => {},
    );

    $hr->add_header_match('X-Version' => 'v2');
    my $headers = $hr->spec->{rules}[0]{matches}[0]{headers};
    is($headers->[0]{name}, 'X-Version', 'header name');
    is($headers->[0]{value}, 'v2', 'header value');
};

subtest 'gateway: chaining' => sub {
    my $hr = IO::K8s::GatewayAPI::V1::HTTPRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
    );

    my $result = $hr->add_hostname('example.com')
                    ->add_backend('web', port => 80);
    is($result, $hr, 'chaining returns self');
    ok($hr->spec->{hostnames}, 'hostname set via chain');
    ok($hr->spec->{rules}[0]{backendRefs}, 'backend set via chain');
};

# --- GRPCRoute ---

subtest 'grpcroute: add_hostname and backend' => sub {
    my $gr = IO::K8s::GatewayAPI::V1::GRPCRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'grpc-route',
        ),
    );

    $gr->add_hostname('grpc.example.com')
       ->add_backend('grpc-service', port => 50051);

    is_deeply($gr->spec->{hostnames}, ['grpc.example.com'], 'grpc hostname');
    is($gr->spec->{rules}[0]{backendRefs}[0]{name}, 'grpc-service', 'grpc backend');
};

done_testing;
