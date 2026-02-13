#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use IO::K8s;

my $io = IO::K8s->new;

# Test Container with nested objects
{
    my $obj = $io->struct_to_object(
        'IO::K8s::Api::Core::V1::Container',
        {
            name => 'container_name',
            env => [
                { name => 'STR_ENV', value => 'STRVALUE' },
                { name => 'INT_ENV', value => '3306' },
            ],
            ports => [
                { containerPort => 4607, hostPort => 4607 },
            ],
            command => [ 'c1', 'c2', 'c3' ],
            tty => 1,
        }
    );

    isa_ok($obj, 'IO::K8s::Api::Core::V1::Container');
    is($obj->name, 'container_name', 'name');
    isa_ok($obj->env->[0], 'IO::K8s::Api::Core::V1::EnvVar');
    is($obj->env->[0]->name, 'STR_ENV', 'env name');
    is($obj->env->[0]->value, 'STRVALUE', 'env value');

    isa_ok($obj->ports->[0], 'IO::K8s::Api::Core::V1::ContainerPort');
    is($obj->ports->[0]->containerPort, 4607, 'containerPort');
    ok($obj->tty, 'tty is true');
    is($obj->command->[0], 'c1', 'command');

    my $json = $io->object_to_json($obj);
    like($json, qr|"name":"container_name"|, 'json has name');
    like($json, qr|"tty":true|, 'json has tty as boolean');
}

# Test Service with nested spec
{
    my $obj = $io->struct_to_object(
        'IO::K8s::Api::Core::V1::Service',
        {
            kind => 'Service',
            apiVersion => 'v1',
            metadata => {
                name => 'svc_name',
            },
            spec => {
                selector => {
                    app => "MyApp",
                },
                ports => [
                    { port => 80, protocol => 'TCP', targetPort => 8022 },
                ]
            },
        }
    );

    isa_ok($obj, 'IO::K8s::Api::Core::V1::Service');
    isa_ok($obj->spec, 'IO::K8s::Api::Core::V1::ServiceSpec');
    isa_ok($obj->spec->ports->[0], 'IO::K8s::Api::Core::V1::ServicePort');

    my $json = $io->object_to_json($obj);
    diag $json;

    like($json, qr|"apiVersion":"v1"|, 'json has apiVersion');
}

# Test json_to_object
{
    my $obj = $io->json_to_object(
        'IO::K8s::Api::Core::V1::Service',
        '{"kind":"Service"}'
    );
    isa_ok($obj, 'IO::K8s::Api::Core::V1::Service');
    is($obj->kind, 'Service', 'kind from json');
}

done_testing;
