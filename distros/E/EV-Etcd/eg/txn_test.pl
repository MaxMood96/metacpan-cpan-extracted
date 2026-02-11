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

print "=== Transaction Test ===\n\n";

# Test 1: Compare-and-swap - create key if it doesn't exist (version == 0)
print "1. Compare-and-swap: Create '/txntest' only if it doesn't exist...\n";

$client->txn(
    # Compare: version == 0 means key doesn't exist
    [
        { key => '/txntest', target => 'version', result => '=', version => 0 },
    ],
    # Success: create the key
    [
        { put => { key => '/txntest', value => 'initial-value' } },
    ],
    # Failure: get current value
    [
        { range => { key => '/txntest' } },
    ],
    sub {
        my ($resp, $err) = @_;

        if ($err) {
            print "Transaction error: $err->{message}\n";
            EV::break;
            return;
        }

        print "   Transaction succeeded: $resp->{succeeded}\n";
        print "   Revision: $resp->{header}{revision}\n";

        if ($resp->{succeeded}) {
            print "   Key was created (didn't exist before)\n\n";
        } else {
            print "   Key already existed, got current value:\n";
            my $range_resp = $resp->{responses}[0]{response_range};
            if ($range_resp && @{$range_resp->{kvs}}) {
                print "   Value: $range_resp->{kvs}[0]{value}\n\n";
            }
        }

        # Test 2: Update only if value matches
        test_conditional_update();
    }
);

sub test_conditional_update {
    print "2. Conditional update: Change value only if current value matches...\n";

    $client->txn(
        # Compare: value must be 'initial-value'
        [
            { key => '/txntest', target => 'value', result => '=', value => 'initial-value' },
        ],
        # Success: update the value
        [
            { put => { key => '/txntest', value => 'updated-value' } },
        ],
        # Failure: do nothing (empty array)
        [],
        sub {
            my ($resp, $err) = @_;

            if ($err) {
                print "Transaction error: $err->{message}\n";
                EV::break;
                return;
            }

            print "   Transaction succeeded: $resp->{succeeded}\n";

            if ($resp->{succeeded}) {
                print "   Value was updated\n\n";
            } else {
                print "   Value didn't match, no update\n\n";
            }

            # Test 3: Multi-key transaction
            test_multi_key();
        }
    );
}

sub test_multi_key {
    print "3. Multi-key transaction: Update multiple keys atomically...\n";

    $client->txn(
        # No compare conditions (always succeeds)
        [],
        # Success: put multiple keys
        [
            { put => { key => '/txntest/a', value => 'value-a' } },
            { put => { key => '/txntest/b', value => 'value-b' } },
            { put => { key => '/txntest/c', value => 'value-c' } },
        ],
        # Failure: (won't happen)
        [],
        sub {
            my ($resp, $err) = @_;

            if ($err) {
                print "Transaction error: $err->{message}\n";
                EV::break;
                return;
            }

            print "   Transaction succeeded: $resp->{succeeded}\n";
            print "   Created " . scalar(@{$resp->{responses}}) . " keys atomically\n\n";

            # Clean up
            cleanup();
        }
    );
}

sub cleanup {
    print "4. Cleanup: Delete test keys...\n";

    $client->delete('/txntest', { range_end => '/txntest0' }, sub {
        my ($resp, $err) = @_;

        if ($err) {
            print "Delete error: $err->{message}\n";
        } else {
            print "   Deleted $resp->{deleted} keys\n";
        }

        EV::break;
    });
}

# Set up a timeout
my $timeout = EV::timer(30, 0, sub {
    print "Timeout reached, stopping.\n";
    EV::break;
});

print "Starting event loop...\n";
EV::run;
print "\nDone.\n";
