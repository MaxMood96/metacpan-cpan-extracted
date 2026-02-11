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

plan tests => 20;

my $client = EV::Etcd->new(
    endpoints => ['127.0.0.1:2379'],
);

my $prefix = "/test-txn-$$-" . time();
my $counter_key = "$prefix/counter";

# Setup: put initial counter value
$client->put($counter_key, "0", sub {
    my ($resp, $err) = @_;
    ok(!$err, 'setup: put initial counter succeeded');
    EV::break;
});
my $t1 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 1-3: Simple txn that should succeed (compare matches)
$client->txn(
    compare => [
        { key => $counter_key, target => 'value', value => '0' }
    ],
    success => [
        { request_put => { key => $counter_key, value => '1' } }
    ],
    failure => [],
    sub {
        my ($resp, $err) = @_;
        ok(!$err, 'txn succeeded');
        ok($resp->{header}, 'txn response has header');
        ok($resp->{succeeded}, 'txn compare succeeded (value was 0)');
        diag("Txn succeeded=" . ($resp->{succeeded} ? "true" : "false"));
        EV::break;
    }
);
my $t2 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 4: Verify the counter was incremented
$client->get($counter_key, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'get counter succeeded');
    is($resp->{kvs}[0]{value}, '1', 'counter was incremented to 1');
    EV::break;
});
my $t3 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 5-6: Txn that should fail (compare does not match)
$client->txn(
    compare => [
        { key => $counter_key, target => 'value', value => '0' }  # no longer 0
    ],
    success => [
        { request_put => { key => $counter_key, value => '2' } }
    ],
    failure => [
        { request_put => { key => "$prefix/txn-failed", value => 'true' } }
    ],
    sub {
        my ($resp, $err) = @_;
        ok(!$err, 'txn completed (failure branch)');
        ok(!$resp->{succeeded}, 'txn compare failed (value was not 0)');
        diag("Txn succeeded=" . ($resp->{succeeded} ? "true" : "false"));
        EV::break;
    }
);
my $t4 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 7-8: Verify failure branch was executed
$client->get("$prefix/txn-failed", sub {
    my ($resp, $err) = @_;
    ok(!$err, 'get txn-failed key succeeded');
    is($resp->{kvs}[0]{value}, 'true', 'failure branch was executed');
    EV::break;
});
my $t5 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 9: Counter still has old value (success branch not executed)
$client->get($counter_key, sub {
    my ($resp, $err) = @_;
    is($resp->{kvs}[0]{value}, '1', 'counter still 1 (success branch not executed)');
    EV::break;
});
my $t6 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 10-11: Txn using positional arguments
$client->txn(
    [{ key => $counter_key, target => 'value', value => '1' }],  # compare
    [{ request_put => { key => $counter_key, value => '2' } }],  # success
    [],                                                           # failure
    sub {
        my ($resp, $err) = @_;
        ok(!$err, 'positional txn succeeded');
        ok($resp->{succeeded}, 'positional txn compare succeeded');
        EV::break;
    }
);
my $t7 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 12: Verify positional txn worked
$client->get($counter_key, sub {
    my ($resp, $err) = @_;
    is($resp->{kvs}[0]{value}, '2', 'counter now 2 from positional txn');
    EV::break;
});
my $t8 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 13-14: Txn with version compare
my $current_version;
$client->get($counter_key, sub {
    my ($resp, $err) = @_;
    $current_version = $resp->{kvs}[0]{version};
    diag("Current version: $current_version");
    EV::break;
});
my $t9 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

$client->txn(
    compare => [
        { key => $counter_key, target => 'version', version => $current_version }
    ],
    success => [
        { request_put => { key => $counter_key, value => '3' } }
    ],
    failure => [],
    sub {
        my ($resp, $err) = @_;
        ok(!$err, 'version compare txn succeeded');
        ok($resp->{succeeded}, 'version compare matched');
        EV::break;
    }
);
my $t10 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 15-16: Txn with request_delete_range in success
$client->put("$prefix/to-delete", "deleteme", sub { EV::break });
my $t11 = EV::timer(5, 0, sub { EV::break });
EV::run;

$client->txn(
    compare => [],  # Empty compare always succeeds
    success => [
        { request_delete_range => { key => "$prefix/to-delete" } }
    ],
    failure => [],
    sub {
        my ($resp, $err) = @_;
        ok(!$err, 'delete txn succeeded');
        ok($resp->{succeeded}, 'empty compare always succeeds');
        EV::break;
    }
);
my $t12 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 17: Verify key was deleted
$client->get("$prefix/to-delete", sub {
    my ($resp, $err) = @_;
    is(scalar(@{$resp->{kvs} || []}), 0, 'key was deleted by txn');
    EV::break;
});
my $t13 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Cleanup
$client->delete($prefix, { prefix => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'cleanup delete succeeded');
    diag("Cleaned up $resp->{deleted} keys");
    EV::break;
});
my $t14 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

done_testing();
