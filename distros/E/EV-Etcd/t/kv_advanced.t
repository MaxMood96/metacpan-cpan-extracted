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

plan tests => 30;

my $client = EV::Etcd->new(
    endpoints => ['127.0.0.1:2379'],
);

my $prefix = "/test-kv-adv-$$-" . time();

# Setup: Create keys with different values for sorting tests
my @keys = (
    { key => "$prefix/alpha", value => "zebra" },
    { key => "$prefix/beta",  value => "apple" },
    { key => "$prefix/gamma", value => "mango" },
    { key => "$prefix/delta", value => "banana" },
);

my $setup_done = 0;
my @revisions;
for my $item (@keys) {
    $client->put($item->{key}, $item->{value}, sub {
        my ($resp, $err) = @_;
        push @revisions, $resp->{header}{revision} if $resp && $resp->{header};
        $setup_done++;
        EV::break if $setup_done == scalar(@keys);
    });
}
my $t = EV::timer(5, 0, sub { EV::break });
EV::run;

is($setup_done, 4, 'setup: all 4 keys created');
diag("Created keys with revisions: " . join(", ", @revisions));

# Test 1-2: sort_order ascend (by key - default sort_target)
$client->get("$prefix/", { prefix => 1, sort_order => 'ascend' }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'sort_order ascend succeeded');
    my @got_keys = map { $_->{key} } @{$resp->{kvs} || []};
    my @expected = sort @got_keys;
    is_deeply(\@got_keys, \@expected, 'keys returned in ascending order');
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 3-4: sort_order descend (by key)
$client->get("$prefix/", { prefix => 1, sort_order => 'descend' }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'sort_order descend succeeded');
    my @got_keys = map { $_->{key} } @{$resp->{kvs} || []};
    my @expected = reverse sort @got_keys;
    is_deeply(\@got_keys, \@expected, 'keys returned in descending order');
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 5-6: sort_target value with ascend
$client->get("$prefix/", { prefix => 1, sort_order => 'ascend', sort_target => 'value' }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'sort by value ascend succeeded');
    my @got_values = map { $_->{value} } @{$resp->{kvs} || []};
    my @expected = sort @got_values;
    is_deeply(\@got_values, \@expected, 'values returned in ascending order');
    diag("Values sorted: " . join(", ", @got_values));
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 7-8: sort_target mod with descend (newest first)
$client->get("$prefix/", { prefix => 1, sort_order => 'descend', sort_target => 'mod' }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'sort by mod descend succeeded');
    my @mod_revs = map { $_->{mod_revision} } @{$resp->{kvs} || []};
    my $is_descending = 1;
    for my $i (0..$#mod_revs-1) {
        $is_descending = 0 if $mod_revs[$i] < $mod_revs[$i+1];
    }
    ok($is_descending, 'mod_revisions in descending order');
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 9-10: keys_only option
$client->get("$prefix/", { prefix => 1, keys_only => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'keys_only get succeeded');
    my $all_empty = 1;
    for my $kv (@{$resp->{kvs} || []}) {
        $all_empty = 0 if defined $kv->{value} && length($kv->{value}) > 0;
    }
    ok($all_empty, 'all values are empty with keys_only');
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 11-12: serializable read
$client->get("$prefix/alpha", { serializable => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'serializable get succeeded');
    is($resp->{kvs}[0]{value}, 'zebra', 'serializable read returns correct value');
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 13-14: min_mod_revision filter
my $mid_rev = $revisions[1];  # Second key's revision
$client->get("$prefix/", { prefix => 1, min_mod_revision => $mid_rev }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'min_mod_revision filter succeeded');
    my $all_above = 1;
    for my $kv (@{$resp->{kvs} || []}) {
        $all_above = 0 if $kv->{mod_revision} < $mid_rev;
    }
    ok($all_above, "all returned keys have mod_revision >= $mid_rev");
    diag("min_mod_revision=$mid_rev returned " . scalar(@{$resp->{kvs} || []}) . " keys");
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 15-16: max_mod_revision filter
$client->get("$prefix/", { prefix => 1, max_mod_revision => $mid_rev }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'max_mod_revision filter succeeded');
    my $all_below = 1;
    for my $kv (@{$resp->{kvs} || []}) {
        $all_below = 0 if $kv->{mod_revision} > $mid_rev;
    }
    ok($all_below, "all returned keys have mod_revision <= $mid_rev");
    diag("max_mod_revision=$mid_rev returned " . scalar(@{$resp->{kvs} || []}) . " keys");
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 17-18: revision (historical read)
# First update a key
my $old_revision;
$client->get("$prefix/alpha", sub {
    my ($resp, $err) = @_;
    $old_revision = $resp->{header}{revision};
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

$client->put("$prefix/alpha", "new_zebra", sub { EV::break });
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Read at old revision
$client->get("$prefix/alpha", { revision => $old_revision }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'historical revision get succeeded');
    is($resp->{kvs}[0]{value}, 'zebra', 'historical read returns old value');
    diag("Read at revision $old_revision got 'zebra' (current is 'new_zebra')");
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 19-20: Put with ignore_value (keeps existing value, updates lease/revision)
$client->put("$prefix/alpha", "", { ignore_value => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'put with ignore_value succeeded');
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

$client->get("$prefix/alpha", sub {
    my ($resp, $err) = @_;
    is($resp->{kvs}[0]{value}, 'new_zebra', 'value unchanged after ignore_value put');
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 21-22: Combined options
$client->get("$prefix/", {
    prefix => 1,
    sort_order => 'descend',
    sort_target => 'value',
    limit => 2
}, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'combined options get succeeded');
    is(scalar(@{$resp->{kvs} || []}), 2, 'limit respected with combined options');
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test 23-26: range_end parameter (custom key range, not prefix)
# Create some sequential keys for range testing
my $range_prefix = "$prefix/range";
for my $letter ('a'..'e') {
    $client->put("$range_prefix/$letter", "value-$letter", sub { });
}
# Wait for all puts
my $range_setup = EV::timer 2, 0, sub { EV::break };
EV::run;

# Test get with range_end: get keys from /range/b to /range/d (exclusive)
$client->get("$range_prefix/b", { range_end => "$range_prefix/d" }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'get with range_end succeeded');
    my @keys = map { $_->{key} } @{$resp->{kvs} || []};
    is(scalar(@keys), 2, 'range_end returns correct number of keys (b, c)');
    my $has_b = grep { $_ =~ /\/b$/ } @keys;
    my $has_c = grep { $_ =~ /\/c$/ } @keys;
    ok($has_b && $has_c, 'range_end returns keys b and c');
    diag("range_end query returned: " . join(", ", @keys));
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Test delete with range_end: delete keys from /range/b to /range/d (exclusive)
$client->delete("$range_prefix/b", { range_end => "$range_prefix/d" }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'delete with range_end succeeded');
    is($resp->{deleted}, 2, 'range_end delete removed 2 keys (b, c)');
    diag("range_end delete removed $resp->{deleted} keys");
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Verify remaining keys after range delete
$client->get("$range_prefix/", { prefix => 1 }, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'get after range delete succeeded');
    my @remaining = map { $_->{key} } @{$resp->{kvs} || []};
    is(scalar(@remaining), 3, 'range delete left 3 keys (a, d, e)');
    diag("Remaining after range delete: " . join(", ", @remaining));
    EV::break;
});
$t = EV::timer(5, 0, sub { EV::break });
EV::run;

# Cleanup
$client->delete("$prefix/", { prefix => 1 }, sub { EV::break });
EV::run;

done_testing();
