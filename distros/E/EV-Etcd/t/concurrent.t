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

plan tests => 12;

my $client = EV::Etcd->new(
    endpoints => ['127.0.0.1:2379'],
);

my $prefix = "/test-concurrent-$$-" . time();

# Test 1-2: Pipelined puts (fire all, then wait)
{
    my $count = 50;
    my $completed = 0;
    my $errors = 0;

    for my $i (1..$count) {
        $client->put("$prefix/pipe$i", "value$i", sub {
            my ($resp, $err) = @_;
            $errors++ if $err;
            $completed++;
            EV::break if $completed == $count;
        });
    }

    my $timeout = EV::timer(10, 0, sub { EV::break });
    EV::run;

    is($completed, $count, "all $count pipelined puts completed");
    is($errors, 0, 'no errors in pipelined puts');
}

# Test 3-4: Pipelined gets
{
    my $count = 50;
    my $completed = 0;
    my $errors = 0;
    my $values_correct = 0;

    for my $i (1..$count) {
        $client->get("$prefix/pipe$i", sub {
            my ($resp, $err) = @_;
            if ($err) {
                $errors++;
            } elsif ($resp->{kvs} && @{$resp->{kvs}}) {
                $values_correct++ if $resp->{kvs}[0]{value} eq "value$i";
            }
            $completed++;
            EV::break if $completed == $count;
        });
    }

    my $timeout = EV::timer(10, 0, sub { EV::break });
    EV::run;

    is($completed, $count, "all $count pipelined gets completed");
    is($values_correct, $count, 'all values retrieved correctly');
}

# Test 5-7: Interleaved watch + KV operations
{
    my $watch_key = "$prefix/watch_interleave";
    my $events_received = 0;
    my $puts_completed = 0;
    my $watch_error = 0;
    my $target_events = 10;

    # Start watch
    my $watch = $client->watch($watch_key, {}, sub {
        my ($resp, $err) = @_;
        if ($err) {
            $watch_error = 1;
            return;
        }
        if ($resp->{events} && @{$resp->{events}}) {
            $events_received += scalar(@{$resp->{events}});
        }
    });

    # Wait for watch to establish
    my $wait = EV::timer(0.1, 0, sub {
        # Fire puts while watch is active
        for my $i (1..$target_events) {
            $client->put($watch_key, "event$i", sub {
                my ($resp, $err) = @_;
                $puts_completed++;
            });
        }
    });

    # Wait for all events
    my $check;
    $check = EV::timer(0.1, 0.1, sub {
        if ($events_received >= $target_events && $puts_completed >= $target_events) {
            EV::break;
        }
    });

    my $timeout = EV::timer(10, 0, sub { EV::break });
    EV::run;

    ok(!$watch_error, 'watch had no errors during interleaved ops');
    is($puts_completed, $target_events, "all $target_events puts completed during watch");
    cmp_ok($events_received, '>=', $target_events, "received at least $target_events watch events");

    # Cancel watch
    $watch->cancel(sub { EV::break });
    EV::run(EV::RUN_ONCE);
}

# Test 8-9: Mixed put/get/delete operations
{
    my $ops_count = 30;  # 10 puts + 10 gets + 10 deletes
    my $completed = 0;
    my $errors = 0;

    # Fire puts
    for my $i (1..10) {
        $client->put("$prefix/mixed$i", "mixval$i", sub {
            my ($resp, $err) = @_;
            $errors++ if $err;
            $completed++;
            EV::break if $completed == $ops_count;
        });
    }

    # Fire gets (for keys from pipelined test)
    for my $i (1..10) {
        $client->get("$prefix/pipe$i", sub {
            my ($resp, $err) = @_;
            $errors++ if $err;
            $completed++;
            EV::break if $completed == $ops_count;
        });
    }

    # Fire deletes
    for my $i (1..10) {
        $client->delete("$prefix/mixed$i", sub {
            my ($resp, $err) = @_;
            $errors++ if $err;
            $completed++;
            EV::break if $completed == $ops_count;
        });
    }

    my $timeout = EV::timer(10, 0, sub { EV::break });
    EV::run;

    is($completed, $ops_count, "all $ops_count mixed operations completed");
    is($errors, 0, 'no errors in mixed operations');
}

# Test 10-12: Rapid sequential operations (stress test)
{
    my $count = 100;
    my $completed = 0;
    my $errors = 0;

    for my $i (1..$count) {
        $client->put("$prefix/rapid$i", "r$i", sub {
            my ($resp, $err) = @_;
            $errors++ if $err;
            $completed++;
            EV::break;
        });
        EV::run;
    }

    is($completed, $count, "all $count rapid sequential puts completed");
    is($errors, 0, 'no errors in rapid sequential puts');

    # Verify a sample
    my $sample_ok = 0;
    $client->get("$prefix/rapid50", sub {
        my ($resp, $err) = @_;
        $sample_ok = 1 if !$err && $resp->{kvs} && $resp->{kvs}[0]{value} eq 'r50';
        EV::break;
    });
    EV::run;

    ok($sample_ok, 'sample value verified after rapid puts');
}

# Cleanup
$client->delete("$prefix/", { prefix => 1 }, sub { EV::break });
EV::run;

done_testing();
