#!/usr/bin/env perl
use strict;
use warnings;
use lib 'blib/lib', 'blib/arch';
use Test::More;

# Skip if EV not available
BEGIN {
    eval { require EV };
    plan skip_all => 'EV required' if $@;
}

use EV;
use EV::Etcd;

# Check if etcd is available
my $etcd_available = 0;
eval {
    my $client = EV::Etcd->new(
        endpoints => ['127.0.0.1:2379'],
        timeout => 2,
    );
    $client->status(sub {
        my ($resp, $err) = @_;
        $etcd_available = 1 if !$err;
        EV::break;
    });
    my $t = EV::timer(3, 0, sub { EV::break });
    EV::run;
};

plan skip_all => 'etcd not available on 127.0.0.1:2379' unless $etcd_available;

plan tests => 19;

my $client = EV::Etcd->new(
    endpoints => ['127.0.0.1:2379'],
);

my $lease_id;
my $test_key = "/test-lease-$$-" . time();

# Test 1-4: lease_grant
$client->lease_grant(60, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'lease_grant succeeded');
    ok($resp->{header}, 'response has header');
    ok($resp->{id}, 'response has lease id');
    ok($resp->{ttl}, 'response has ttl');

    $lease_id = $resp->{id};
    diag("Granted lease: id=$lease_id, ttl=$resp->{ttl}");
    EV::break;
});
my $t1 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

SKIP: {
    skip "no lease id", 15 unless $lease_id;

    # Test 5-7: lease_time_to_live (basic)
    $client->lease_time_to_live($lease_id, sub {
        my ($resp, $err) = @_;
        ok(!$err, 'lease_time_to_live succeeded');
        ok($resp->{header}, 'ttl response has header');
        ok($resp->{ttl} > 0, 'ttl is positive');

        diag("Lease TTL: $resp->{ttl} seconds remaining, granted_ttl=$resp->{granted_ttl}");
        EV::break;
    });
    my $t2 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
    EV::run;

    # Test 8: Put a key with this lease
    $client->put($test_key, "lease-test-value", { lease => $lease_id }, sub {
        my ($resp, $err) = @_;
        ok(!$err, 'put with lease succeeded');
        EV::break;
    });
    my $t3 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
    EV::run;

    # Test 9-10: lease_time_to_live with keys option
    $client->lease_time_to_live($lease_id, { keys => 1 }, sub {
        my ($resp, $err) = @_;
        ok(!$err, 'lease_time_to_live with keys succeeded');
        ok(ref($resp->{keys}) eq 'ARRAY', 'response has keys array');

        if ($resp->{keys} && @{$resp->{keys}}) {
            diag("Keys attached to lease: " . join(', ', @{$resp->{keys}}));
        }
        EV::break;
    });
    my $t4 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
    EV::run;

    # Test 11-13: lease_leases (list all leases)
    $client->lease_leases(sub {
        my ($resp, $err) = @_;
        ok(!$err, 'lease_leases succeeded');
        ok($resp->{header}, 'leases response has header');
        ok(ref($resp->{leases}) eq 'ARRAY', 'response has leases array');

        my $found = 0;
        for my $lease (@{$resp->{leases} || []}) {
            if ($lease->{id} == $lease_id) {
                $found = 1;
                last;
            }
        }
        diag("Found " . scalar(@{$resp->{leases} || []}) . " lease(s), our lease " . ($found ? "found" : "not found"));
        EV::break;
    });
    my $t5 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
    EV::run;

    # Test 14-15: lease_keepalive (send one keepalive)
    my $keepalive_received = 0;
    $client->lease_keepalive($lease_id, sub {
        my ($resp, $err) = @_;
        if (!$keepalive_received) {
            $keepalive_received = 1;
            ok(!$err, 'lease_keepalive succeeded');
            ok($resp->{ttl} > 0, 'keepalive response has positive ttl');
            diag("Keepalive response: id=$resp->{id}, ttl=$resp->{ttl}");
            EV::break;
        }
    });
    my $t6 = EV::timer(5, 0, sub {
        fail('keepalive timeout') unless $keepalive_received;
        EV::break;
    });
    EV::run;

    # Test 16-17: lease_revoke
    $client->lease_revoke($lease_id, sub {
        my ($resp, $err) = @_;
        ok(!$err, 'lease_revoke succeeded');
        ok($resp->{header}, 'revoke response has header');
        diag("Lease revoked");
        EV::break;
    });
    my $t7 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
    EV::run;

    # Test 18: Verify key was deleted when lease was revoked
    $client->get($test_key, sub {
        my ($resp, $err) = @_;
        ok(!$err, 'get after revoke succeeded');
        my $count = scalar @{$resp->{kvs} || []};
        is($count, 0, 'key was deleted when lease was revoked');
        EV::break;
    });
    my $t8 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
    EV::run;
}

done_testing();
