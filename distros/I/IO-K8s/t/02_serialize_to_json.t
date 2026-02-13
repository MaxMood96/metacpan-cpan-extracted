#!/usr/bin/env perl

use Test::More;
use IO::K8s;
use IO::K8s::Api::Core::V1::Container;
use IO::K8s::Api::Core::V1::ContainerPort;
use IO::K8s::Api::Core::V1::EnvVar;

my $io = IO::K8s->new;

my $object = IO::K8s::Api::Core::V1::Container->new(
    name => 'container_name',
    env => [
        IO::K8s::Api::Core::V1::EnvVar->new(name => 'STR_ENV', value => 'STRVALUE'),
        IO::K8s::Api::Core::V1::EnvVar->new(name => 'INT_ENV', value => '3306'),
    ],
    ports => [
        IO::K8s::Api::Core::V1::ContainerPort->new(containerPort => 4607, hostPort => 4607),
    ],
    tty => 1,
);

my $json = $io->object_to_json($object);

ok($json eq $object->to_json, 'object_to_json matches to_json');

diag $json;

like($json, qr|"name":"container_name"|, 'has name');
like($json, qr|"value":"3306"|, 'has env value');
like($json, qr|"containerPort":4607|, 'has containerPort');
like($json, qr|"tty":true|, 'has tty as boolean');

done_testing;
