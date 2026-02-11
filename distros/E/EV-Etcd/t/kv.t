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

plan tests => 31;

my $client = EV::Etcd->new(
    endpoints => ['127.0.0.1:2379'],
);

my $prefix = "/test-kv-$$-" . time();

# Test 1-3: Basic put
$client->put("$prefix/key1", "value1", sub {
    my ($resp, $err) = @_;
    ok(!$err, 'put succeeded');
    ok($resp->{header}, 'put response has header');
    ok($resp->{header}{revision}, 'header has revision');
    diag("Put key1, revision=$resp->{header}{revision}");
    EV::break;
});
my $t1 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 4-9: Basic get
$client->get("$prefix/key1", sub {
    my ($resp, $err) = @_;
    ok(!$err, 'get succeeded');
    ok($resp->{header}, 'get response has header');
    ok(ref($resp->{kvs}) eq 'ARRAY', 'response has kvs array');
    is(scalar(@{$resp->{kvs}}), 1, 'got one key');

    if (@{$resp->{kvs}}) {
        my $kv = $resp->{kvs}[0];
        is($kv->{key}, "$prefix/key1", 'key matches');
        is($kv->{value}, "value1", 'value matches');
        diag("Got key=$kv->{key}, value=$kv->{value}, mod_revision=$kv->{mod_revision}");
    }
    EV::break;
});
my $t2 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 10-11: Get non-existent key
$client->get("$prefix/nonexistent", sub {
    my ($resp, $err) = @_;
    ok(!$err, 'get non-existent key succeeded (no error)');
    is(scalar(@{$resp->{kvs} || []}), 0, 'no kvs returned for non-existent key');
    EV::break;
});
my $t3 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 12-14: Put with prev_kv option
$client->put("$prefix/key1", "value1-updated", { prev_kv => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'put with prev_kv succeeded');
    ok($resp->{prev_kv}, 'response has prev_kv');
    if ($resp->{prev_kv}) {
        is($resp->{prev_kv}{value}, "value1", 'prev_kv has old value');
        diag("Updated key1, prev_value=$resp->{prev_kv}{value}");
    }
    EV::break;
});
my $t4 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Setup multiple keys for prefix/range tests
my $setup_done = 0;
for my $i (2..5) {
    $client->put("$prefix/key$i", "value$i", sub {
        $setup_done++;
        EV::break if $setup_done == 4;
    });
}
my $t5 = EV::timer(5, 0, sub { fail('setup timeout'); EV::break });
EV::run;

# Test 15-17: Prefix query
$client->get("$prefix/", { prefix => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'prefix get succeeded');
    ok(ref($resp->{kvs}) eq 'ARRAY', 'prefix response has kvs array');
    cmp_ok(scalar(@{$resp->{kvs}}), '>=', 5, 'got at least 5 keys with prefix');
    diag("Prefix query returned " . scalar(@{$resp->{kvs}}) . " keys");
    EV::break;
});
my $t6 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 18-19: Range with limit
$client->get("$prefix/", { prefix => 1, limit => 2 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'limited prefix get succeeded');
    is(scalar(@{$resp->{kvs}}), 2, 'got exactly 2 keys with limit');
    EV::break;
});
my $t7 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 20-21: count_only option
$client->get("$prefix/", { prefix => 1, count_only => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'count_only get succeeded');
    cmp_ok($resp->{count}, '>=', 5, 'count shows at least 5 keys');
    diag("count_only returned count=$resp->{count}");
    EV::break;
});
my $t8 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 22-24: Delete single key
$client->delete("$prefix/key5", sub {
    my ($resp, $err) = @_;
    ok(!$err, 'delete succeeded');
    ok($resp->{header}, 'delete response has header');
    is($resp->{deleted}, 1, 'deleted count is 1');
    diag("Deleted key5, deleted=$resp->{deleted}");
    EV::break;
});
my $t9 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 25-27: Delete with prev_kv
$client->delete("$prefix/key4", { prev_kv => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'delete with prev_kv succeeded');
    ok($resp->{prev_kvs} && @{$resp->{prev_kvs}}, 'response has prev_kvs');
    if ($resp->{prev_kvs} && @{$resp->{prev_kvs}}) {
        is($resp->{prev_kvs}[0]{value}, "value4", 'prev_kv has old value');
    }
    EV::break;
});
my $t10 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 28-29: Delete with prefix
$client->delete("$prefix/", { prefix => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'prefix delete succeeded');
    cmp_ok($resp->{deleted}, '>=', 3, 'deleted at least 3 remaining keys');
    diag("Prefix delete removed $resp->{deleted} keys");
    EV::break;
});
my $t11 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 30-31: Verify all keys deleted
$client->get("$prefix/", { prefix => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'verify get succeeded');
    is(scalar(@{$resp->{kvs} || []}), 0, 'all keys deleted');
    EV::break;
});
my $t12 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

done_testing();
