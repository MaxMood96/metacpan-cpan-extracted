#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use IO::K8s;
use IO::K8s::Traefik;

# --- All Traefik CRD classes (all traefik.io/v1alpha1, all namespaced) ---

my %classes = (
    IngressRoute        => { plural => 'ingressroutes' },
    IngressRouteTCP     => { plural => 'ingressroutetcps' },
    IngressRouteUDP     => { plural => 'ingressrouteudps' },
    Middleware          => { plural => 'middlewares' },
    MiddlewareTCP       => { plural => 'middlewaretcps' },
    ServersTransport    => { plural => 'serverstransports' },
    ServersTransportTCP => { plural => 'serverstransporttcps' },
    TLSOption           => { plural => 'tlsoptions' },
    TLSStore            => { plural => 'tlsstores' },
    TraefikService      => { plural => 'traefikservices' },
);

# --- Load all 10 classes ---

subtest 'load all Traefik classes' => sub {
    for my $kind (sort keys %classes) {
        my $class = "IO::K8s::Traefik::V1alpha1::$kind";
        use_ok($class) or BAIL_OUT("Cannot load $class");
    }
};

# --- Verify api_version, kind, resource_plural, namespaced ---

subtest 'class metadata' => sub {
    for my $kind (sort keys %classes) {
        my $class = "IO::K8s::Traefik::V1alpha1::$kind";
        my $info = $classes{$kind};

        is($class->api_version, 'traefik.io/v1alpha1', "$kind api_version");
        is($class->kind, $kind, "$kind kind");
        is($class->resource_plural, $info->{plural}, "$kind resource_plural");
        ok($class->does('IO::K8s::Role::Namespaced'), "$kind is namespaced");
    }
};

# --- IO::K8s::Traefik resource_map completeness ---

subtest 'IO::K8s::Traefik resource_map' => sub {
    my $provider = IO::K8s::Traefik->new;
    ok($provider->does('IO::K8s::Role::ResourceMap'), 'consumes ResourceMap role');

    my $map = $provider->resource_map;
    is(scalar keys %$map, 10, 'resource_map has 10 entries');

    for my $kind (sort keys %classes) {
        ok(exists $map->{$kind}, "$kind in resource_map");
        is($map->{$kind}, "Traefik::V1alpha1::$kind", "$kind maps to correct class path");
    }
};

# --- new(with => ['IO::K8s::Traefik']) integration ---

subtest 'with constructor parameter' => sub {
    my $k8s = IO::K8s->new(with => ['IO::K8s::Traefik']);

    # All 10 Traefik kinds should be resolvable by short name
    for my $kind (sort keys %classes) {
        is($k8s->expand_class($kind), "IO::K8s::Traefik::V1alpha1::$kind",
            "expand_class('$kind') resolves");
    }

    # Core resources are unaffected
    is($k8s->expand_class('Pod'), 'IO::K8s::Api::Core::V1::Pod',
        'core Pod still resolves');
    is($k8s->expand_class('Deployment'), 'IO::K8s::Api::Apps::V1::Deployment',
        'core Deployment still resolves');
};

# --- new_object + inflate round-trip ---

subtest 'new_object and inflate round-trip' => sub {
    my $k8s = IO::K8s->new(with => ['IO::K8s::Traefik']);

    # Create an IngressRoute
    my $ir = $k8s->new_object('IngressRoute',
        metadata => { name => 'my-route', namespace => 'default' },
        spec => {
            entryPoints => ['web'],
            routes => [{ match => 'Host(`example.com`)', kind => 'Rule' }],
        },
    );
    isa_ok($ir, 'IO::K8s::Traefik::V1alpha1::IngressRoute');
    is($ir->kind, 'IngressRoute', 'kind');
    is($ir->api_version, 'traefik.io/v1alpha1', 'api_version');
    isa_ok($ir->metadata, 'IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta');
    is($ir->metadata->name, 'my-route', 'name');
    is($ir->metadata->namespace, 'default', 'namespace');

    # Serialize and re-inflate
    my $json = $k8s->object_to_json($ir);
    like($json, qr/"apiVersion":"traefik\.io\/v1alpha1"/, 'JSON has apiVersion');
    like($json, qr/"kind":"IngressRoute"/, 'JSON has kind');

    my $re = $k8s->inflate($json);
    isa_ok($re, 'IO::K8s::Traefik::V1alpha1::IngressRoute', 're-inflated');
    is($re->metadata->name, 'my-route', 'round-trip name preserved');
    is($re->metadata->namespace, 'default', 'round-trip namespace preserved');

    # Create a Middleware
    my $mw = $k8s->new_object('Middleware',
        metadata => { name => 'rate-limit', namespace => 'default' },
        spec => { rateLimit => { average => 100, burst => 200 } },
    );
    isa_ok($mw, 'IO::K8s::Traefik::V1alpha1::Middleware');
    ok($mw->does('IO::K8s::Role::Namespaced'), 'Middleware is namespaced');

    # Round-trip Middleware
    my $mw_re = $k8s->inflate($k8s->object_to_json($mw));
    isa_ok($mw_re, 'IO::K8s::Traefik::V1alpha1::Middleware');
    is($mw_re->metadata->name, 'rate-limit', 'Middleware round-trip');
};

# --- to_yaml output ---

subtest 'to_yaml output' => sub {
    my $k8s = IO::K8s->new(with => ['IO::K8s::Traefik']);

    my $ir = $k8s->new_object('IngressRoute',
        metadata => { name => 'test-route', namespace => 'default' },
        spec => { entryPoints => ['web'] },
    );
    my $yaml = $ir->to_yaml;
    like($yaml, qr/apiVersion: traefik\.io\/v1alpha1/, 'YAML apiVersion');
    like($yaml, qr/kind: IngressRoute/, 'YAML kind');
    like($yaml, qr/name: test-route/, 'YAML name');
    like($yaml, qr/namespace: default/, 'YAML namespace');
};

# --- Domain-qualified expand_class ---

subtest 'domain-qualified expand_class' => sub {
    my $k8s = IO::K8s->new(with => ['IO::K8s::Traefik']);

    for my $kind (sort keys %classes) {
        is($k8s->expand_class("traefik.io/v1alpha1/$kind"),
            "IO::K8s::Traefik::V1alpha1::$kind",
            "traefik.io/v1alpha1/$kind resolves");
    }

    # api_version parameter style
    is($k8s->expand_class('IngressRoute', 'traefik.io/v1alpha1'),
        'IO::K8s::Traefik::V1alpha1::IngressRoute',
        'api_version parameter disambiguation');
};

# --- pk8s DSL with Traefik kinds ---

subtest 'pk8s DSL with Traefik kinds' => sub {
    require File::Temp;
    my $k8s = IO::K8s->new(with => ['IO::K8s::Traefik']);

    my ($fh, $filename) = File::Temp::tempfile(SUFFIX => '.pk8s', UNLINK => 1);
    print $fh q{
        IngressRoute {
            name => 'my-route',
            namespace => 'default',
            spec => { entryPoints => ['web'] },
        };

        Middleware {
            name => 'rate-limit',
            namespace => 'default',
            spec => { rateLimit => { average => 100 } },
        };

        TraefikService {
            name => 'mirror-svc',
            namespace => 'default',
            spec => { mirroring => { name => 'svc1' } },
        };
    };
    close $fh;

    my $objs = $k8s->load($filename);
    is(scalar(@$objs), 3, 'pk8s loaded 3 Traefik objects');

    my ($ir, $mw, $ts) = @$objs;

    isa_ok($ir, 'IO::K8s::Traefik::V1alpha1::IngressRoute');
    is($ir->kind, 'IngressRoute', 'pk8s IngressRoute kind');
    is($ir->metadata->name, 'my-route', 'pk8s IngressRoute name');

    isa_ok($mw, 'IO::K8s::Traefik::V1alpha1::Middleware');
    is($mw->kind, 'Middleware', 'pk8s Middleware kind');

    isa_ok($ts, 'IO::K8s::Traefik::V1alpha1::TraefikService');
    is($ts->kind, 'TraefikService', 'pk8s TraefikService kind');
    is($ts->api_version, 'traefik.io/v1alpha1', 'pk8s TraefikService api_version');
};

done_testing;
