#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

use IO::K8s::K3s::V1::HelmChart;
use IO::K8s::K3s::V1::HelmChartConfig;
use IO::K8s::Traefik::V1alpha1::TraefikService;
use IO::K8s::Traefik::V1alpha1::Middleware;
use IO::K8s::Traefik::V1alpha1::MiddlewareTCP;
use IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta;

# --- HelmManaged ---

subtest 'helm: from_repo and set_version' => sub {
    my $chart = IO::K8s::K3s::V1::HelmChart->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'traefik', namespace => 'kube-system',
        ),
    );

    $chart->from_repo('https://traefik.github.io/charts', 'traefik')
          ->set_version('25.0.0');

    is($chart->spec->{repo}, 'https://traefik.github.io/charts', 'repo URL');
    is($chart->spec->{chart}, 'traefik', 'chart name');
    is($chart->spec->{version}, '25.0.0', 'version');
};

subtest 'helm: set_values' => sub {
    my $chart = IO::K8s::K3s::V1::HelmChart->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'traefik', namespace => 'kube-system',
        ),
    );

    $chart->set_values(replicas => 3, 'ingress.enabled' => 1);
    is($chart->spec->{set}{replicas}, 3, 'set value');
    is($chart->spec->{set}{'ingress.enabled'}, 1, 'dotted key');
};

subtest 'helm: set_values_yaml' => sub {
    my $chart = IO::K8s::K3s::V1::HelmChart->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'traefik', namespace => 'kube-system',
        ),
    );

    $chart->set_values_yaml("replicas: 3\ningress:\n  enabled: true");
    like($chart->spec->{valuesContent}, qr/replicas: 3/, 'YAML content');
};

subtest 'helm: HelmChartConfig' => sub {
    my $config = IO::K8s::K3s::V1::HelmChartConfig->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'traefik', namespace => 'kube-system',
        ),
    );

    $config->set_values_yaml("additionalArguments:\n  - '--log.level=DEBUG'");
    ok($config->spec->{valuesContent}, 'config values set');
};

subtest 'helm: chaining' => sub {
    my $chart = IO::K8s::K3s::V1::HelmChart->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'traefik', namespace => 'kube-system',
        ),
    );

    my $result = $chart->from_repo('https://charts.example.com', 'myapp')
                       ->set_version('1.0.0')
                       ->set_values(replicas => 2);
    is($result, $chart, 'chaining returns self');
};

# --- Loadbalanced ---

subtest 'loadbalanced: set_weighted' => sub {
    my $svc = IO::K8s::Traefik::V1alpha1::TraefikService->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'canary-svc',
        ),
    );

    $svc->set_weighted('api-v1', 90)
        ->set_weighted('api-v2', 10);

    my $services = $svc->spec->{weighted}{services};
    is(scalar @$services, 2, 'two weighted services');
    is($services->[0]{name}, 'api-v1', 'first service');
    is($services->[0]{weight}, 90, 'first weight');
    is($services->[1]{name}, 'api-v2', 'second service');
    is($services->[1]{weight}, 10, 'second weight');
};

subtest 'loadbalanced: update existing weight' => sub {
    my $svc = IO::K8s::Traefik::V1alpha1::TraefikService->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'canary-svc',
        ),
    );

    $svc->set_weighted('api-v1', 90)->set_weighted('api-v1', 50);
    my $services = $svc->spec->{weighted}{services};
    is(scalar @$services, 1, 'still one service');
    is($services->[0]{weight}, 50, 'weight updated');
};

subtest 'loadbalanced: mirror_to' => sub {
    my $svc = IO::K8s::Traefik::V1alpha1::TraefikService->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'mirror-svc',
        ),
    );

    $svc->mirror_to('canary', percent => 10);
    my $mirrors = $svc->spec->{mirroring}{mirrors};
    is(scalar @$mirrors, 1, 'one mirror');
    is($mirrors->[0]{name}, 'canary', 'mirror name');
    is($mirrors->[0]{percent}, 10, 'mirror percent');
};

# --- MiddlewareBuilder ---

subtest 'middleware: rate_limit' => sub {
    my $mw = IO::K8s::Traefik::V1alpha1::Middleware->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'rate-limit',
        ),
    );

    $mw->rate_limit(average => 100, burst => 200);
    is($mw->spec->{rateLimit}{average}, 100, 'rate average');
    is($mw->spec->{rateLimit}{burst}, 200, 'rate burst');
};

subtest 'middleware: basic_auth' => sub {
    my $mw = IO::K8s::Traefik::V1alpha1::Middleware->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'auth',
        ),
    );

    $mw->basic_auth(secret => 'htpasswd');
    is($mw->spec->{basicAuth}{secret}, 'htpasswd', 'auth secret');
};

subtest 'middleware: strip_prefix' => sub {
    my $mw = IO::K8s::Traefik::V1alpha1::Middleware->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'strip',
        ),
    );

    $mw->strip_prefix('/api');
    is_deeply($mw->spec->{stripPrefix}{prefixes}, ['/api'], 'prefix stripped');
};

subtest 'middleware: redirect_https' => sub {
    my $mw = IO::K8s::Traefik::V1alpha1::Middleware->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'redirect',
        ),
    );

    $mw->redirect_https;
    is($mw->spec->{redirectScheme}{scheme}, 'https', 'redirect scheme');
    is($mw->spec->{redirectScheme}{permanent}, 1, 'permanent redirect');
};

subtest 'middleware: headers' => sub {
    my $mw = IO::K8s::Traefik::V1alpha1::Middleware->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'headers',
        ),
    );

    $mw->add_request_header('X-Forwarded-Proto' => 'https')
       ->add_response_header('Strict-Transport-Security' => 'max-age=31536000');

    is($mw->spec->{headers}{customRequestHeaders}{'X-Forwarded-Proto'}, 'https', 'request header');
    is($mw->spec->{headers}{customResponseHeaders}{'Strict-Transport-Security'}, 'max-age=31536000', 'response header');
};

subtest 'middleware: chaining' => sub {
    my $mw = IO::K8s::Traefik::V1alpha1::Middleware->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'all-in-one',
        ),
    );

    my $result = $mw->rate_limit(average => 100)
                    ->add_request_header('X-Test' => 'value');
    is($result, $mw, 'chaining returns self');
};

subtest 'middlewareTCP: rate_limit' => sub {
    my $mw = IO::K8s::Traefik::V1alpha1::MiddlewareTCP->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'tcp-rate',
        ),
    );

    $mw->rate_limit(average => 50);
    is($mw->spec->{rateLimit}{average}, 50, 'TCP rate limit');
};

done_testing;
