#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

use IO::K8s::CertManager::V1::Certificate;
use IO::K8s::CertManager::V1::Issuer;
use IO::K8s::CertManager::V1::ClusterIssuer;
use IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta;

# --- Certificate ---

subtest 'certificate: for_domains' => sub {
    my $cert = IO::K8s::CertManager::V1::Certificate->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-cert', namespace => 'default',
        ),
    );

    $cert->for_domains('example.com', '*.example.com');
    is_deeply($cert->spec->{dnsNames}, ['example.com', '*.example.com'], 'dnsNames set');
};

subtest 'certificate: with_issuer' => sub {
    my $cert = IO::K8s::CertManager::V1::Certificate->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-cert', namespace => 'default',
        ),
    );

    $cert->with_issuer('letsencrypt-prod', kind => 'ClusterIssuer');
    is($cert->spec->{issuerRef}{name}, 'letsencrypt-prod', 'issuer name');
    is($cert->spec->{issuerRef}{kind}, 'ClusterIssuer', 'issuer kind');
    is($cert->spec->{issuerRef}{group}, 'cert-manager.io', 'default group');
};

subtest 'certificate: store_in_secret' => sub {
    my $cert = IO::K8s::CertManager::V1::Certificate->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-cert', namespace => 'default',
        ),
    );

    $cert->store_in_secret('example-tls');
    is($cert->spec->{secretName}, 'example-tls', 'secretName set');
};

subtest 'certificate: add_ip_san' => sub {
    my $cert = IO::K8s::CertManager::V1::Certificate->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-cert', namespace => 'default',
        ),
    );

    $cert->add_ip_san('10.0.0.1', '192.168.1.1');
    is_deeply($cert->spec->{ipAddresses}, ['10.0.0.1', '192.168.1.1'], 'IP SANs set');

    dies_ok { $cert->add_ip_san('not-an-ip') } 'rejects invalid IP';
};

subtest 'certificate: renew_before' => sub {
    my $cert = IO::K8s::CertManager::V1::Certificate->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-cert', namespace => 'default',
        ),
    );

    $cert->renew_before(days => 30);
    is($cert->spec->{renewBefore}, '720h0m0s', 'renew_before in hours');
};

subtest 'certificate: chaining' => sub {
    my $cert = IO::K8s::CertManager::V1::Certificate->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-cert', namespace => 'default',
        ),
    );

    my $result = $cert->for_domains('example.com')
                      ->with_issuer('letsencrypt-prod', kind => 'ClusterIssuer')
                      ->store_in_secret('example-tls')
                      ->renew_before(days => 30);

    is($result, $cert, 'chaining returns self');
    ok($cert->spec->{dnsNames}, 'domains set via chain');
    ok($cert->spec->{issuerRef}, 'issuer set via chain');
    ok($cert->spec->{secretName}, 'secret set via chain');
    ok($cert->spec->{renewBefore}, 'renewBefore set via chain');
};

# --- Issuer ---

subtest 'issuer: letsencrypt' => sub {
    my $issuer = IO::K8s::CertManager::V1::Issuer->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'letsencrypt', namespace => 'default',
        ),
    );

    $issuer->letsencrypt(email => 'admin@example.com', production => 1);
    like($issuer->spec->{acme}{server}, qr/acme-v02\.api\.letsencrypt\.org/, 'production ACME server');
    is($issuer->spec->{acme}{email}, 'admin@example.com', 'email');
};

subtest 'issuer: letsencrypt staging' => sub {
    my $issuer = IO::K8s::CertManager::V1::Issuer->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'letsencrypt-staging', namespace => 'default',
        ),
    );

    $issuer->letsencrypt(email => 'admin@example.com', production => 0);
    like($issuer->spec->{acme}{server}, qr/acme-staging-v02/, 'staging ACME server');
};

subtest 'issuer: self_signed' => sub {
    my $issuer = IO::K8s::CertManager::V1::Issuer->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'selfsigned', namespace => 'default',
        ),
    );

    $issuer->self_signed;
    ok(exists $issuer->spec->{selfSigned}, 'selfSigned set');
};

subtest 'issuer: ca' => sub {
    my $issuer = IO::K8s::CertManager::V1::Issuer->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'ca-issuer', namespace => 'default',
        ),
    );

    $issuer->ca(secret => 'ca-keypair');
    is($issuer->spec->{ca}{secretName}, 'ca-keypair', 'CA secret');

    dies_ok { IO::K8s::CertManager::V1::Issuer->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(name => 'x'),
    )->ca } 'ca requires secret';
};

subtest 'issuer: add_http01_solver' => sub {
    my $issuer = IO::K8s::CertManager::V1::Issuer->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'letsencrypt', namespace => 'default',
        ),
    );

    $issuer->letsencrypt(email => 'admin@example.com')
           ->add_http01_solver(class => 'nginx');

    my $solvers = $issuer->spec->{acme}{solvers};
    is(scalar @$solvers, 1, 'one solver');
    is($solvers->[0]{http01}{ingress}{class}, 'nginx', 'ingress class');
};

subtest 'issuer: add_dns01_solver' => sub {
    my $issuer = IO::K8s::CertManager::V1::Issuer->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'letsencrypt', namespace => 'default',
        ),
    );

    $issuer->letsencrypt(email => 'admin@example.com')
           ->add_dns01_solver(provider => 'cloudflare', secret => 'cf-token');

    my $solvers = $issuer->spec->{acme}{solvers};
    is(scalar @$solvers, 1, 'one solver');
    ok($solvers->[0]{dns01}{cloudflare}, 'cloudflare dns01');
    is($solvers->[0]{dns01}{cloudflare}{apiTokenSecretRef}{name}, 'cf-token', 'secret ref');
};

# --- ClusterIssuer ---

subtest 'cluster issuer: letsencrypt' => sub {
    my $ci = IO::K8s::CertManager::V1::ClusterIssuer->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'letsencrypt-prod',
        ),
    );

    $ci->letsencrypt(email => 'admin@example.com', production => 1)
       ->add_http01_solver;

    ok($ci->spec->{acme}, 'acme config');
    ok($ci->spec->{acme}{solvers}, 'solvers');
};

done_testing;
