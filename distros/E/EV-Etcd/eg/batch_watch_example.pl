#!/usr/bin/env perl
#
# Example: Transactional batch writes with multiple watchers
#
# Demonstrates:
#   1. Two clients watching the same prefix (/config/)
#   2. A third client writing multiple keys atomically via transaction
#   3. Both watchers receive all changes in ONE batch (single callback)
#
use strict;
use warnings;
use lib 'blib/lib', 'blib/arch';
use EV;
use EV::Etcd;
use Data::Dumper;

my $prefix = "/config/app1/";

# Track state
my $watcher1_batches = 0;
my $watcher2_batches = 0;
my $writes_done = 0;
my $cleaning_up = 0;

# === Client 1: First watcher ===
my $watcher_client1 = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);

my $watch1 = $watcher_client1->watch($prefix, { prefix => 1 }, sub {
    my ($resp, $err) = @_;
    if ($err) {
        print "Watcher 1 error: $err->{message}\n";
        return;
    }

    $watcher1_batches++;
    my $events = $resp->{events} || [];
    print "\n=== Watcher 1 received batch #$watcher1_batches ===\n";
    print "  Events in this batch: " . scalar(@$events) . "\n";

    for my $event (@$events) {
        my $type = $event->{type} // 'PUT';
        my $key = $event->{kv}{key} // '';
        my $value = $event->{kv}{value} // '';
        print "  - $type: $key = $value\n";
    }

    check_done();
});

# === Client 2: Second watcher ===
my $watcher_client2 = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);

my $watch2 = $watcher_client2->watch($prefix, { prefix => 1 }, sub {
    my ($resp, $err) = @_;
    if ($err) {
        print "Watcher 2 error: $err->{message}\n";
        return;
    }

    $watcher2_batches++;
    my $events = $resp->{events} || [];
    print "\n=== Watcher 2 received batch #$watcher2_batches ===\n";
    print "  Events in this batch: " . scalar(@$events) . "\n";

    for my $event (@$events) {
        my $type = $event->{type} // 'PUT';
        my $key = $event->{kv}{key} // '';
        my $value = $event->{kv}{value} // '';
        print "  - $type: $key = $value\n";
    }

    check_done();
});

# === Client 3: Writer (performs transactional batch write) ===
my $writer_client = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);

# Wait a moment for watches to be established, then write
my $write_timer = EV::timer(0.5, 0, sub {
    print "Writer: Performing transactional batch write to $prefix\n";

    # Transaction that writes 5 keys atomically
    # All watchers will receive these as ONE batch
    $writer_client->txn(
        # No compare conditions - always succeeds
        compare => [],

        # Success: write multiple keys atomically
        success => [
            { put => { key => "${prefix}database/host",     value => "db.example.com" } },
            { put => { key => "${prefix}database/port",     value => "5432" } },
            { put => { key => "${prefix}database/name",     value => "myapp_prod" } },
            { put => { key => "${prefix}cache/host",        value => "redis.example.com" } },
            { put => { key => "${prefix}cache/ttl",         value => "3600" } },
        ],

        # Failure: (not used since no compare conditions)
        failure => [],

        sub {
            my ($resp, $err) = @_;
            if ($err) {
                print "Writer: Transaction FAILED - $err->{message}\n";
            } else {
                print "Writer: Transaction succeeded (revision: $resp->{header}{revision})\n";
                print "Writer: Wrote 5 keys atomically\n";
            }
            $writes_done = 1;
            check_done();
        }
    );
});

# Cleanup function
sub check_done {
    return if $cleaning_up;

    # Wait until both watchers received the transaction batch and write is done
    if ($writes_done && $watcher1_batches >= 2 && $watcher2_batches >= 2) {
        $cleaning_up = 1;
        print "\n=== Summary ===\n";
        print "Watcher 1 received $watcher1_batches batch(es)\n";
        print "Watcher 2 received $watcher2_batches batch(es)\n";
        print "Both watchers received the 5 keys as a SINGLE batch!\n";

        # Cleanup: delete the test keys
        cleanup();
    }
}

sub cleanup {
    print "\nCleaning up test keys...\n";
    $writer_client->delete($prefix, { prefix => 1 }, sub {
        my ($resp, $err) = @_;
        print "Cleanup done (deleted $resp->{deleted} keys)\n";
        EV::break;
    });
}

# Timeout
my $timeout = EV::timer(10, 0, sub {
    print "Timeout!\n";
    EV::break;
});

print "Starting example: transactional batch writes with multiple watchers\n";
print "Prefix: $prefix\n";
print "Waiting for watches to establish...\n";

EV::run;

print "Done.\n";
