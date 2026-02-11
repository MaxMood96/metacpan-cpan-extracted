#!/usr/bin/env perl
#
# Example: Load branch data then watch for changes
#
# Common pattern for distributed configuration:
#   1. Load all existing keys from a prefix (branch)
#   2. Start watching from that revision for future changes
#   3. Receive incremental updates as they happen
#
# This ensures no updates are missed between load and watch.
#
use strict;
use warnings;
use lib 'blib/lib', 'blib/arch';
use EV;
use EV::Etcd;

my $prefix = "/myapp/config/";

# === Setup: Create some initial data ===
print "=== Setup: Creating initial data ===\n";

my $setup_client = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);
my $setup_done = 0;

# Use transaction to create initial config atomically
$setup_client->txn(
    compare => [],
    success => [
        { put => { key => "${prefix}db/host",     value => "localhost" } },
        { put => { key => "${prefix}db/port",     value => "5432" } },
        { put => { key => "${prefix}db/name",     value => "myapp" } },
        { put => { key => "${prefix}cache/host",  value => "localhost" } },
        { put => { key => "${prefix}cache/port",  value => "6379" } },
    ],
    failure => [],
    sub {
        my ($resp, $err) = @_;
        die "Setup failed: $err->{message}" if $err;
        print "Initial data created at revision $resp->{header}{revision}\n\n";
        $setup_done = 1;
        EV::break;
    }
);
my $t_setup = EV::timer(5, 0, sub { die "Setup timeout" });
EV::run;

# === Client 1: Subscriber that loads then watches ===
print "=== Client 1: Loading existing data and watching ===\n";

my $subscriber = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);
my %local_cache;       # Local copy of the config branch
my $watch_revision;    # Revision to start watching from
my $watch_handle;
my $load_done = 0;

# Step 1: Load all existing data from the branch
$subscriber->get($prefix, { prefix => 1 }, sub {
    my ($resp, $err) = @_;
    die "Load failed: $err->{message}" if $err;

    print "Loaded " . scalar(@{$resp->{kvs} || []}) . " keys:\n";

    for my $kv (@{$resp->{kvs} || []}) {
        my $key = $kv->{key};
        my $value = $kv->{value};
        $local_cache{$key} = $value;
        print "  $key = $value\n";
    }

    # IMPORTANT: Start watching from the revision AFTER our get
    # This ensures we don't miss any updates that happened during/after our get
    $watch_revision = $resp->{header}{revision} + 1;
    print "\nWill watch from revision: $watch_revision\n";

    # Step 2: Start watching for changes from that revision
    $watch_handle = $subscriber->watch($prefix, {
        prefix        => 1,
        start_revision => $watch_revision,
    }, sub {
        my ($resp, $err) = @_;
        if ($err) {
            print "Watch error: $err->{message}\n";
            return;
        }

        my $events = $resp->{events} || [];
        return unless @$events;  # Skip empty responses

        print "\n--- Received " . scalar(@$events) . " update(s) ---\n";

        for my $event (@$events) {
            my $type = $event->{type} // 'PUT';
            my $key = $event->{kv}{key};
            my $value = $event->{kv}{value} // '';
            my $mod_rev = $event->{kv}{mod_revision};

            if ($type eq 'DELETE') {
                delete $local_cache{$key};
                print "  DELETE: $key (rev $mod_rev)\n";
            } else {
                $local_cache{$key} = $value;
                print "  PUT: $key = $value (rev $mod_rev)\n";
            }
        }

        print "Local cache now has " . scalar(keys %local_cache) . " keys\n";
    });

    $load_done = 1;
    print "\nNow watching for changes...\n";
    EV::break;
});

my $t_load = EV::timer(5, 0, sub { die "Load timeout" });
EV::run;

# === Client 2: Publisher that makes changes ===
print "\n=== Client 2: Making changes ===\n";

my $publisher = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);
my $changes_done = 0;

# Schedule a series of changes
my @changes = (
    sub {
        print "\nPublisher: Updating db/host...\n";
        $publisher->put("${prefix}db/host", "db.production.local", sub {
            my ($resp, $err) = @_;
            print "  Updated (rev $resp->{header}{revision})\n" unless $err;
            EV::break;
        });
    },
    sub {
        print "\nPublisher: Adding new key logging/level...\n";
        $publisher->put("${prefix}logging/level", "info", sub {
            my ($resp, $err) = @_;
            print "  Added (rev $resp->{header}{revision})\n" unless $err;
            EV::break;
        });
    },
    sub {
        print "\nPublisher: Batch update via transaction...\n";
        $publisher->txn(
            compare => [],
            success => [
                { put => { key => "${prefix}db/pool_size",    value => "10" } },
                { put => { key => "${prefix}db/timeout",      value => "30" } },
                { put => { key => "${prefix}cache/ttl",       value => "3600" } },
            ],
            failure => [],
            sub {
                my ($resp, $err) = @_;
                print "  Batch updated (rev $resp->{header}{revision})\n" unless $err;
                EV::break;
            }
        );
    },
    sub {
        print "\nPublisher: Deleting cache/port...\n";
        $publisher->delete("${prefix}cache/port", sub {
            my ($resp, $err) = @_;
            print "  Deleted (rev $resp->{header}{revision})\n" unless $err;
            $changes_done = 1;
            EV::break;
        });
    },
);

# Execute changes sequentially with delays
for my $i (0..$#changes) {
    $changes[$i]->();
    my $t = EV::timer(5, 0, sub { EV::break });
    EV::run;

    # Small delay between changes for watch to process
    my $delay = EV::timer(0.3, 0, sub { EV::break });
    EV::run;
}

# === Final state ===
print "\n=== Final local cache state ===\n";
for my $key (sort keys %local_cache) {
    print "  $key = $local_cache{$key}\n";
}

# === Cleanup ===
print "\n=== Cleanup ===\n";
$publisher->delete($prefix, { prefix => 1 }, sub {
    my ($resp, $err) = @_;
    print "Deleted $resp->{deleted} keys\n";
    EV::break;
});
my $t_cleanup = EV::timer(5, 0, sub { EV::break });
EV::run;

print "\nDone.\n";
