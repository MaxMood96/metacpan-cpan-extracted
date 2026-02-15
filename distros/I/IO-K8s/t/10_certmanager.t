#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use IO::K8s;
use IO::K8s::CertManager;

# --- All cert-manager CRD classes ---

my %classes = (
    # cert-manager.io/v1
    Certificate        => { api_version => 'cert-manager.io/v1',      plural => 'certificates',        namespaced => 1 },
    CertificateRequest => { api_version => 'cert-manager.io/v1',      plural => 'certificaterequests', namespaced => 1 },
    Issuer             => { api_version => 'cert-manager.io/v1',      plural => 'issuers',             namespaced => 1 },
    ClusterIssuer      => { api_version => 'cert-manager.io/v1',      plural => 'clusterissuers',      namespaced => 0 },
    # acme.cert-manager.io/v1
    Order              => { api_version => 'acme.cert-manager.io/v1', plural => 'orders',              namespaced => 1 },
    Challenge          => { api_version => 'acme.cert-manager.io/v1', plural => 'challenges',          namespaced => 1 },
);

# --- Load all 6 classes ---

subtest 'load all cert-manager classes' => sub {
    for my $kind (sort keys %classes) {
        my $class = "IO::K8s::CertManager::V1::$kind";
        use_ok($class) or BAIL_OUT("Cannot load $class");
    }
};

# --- Verify api_version, kind, resource_plural, namespaced ---

subtest 'class metadata' => sub {
    for my $kind (sort keys %classes) {
        my $class = "IO::K8s::CertManager::V1::$kind";
        my $info = $classes{$kind};

        is($class->api_version, $info->{api_version}, "$kind api_version");
        is($class->kind, $kind, "$kind kind");
        is($class->resource_plural, $info->{plural}, "$kind resource_plural");
        if ($info->{namespaced}) {
            ok($class->does('IO::K8s::Role::Namespaced'), "$kind is namespaced");
        } else {
            ok(!$class->does('IO::K8s::Role::Namespaced'), "$kind is cluster-scoped");
        }
    }
};

# --- IO::K8s::CertManager resource_map completeness ---

subtest 'IO::K8s::CertManager resource_map' => sub {
    my $provider = IO::K8s::CertManager->new;
    ok($provider->does('IO::K8s::Role::ResourceMap'), 'consumes ResourceMap role');

    my $map = $provider->resource_map;
    is(scalar keys %$map, 6, 'resource_map has 6 entries');

    for my $kind (sort keys %classes) {
        ok(exists $map->{$kind}, "$kind in resource_map");
        is($map->{$kind}, "CertManager::V1::$kind", "$kind maps to correct class path");
    }
};

# --- new(with => ['IO::K8s::CertManager']) integration ---

subtest 'with constructor parameter' => sub {
    my $k8s = IO::K8s->new(with => ['IO::K8s::CertManager']);

    # All 6 cert-manager kinds should be resolvable by short name
    for my $kind (sort keys %classes) {
        is($k8s->expand_class($kind), "IO::K8s::CertManager::V1::$kind",
            "expand_class('$kind') resolves");
    }

    # Domain-qualified access
    is($k8s->expand_class('cert-manager.io/v1/Certificate'),
        'IO::K8s::CertManager::V1::Certificate',
        'domain-qualified Certificate resolves');
    is($k8s->expand_class('acme.cert-manager.io/v1/Order'),
        'IO::K8s::CertManager::V1::Order',
        'domain-qualified Order resolves');

    # Core resources are unaffected
    is($k8s->expand_class('Pod'), 'IO::K8s::Api::Core::V1::Pod',
        'core Pod still resolves');
    is($k8s->expand_class('Deployment'), 'IO::K8s::Api::Apps::V1::Deployment',
        'core Deployment still resolves');
};

# --- new_object + inflate round-trip ---

subtest 'new_object and inflate round-trip' => sub {
    my $k8s = IO::K8s->new(with => ['IO::K8s::CertManager']);

    # Create a Certificate
    my $cert = $k8s->new_object('Certificate',
        metadata => { name => 'my-cert', namespace => 'default' },
        spec => {
            secretName => 'my-cert-tls',
            issuerRef => { name => 'letsencrypt', kind => 'ClusterIssuer' },
            dnsNames => ['example.com'],
        },
    );
    isa_ok($cert, 'IO::K8s::CertManager::V1::Certificate');
    is($cert->kind, 'Certificate', 'kind');
    is($cert->api_version, 'cert-manager.io/v1', 'api_version');
    isa_ok($cert->metadata, 'IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta');
    is($cert->metadata->name, 'my-cert', 'name');
    is($cert->metadata->namespace, 'default', 'namespace');

    # Serialize and re-inflate
    my $json = $k8s->object_to_json($cert);
    like($json, qr/"apiVersion":"cert-manager\.io\/v1"/, 'JSON has apiVersion');
    like($json, qr/"kind":"Certificate"/, 'JSON has kind');

    my $re = $k8s->inflate($json);
    isa_ok($re, 'IO::K8s::CertManager::V1::Certificate', 're-inflated');
    is($re->metadata->name, 'my-cert', 'round-trip name preserved');
    is($re->metadata->namespace, 'default', 'round-trip namespace preserved');

    # Create a ClusterIssuer (cluster-scoped)
    my $ci = $k8s->new_object('ClusterIssuer',
        metadata => { name => 'letsencrypt' },
        spec => {
            acme => {
                server => 'https://acme-v02.api.letsencrypt.org/directory',
                email => 'admin@example.com',
            },
        },
    );
    isa_ok($ci, 'IO::K8s::CertManager::V1::ClusterIssuer');
    ok(!$ci->does('IO::K8s::Role::Namespaced'), 'ClusterIssuer is cluster-scoped');

    # Round-trip ClusterIssuer
    my $ci_re = $k8s->inflate($k8s->object_to_json($ci));
    isa_ok($ci_re, 'IO::K8s::CertManager::V1::ClusterIssuer');
    is($ci_re->metadata->name, 'letsencrypt', 'ClusterIssuer round-trip');

    # Create an Order (acme.cert-manager.io/v1)
    my $order = $k8s->new_object('Order',
        metadata => { name => 'my-order', namespace => 'default' },
        spec => { request => 'base64-csr-data' },
    );
    isa_ok($order, 'IO::K8s::CertManager::V1::Order');
    is($order->api_version, 'acme.cert-manager.io/v1', 'Order api_version');
    my $order_re = $k8s->inflate($k8s->object_to_json($order));
    isa_ok($order_re, 'IO::K8s::CertManager::V1::Order');
};

# --- to_yaml output ---

subtest 'to_yaml output' => sub {
    my $k8s = IO::K8s->new(with => ['IO::K8s::CertManager']);

    my $cert = $k8s->new_object('Certificate',
        metadata => { name => 'test-cert', namespace => 'default' },
        spec => { secretName => 'test-tls' },
    );
    my $yaml = $cert->to_yaml;
    like($yaml, qr/apiVersion: cert-manager\.io\/v1/, 'YAML apiVersion');
    like($yaml, qr/kind: Certificate/, 'YAML kind');
    like($yaml, qr/name: test-cert/, 'YAML name');
    like($yaml, qr/namespace: default/, 'YAML namespace');
};

# --- Domain-qualified expand_class ---

subtest 'domain-qualified expand_class' => sub {
    my $k8s = IO::K8s->new(with => ['IO::K8s::CertManager']);

    # cert-manager.io/v1 kinds
    for my $kind (qw(Certificate CertificateRequest Issuer ClusterIssuer)) {
        is($k8s->expand_class("cert-manager.io/v1/$kind"),
            "IO::K8s::CertManager::V1::$kind",
            "cert-manager.io/v1/$kind resolves");
    }

    # acme.cert-manager.io/v1 kinds
    for my $kind (qw(Order Challenge)) {
        is($k8s->expand_class("acme.cert-manager.io/v1/$kind"),
            "IO::K8s::CertManager::V1::$kind",
            "acme.cert-manager.io/v1/$kind resolves");
    }

    # api_version parameter style
    is($k8s->expand_class('Certificate', 'cert-manager.io/v1'),
        'IO::K8s::CertManager::V1::Certificate',
        'api_version parameter disambiguation');
};

# --- pk8s DSL with cert-manager kinds ---

subtest 'pk8s DSL with cert-manager kinds' => sub {
    require File::Temp;
    my $k8s = IO::K8s->new(with => ['IO::K8s::CertManager']);

    my ($fh, $filename) = File::Temp::tempfile(SUFFIX => '.pk8s', UNLINK => 1);
    print $fh q{
        ClusterIssuer {
            name => 'letsencrypt',
            spec => { acme => { server => 'https://acme-v02.api.letsencrypt.org/directory' } },
        };

        Certificate {
            name => 'my-cert',
            namespace => 'default',
            spec => { secretName => 'my-cert-tls', issuerRef => { name => 'letsencrypt' } },
        };

        Order {
            name => 'my-order',
            namespace => 'default',
            spec => { request => 'csr-data' },
        };
    };
    close $fh;

    my $objs = $k8s->load($filename);
    is(scalar(@$objs), 3, 'pk8s loaded 3 cert-manager objects');

    my ($ci, $cert, $order) = @$objs;

    isa_ok($ci, 'IO::K8s::CertManager::V1::ClusterIssuer');
    is($ci->kind, 'ClusterIssuer', 'pk8s ClusterIssuer kind');
    is($ci->metadata->name, 'letsencrypt', 'pk8s ClusterIssuer name');

    isa_ok($cert, 'IO::K8s::CertManager::V1::Certificate');
    is($cert->kind, 'Certificate', 'pk8s Certificate kind');

    isa_ok($order, 'IO::K8s::CertManager::V1::Order');
    is($order->kind, 'Order', 'pk8s Order kind');
    is($order->api_version, 'acme.cert-manager.io/v1', 'pk8s Order api_version');
};

done_testing;
