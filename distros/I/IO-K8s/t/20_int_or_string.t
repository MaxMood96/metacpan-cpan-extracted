#!/usr/bin/env perl
# Tests for IntOrStr type support
# Ensures numeric values serialize as JSON integers and strings stay strings

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

use JSON::MaybeXS;

my $json = JSON::MaybeXS->new(utf8 => 0, canonical => 1);

# ---- Core classes with IntOrStr fields ----

use_ok('IO::K8s::Api::Core::V1::HTTPGetAction');
use_ok('IO::K8s::Api::Core::V1::TCPSocketAction');
use_ok('IO::K8s::Api::Core::V1::ServicePort');
use_ok('IO::K8s::Api::Networking::V1::NetworkPolicyPort');
use_ok('IO::K8s::Api::Apps::V1::RollingUpdateDeployment');
use_ok('IO::K8s::Api::Apps::V1::RollingUpdateDaemonSet');
use_ok('IO::K8s::Api::Apps::V1::RollingUpdateStatefulSetStrategy');
use_ok('IO::K8s::Api::Policy::V1::PodDisruptionBudgetSpec');

# ---- HTTPGetAction: numeric port -> JSON integer ----

subtest 'HTTPGetAction numeric port' => sub {
    my $action = IO::K8s::Api::Core::V1::HTTPGetAction->new(
        port => '8080',
        path => '/healthz',
    );
    my $data = $action->TO_JSON;
    is($data->{port}, 8080, 'numeric port value is 8080');
    ok(!ref($data->{port}), 'port is a scalar');

    my $encoded = $json->encode($data);
    like($encoded, qr/"port":8080\b/, 'JSON encodes port as integer');
    unlike($encoded, qr/"port":"8080"/, 'JSON does NOT encode port as string');
};

# ---- HTTPGetAction: named port -> JSON string ----

subtest 'HTTPGetAction named port' => sub {
    my $action = IO::K8s::Api::Core::V1::HTTPGetAction->new(
        port => 'http',
        path => '/healthz',
    );
    my $data = $action->TO_JSON;
    is($data->{port}, 'http', 'named port stays string');

    my $encoded = $json->encode($data);
    like($encoded, qr/"port":"http"/, 'JSON encodes named port as string');
};

# ---- TCPSocketAction: numeric port ----

subtest 'TCPSocketAction numeric port' => sub {
    my $action = IO::K8s::Api::Core::V1::TCPSocketAction->new(
        port => '3306',
    );
    my $data = $action->TO_JSON;
    is($data->{port}, 3306, 'numeric port is integer');

    my $encoded = $json->encode($data);
    like($encoded, qr/"port":3306\b/, 'JSON integer');
};

# ---- ServicePort: targetPort ----

subtest 'ServicePort targetPort' => sub {
    my $sp = IO::K8s::Api::Core::V1::ServicePort->new(
        port       => 80,
        targetPort => '4000',
    );
    my $data = $sp->TO_JSON;
    is($data->{targetPort}, 4000, 'numeric targetPort is integer');
    is($data->{port}, 80, 'port stays integer (Int type)');

    my $encoded = $json->encode($data);
    like($encoded, qr/"targetPort":4000\b/, 'targetPort JSON integer');

    # Named targetPort
    my $sp2 = IO::K8s::Api::Core::V1::ServicePort->new(
        port       => 80,
        targetPort => 'http-web',
    );
    my $data2 = $sp2->TO_JSON;
    is($data2->{targetPort}, 'http-web', 'named targetPort stays string');
};

# ---- RollingUpdateDeployment: percentage stays string ----

subtest 'RollingUpdateDeployment percentage values' => sub {
    my $ru = IO::K8s::Api::Apps::V1::RollingUpdateDeployment->new(
        maxSurge       => '25%',
        maxUnavailable => '25%',
    );
    my $data = $ru->TO_JSON;
    is($data->{maxSurge}, '25%', 'percentage maxSurge stays string');
    is($data->{maxUnavailable}, '25%', 'percentage maxUnavailable stays string');

    my $encoded = $json->encode($data);
    like($encoded, qr/"maxSurge":"25%"/, 'percentage as JSON string');
};

# ---- RollingUpdateDeployment: absolute numbers become integers ----

subtest 'RollingUpdateDeployment absolute numbers' => sub {
    my $ru = IO::K8s::Api::Apps::V1::RollingUpdateDeployment->new(
        maxSurge       => '5',
        maxUnavailable => '2',
    );
    my $data = $ru->TO_JSON;
    is($data->{maxSurge}, 5, 'absolute maxSurge is integer');
    is($data->{maxUnavailable}, 2, 'absolute maxUnavailable is integer');

    my $encoded = $json->encode($data);
    like($encoded, qr/"maxSurge":5\b/, 'absolute as JSON integer');
};

# ---- RollingUpdateDaemonSet ----

subtest 'RollingUpdateDaemonSet' => sub {
    my $ru = IO::K8s::Api::Apps::V1::RollingUpdateDaemonSet->new(
        maxSurge       => '1',
        maxUnavailable => '10%',
    );
    my $encoded = $json->encode($ru->TO_JSON);
    like($encoded, qr/"maxSurge":1\b/, 'DaemonSet maxSurge JSON integer');
    unlike($encoded, qr/"maxSurge":"1"/, 'DaemonSet maxSurge NOT JSON string');
    like($encoded, qr/"maxUnavailable":"10%"/, 'DaemonSet maxUnavailable JSON string');
};

# ---- RollingUpdateStatefulSetStrategy ----

subtest 'RollingUpdateStatefulSetStrategy' => sub {
    my $ru = IO::K8s::Api::Apps::V1::RollingUpdateStatefulSetStrategy->new(
        maxUnavailable => '3',
    );
    my $encoded = $json->encode($ru->TO_JSON);
    like($encoded, qr/"maxUnavailable":3\b/, 'StatefulSet maxUnavailable JSON integer');
    unlike($encoded, qr/"maxUnavailable":"3"/, 'StatefulSet maxUnavailable NOT JSON string');
};

# ---- PodDisruptionBudgetSpec ----

subtest 'PodDisruptionBudgetSpec' => sub {
    my $pdb = IO::K8s::Api::Policy::V1::PodDisruptionBudgetSpec->new(
        maxUnavailable => '1',
        minAvailable   => '100%',
    );
    my $encoded = $json->encode($pdb->TO_JSON);
    like($encoded, qr/"maxUnavailable":1\b/, 'PDB maxUnavailable JSON integer');
    unlike($encoded, qr/"maxUnavailable":"1"/, 'PDB maxUnavailable NOT JSON string');
    like($encoded, qr/"minAvailable":"100%"/, 'PDB minAvailable JSON string');
};

# ---- NetworkPolicyPort ----

subtest 'NetworkPolicyPort' => sub {
    my $npp = IO::K8s::Api::Networking::V1::NetworkPolicyPort->new(
        port     => '443',
        protocol => 'TCP',
    );
    my $encoded = $json->encode($npp->TO_JSON);
    like($encoded, qr/"port":443\b/, 'NetworkPolicyPort numeric port JSON integer');
    unlike($encoded, qr/"port":"443"/, 'NetworkPolicyPort numeric port NOT JSON string');

    my $npp2 = IO::K8s::Api::Networking::V1::NetworkPolicyPort->new(
        port     => 'https',
        protocol => 'TCP',
    );
    my $encoded2 = $json->encode($npp2->TO_JSON);
    like($encoded2, qr/"port":"https"/, 'NetworkPolicyPort named port JSON string');
};

# ---- Edge cases ----

subtest 'edge cases' => sub {
    # Zero
    my $action = IO::K8s::Api::Core::V1::TCPSocketAction->new(port => '0');
    my $data = $action->TO_JSON;
    is($data->{port}, 0, 'zero port is integer');
    ok(defined $data->{port}, 'zero port is defined');
    my $encoded = $json->encode($data);
    like($encoded, qr/"port":0\b/, 'zero as JSON integer');

    # Negative number
    my $ru = IO::K8s::Api::Apps::V1::RollingUpdateDeployment->new(
        maxSurge => '-1',
    );
    my $encoded2 = $json->encode($ru->TO_JSON);
    like($encoded2, qr/"maxSurge":-1\b/, 'negative number as JSON integer');
    unlike($encoded2, qr/"maxSurge":"-1"/, 'negative number NOT JSON string');
};

# ---- Roundtrip: JSON encode -> decode -> re-encode ----

subtest 'JSON roundtrip' => sub {
    my $sp = IO::K8s::Api::Core::V1::ServicePort->new(
        port       => 80,
        targetPort => '8080',
        name       => 'http',
        protocol   => 'TCP',
    );

    my $json_str = $sp->to_json;
    my $decoded = decode_json($json_str);
    is($decoded->{targetPort}, 8080, 'roundtrip: targetPort is integer');
    is($decoded->{port}, 80, 'roundtrip: port is integer');
    is($decoded->{name}, 'http', 'roundtrip: name is string');
};

# ---- attr_info flag check ----

subtest 'attr registry has is_int_or_string flag' => sub {
    my $info = IO::K8s::Api::Core::V1::HTTPGetAction->_k8s_attr_info;
    ok($info->{port}{is_int_or_string}, 'HTTPGetAction port has is_int_or_string flag');
    ok(!$info->{port}{is_str}, 'HTTPGetAction port does NOT have is_str flag');
    ok(!$info->{port}{is_int}, 'HTTPGetAction port does NOT have is_int flag');

    ok($info->{host}{is_str}, 'HTTPGetAction host still has is_str flag');
};

done_testing;
