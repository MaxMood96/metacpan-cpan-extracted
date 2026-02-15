#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

use IO::K8s::Api::Core::V1::Pod;
use IO::K8s::Api::Apps::V1::Deployment;
use IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta;

# --- Labels ---

subtest 'add_label and label' => sub {
    my $pod = IO::K8s::Api::Core::V1::Pod->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-pod',
        ),
    );

    $pod->add_label(app => 'web');
    is($pod->label('app'), 'web', 'label returns value');
    is($pod->label('nonexistent'), undef, 'label returns undef for missing key');
};

subtest 'add_labels' => sub {
    my $pod = IO::K8s::Api::Core::V1::Pod->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-pod',
        ),
    );

    $pod->add_labels(app => 'web', tier => 'frontend', version => 'v1');
    is($pod->label('app'), 'web', 'app label set');
    is($pod->label('tier'), 'frontend', 'tier label set');
    is($pod->label('version'), 'v1', 'version label set');
};

subtest 'has_label' => sub {
    my $pod = IO::K8s::Api::Core::V1::Pod->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-pod',
            labels => { app => 'web' },
        ),
    );

    ok($pod->has_label('app'), 'has_label true for existing');
    ok(!$pod->has_label('missing'), 'has_label false for missing');
};

subtest 'remove_label' => sub {
    my $pod = IO::K8s::Api::Core::V1::Pod->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-pod',
            labels => { app => 'web', tier => 'frontend' },
        ),
    );

    $pod->remove_label('tier');
    ok(!$pod->has_label('tier'), 'label removed');
    ok($pod->has_label('app'), 'other labels preserved');
};

subtest 'match_labels' => sub {
    my $pod = IO::K8s::Api::Core::V1::Pod->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-pod',
            labels => { app => 'web', tier => 'frontend', version => 'v1' },
        ),
    );

    ok($pod->match_labels(app => 'web'), 'single match');
    ok($pod->match_labels(app => 'web', tier => 'frontend'), 'multi match');
    ok(!$pod->match_labels(app => 'api'), 'value mismatch');
    ok(!$pod->match_labels(missing => 'val'), 'key missing');
};

# --- Annotations ---

subtest 'add_annotation and annotation' => sub {
    my $pod = IO::K8s::Api::Core::V1::Pod->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-pod',
        ),
    );

    $pod->add_annotation('prometheus.io/scrape' => 'true');
    is($pod->annotation('prometheus.io/scrape'), 'true', 'annotation value');
    ok($pod->has_annotation('prometheus.io/scrape'), 'has_annotation');
    ok(!$pod->has_annotation('missing'), 'has_annotation false for missing');
};

subtest 'remove_annotation' => sub {
    my $pod = IO::K8s::Api::Core::V1::Pod->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-pod',
            annotations => { 'a' => '1', 'b' => '2' },
        ),
    );

    $pod->remove_annotation('a');
    ok(!$pod->has_annotation('a'), 'annotation removed');
    ok($pod->has_annotation('b'), 'other annotation preserved');
};

# --- Chaining ---

subtest 'method chaining' => sub {
    my $pod = IO::K8s::Api::Core::V1::Pod->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-pod',
        ),
    );

    my $result = $pod->add_label(app => 'web')
                     ->add_label(tier => 'frontend')
                     ->add_annotation('note' => 'test');

    is($result, $pod, 'chaining returns same object');
    is($pod->label('app'), 'web', 'chained label 1');
    is($pod->label('tier'), 'frontend', 'chained label 2');
    is($pod->annotation('note'), 'test', 'chained annotation');
};

# --- Auto-creates metadata ---

subtest 'auto-creates metadata when missing' => sub {
    my $pod = IO::K8s::Api::Core::V1::Pod->new;

    $pod->add_label(app => 'web');
    ok($pod->metadata, 'metadata auto-created');
    is($pod->label('app'), 'web', 'label set on auto-created metadata');
};

# --- Works on no-metadata objects ---

subtest 'safe on objects without metadata yet' => sub {
    my $pod = IO::K8s::Api::Core::V1::Pod->new;

    is($pod->label('app'), undef, 'label returns undef without metadata');
    ok(!$pod->has_label('app'), 'has_label false without metadata');
    is($pod->annotation('key'), undef, 'annotation undef without metadata');
    ok(!$pod->has_annotation('key'), 'has_annotation false without metadata');
    ok(!$pod->match_labels(app => 'web'), 'match_labels false without metadata');
};

done_testing;
