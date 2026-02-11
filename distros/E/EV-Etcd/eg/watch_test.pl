#!/usr/bin/env perl
use strict;
use warnings;
use lib 'blib/lib', 'blib/arch';
use EV;
use EV::Etcd;
use Data::Dumper;

my $client = EV::Etcd->new(
    endpoints => ['127.0.0.1:2379'],
);

print "=== Watch Test ===\n\n";
print "Watching key '/watchtest'...\n";
print "(In another terminal, run: etcdctl put /watchtest value1)\n\n";

my $event_count = 0;

$client->watch('/watchtest', sub {
    my ($resp, $err) = @_;

    if ($err) {
        print "Watch error: $err->{message}\n";
        EV::break;
        return;
    }

    if ($resp->{created}) {
        print "Watch created, watch_id: $resp->{watch_id}\n\n";
        return;
    }

    for my $event (@{$resp->{events}}) {
        $event_count++;
        print "Event #$event_count:\n";
        print "  Type: $event->{type}\n";
        print "  Key: $event->{kv}{key}\n";
        print "  Value: $event->{kv}{value}\n";
        print "  Revision: $resp->{header}{revision}\n\n";
    }

    # Stop after 3 events for demo purposes
    if ($event_count >= 3) {
        print "Received 3 events, stopping.\n";
        EV::break;
    }
});

# Set up a timer to demonstrate the watch is async
my $timer = EV::timer(5, 5, sub {
    print "(Still watching... $event_count events so far)\n";
});

print "Starting event loop...\n";
EV::run;
print "Done.\n";
