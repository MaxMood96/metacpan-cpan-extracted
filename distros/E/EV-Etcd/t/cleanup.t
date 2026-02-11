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

plan tests => 8;

my $test_prefix = "/test-cleanup-$$-" . time();

# Test 1-2: Client DESTROY without pending operations
{
    my $client = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);
    ok($client, 'created client for DESTROY test');
}
pass('client DESTROY completed without crash');

# Test 3-4: Client DESTROY with completed operation
{
    my $client = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);
    my $done = 0;
    $client->put("$test_prefix/destroy-test", "value", sub {
        $done = 1;
        EV::break;
    });
    my $t = EV::timer(5, 0, sub { EV::break });
    EV::run;
    ok($done, 'put completed before DESTROY');
}
pass('client DESTROY after operation completed without crash');

# Test 5-6: Watch DESTROY without explicit cancel
{
    my $client = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);
    my $watch_created = 0;

    my $watch = $client->watch("$test_prefix/watch-destroy", sub {
        my ($resp, $err) = @_;
        if ($resp && $resp->{created}) {
            $watch_created = 1;
            EV::break;
        }
    });

    my $t = EV::timer(5, 0, sub { EV::break });
    EV::run;

    ok($watch_created, 'watch created before letting it go out of scope');
    # Let $watch go out of scope without calling cancel()
}
pass('watch DESTROY without explicit cancel completed without crash');

# Test 7-8: Multiple clients created and destroyed
{
    my @clients;
    for my $i (1..5) {
        push @clients, EV::Etcd->new(endpoints => ['127.0.0.1:2379']);
    }
    ok(scalar(@clients) == 5, 'created 5 clients');
    # Let all clients go out of scope at once
}
pass('multiple clients DESTROY completed without crash');

# Cleanup
my $cleanup_client = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);
$cleanup_client->delete("$test_prefix/", { prefix => 1 }, sub {
    diag("Cleanup completed");
});
my $cleanup_timer = EV::timer(2, 0, sub { EV::break });
EV::run;

done_testing();
