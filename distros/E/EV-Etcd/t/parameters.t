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

# Test 1-2: timeout parameter
{
    my $client = EV::Etcd->new(
        endpoints => ['127.0.0.1:2379'],
        timeout => 5,
    );
    ok($client, 'client created with timeout=5');

    my $works = 0;
    $client->status(sub {
        my ($resp, $err) = @_;
        $works = 1 if !$err;
        EV::break;
    });
    my $t = EV::timer(5, 0, sub { EV::break });
    EV::run;
    ok($works, 'client with custom timeout works');
}

# Test 3-4: timeout minimum value clamping
{
    my $client = EV::Etcd->new(
        endpoints => ['127.0.0.1:2379'],
        timeout => 0,  # Should be clamped to 1
    );
    ok($client, 'client created with timeout=0 (clamped to 1)');

    my $works = 0;
    $client->status(sub {
        my ($resp, $err) = @_;
        $works = 1 if !$err;
        EV::break;
    });
    my $t = EV::timer(5, 0, sub { EV::break });
    EV::run;
    ok($works, 'client with clamped timeout works');
}

# Test 5-6: health_interval parameter (health callback setup)
{
    my $health_called = 0;
    my $client = EV::Etcd->new(
        endpoints => ['127.0.0.1:2379'],
        health_interval => 1,  # Check every 1 second
        on_health_change => sub {
            my ($is_healthy) = @_;
            $health_called++;
        },
    );
    ok($client, 'client created with health_interval');

    # Do something to ensure client is active
    my $done = 0;
    $client->status(sub {
        $done = 1;
        EV::break;
    });
    my $t = EV::timer(5, 0, sub { EV::break });
    EV::run;
    ok($done, 'client with health monitoring works');
    # Note: health callback may or may not have been called depending on timing
}

# Test 7-8: Input size limit validation
{
    my $client = EV::Etcd->new(
        endpoints => ['127.0.0.1:2379'],
    );
    ok($client, 'client created for size limit test');

    # Test that normal size keys work
    my $normal_key = "/test-size-$$/" . ('x' x 100);  # 100 byte key
    my $works = 0;
    $client->put($normal_key, "value", sub {
        my ($resp, $err) = @_;
        $works = 1 if !$err;
        EV::break;
    });
    my $t = EV::timer(5, 0, sub { EV::break });
    EV::run;
    ok($works, 'normal size key accepted');

    # Cleanup
    $client->delete($normal_key, sub { EV::break });
    EV::run;
}

done_testing();
