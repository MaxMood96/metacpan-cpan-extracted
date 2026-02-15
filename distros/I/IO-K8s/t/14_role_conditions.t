#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

use IO::K8s::Cilium::V2::CiliumNetworkPolicy;
use IO::K8s::Traefik::V1alpha1::IngressRoute;
use IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta;

# CRD classes have opaque hashref status ({ Str => 1 }),
# which is the most flexible way to test HasConditions.

subtest 'conditions from opaque hashref status' => sub {
    my $cnp = IO::K8s::Cilium::V2::CiliumNetworkPolicy->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-policy',
        ),
        status => {
            conditions => [
                { type => 'Ready',       status => 'True',  message => 'all good' },
                { type => 'Initialized', status => 'True',  message => 'init done' },
                { type => 'Degraded',    status => 'False', message => 'no issues' },
            ],
        },
    );

    my $conds = $cnp->conditions;
    is(scalar @$conds, 3, 'conditions returns all 3');

    ok($cnp->is_ready, 'is_ready true when Ready=True');
    ok($cnp->is_condition_true('Initialized'), 'Initialized is True');
    ok(!$cnp->is_condition_true('Degraded'), 'Degraded is False');
    ok(!$cnp->is_condition_true('NonExistent'), 'non-existent condition is false');

    my $cond = $cnp->get_condition('Ready');
    is(ref $cond, 'HASH', 'get_condition returns hashref');
    is($cond->{status}, 'True', 'condition status');

    is($cnp->condition_message('Ready'), 'all good', 'condition_message');
    is($cnp->condition_message('Degraded'), 'no issues', 'condition_message for false');
    is($cnp->condition_message('NonExistent'), undef, 'condition_message for missing');
};

subtest 'is_ready checks Available too' => sub {
    my $ir = IO::K8s::Traefik::V1alpha1::IngressRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
        status => {
            conditions => [
                { type => 'Available',  status => 'True', message => 'deployment available' },
                { type => 'Progressing', status => 'True', message => 'progressing' },
            ],
        },
    );

    ok($ir->is_ready, 'is_ready true via Available condition');
};

subtest 'is_ready false when neither Ready nor Available' => sub {
    my $ir = IO::K8s::Traefik::V1alpha1::IngressRoute->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-route',
        ),
        status => {
            conditions => [
                { type => 'Progressing', status => 'True', message => 'still progressing' },
            ],
        },
    );

    ok(!$ir->is_ready, 'is_ready false without Ready or Available');
};

subtest 'no status' => sub {
    my $cnp = IO::K8s::Cilium::V2::CiliumNetworkPolicy->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-policy',
        ),
    );

    my $conds = $cnp->conditions;
    is(scalar @$conds, 0, 'empty conditions when no status');
    ok(!$cnp->is_ready, 'not ready without status');
    is($cnp->get_condition('Ready'), undef, 'get_condition undef without status');
};

subtest 'status without conditions' => sub {
    my $cnp = IO::K8s::Cilium::V2::CiliumNetworkPolicy->new(
        metadata => IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta->new(
            name => 'test-policy',
        ),
        status => { phase => 'Active' },
    );

    my $conds = $cnp->conditions;
    is(scalar @$conds, 0, 'empty conditions when status has no conditions');
    ok(!$cnp->is_ready, 'not ready without conditions in status');
};

done_testing;
