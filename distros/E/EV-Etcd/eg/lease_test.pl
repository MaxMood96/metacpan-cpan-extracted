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

print "=== Lease Test ===\n\n";

my $lease_id;
my $keepalive_count = 0;

# Step 1: Grant a lease with 10 second TTL
print "1. Granting lease with TTL=10s...\n";
$client->lease_grant(10, sub {
    my ($resp, $err) = @_;

    if ($err) {
        print "Lease grant error: $err->{message}\n";
        EV::break;
        return;
    }

    $lease_id = $resp->{id};
    print "   Lease granted: ID=$lease_id, TTL=$resp->{ttl}\n\n";

    # Step 2: Put a key with this lease
    print "2. Putting key '/leasetest' with lease...\n";
    $client->put('/leasetest', 'lease-value', { lease => $lease_id }, sub {
        my ($resp, $err) = @_;

        if ($err) {
            print "Put error: $err->{message}\n";
            EV::break;
            return;
        }

        print "   Key stored with lease (revision: $resp->{header}{revision})\n\n";

        # Step 3: Verify key exists
        print "3. Verifying key exists...\n";
        $client->get('/leasetest', sub {
            my ($resp, $err) = @_;

            if ($err) {
                print "Get error: $err->{message}\n";
                EV::break;
                return;
            }

            if (@{$resp->{kvs}}) {
                print "   Key exists: $resp->{kvs}[0]{key} = $resp->{kvs}[0]{value}\n\n";
            }

            # Step 4: Revoke the lease
            print "4. Revoking lease $lease_id...\n";
            $client->lease_revoke($lease_id, sub {
                my ($resp, $err) = @_;

                if ($err) {
                    print "Lease revoke error: $err->{message}\n";
                    EV::break;
                    return;
                }

                print "   Lease revoked (revision: $resp->{header}{revision})\n\n";

                # Step 5: Verify key is gone (because lease was revoked)
                print "5. Verifying key is deleted (lease revoked)...\n";
                $client->get('/leasetest', sub {
                    my ($resp, $err) = @_;

                    if ($err) {
                        print "Get error: $err->{message}\n";
                    } elsif (@{$resp->{kvs}}) {
                        print "   Key still exists (unexpected): $resp->{kvs}[0]{key}\n";
                    } else {
                        print "   Key deleted as expected (lease was revoked)\n";
                    }

                    EV::break;
                });
            });
        });
    });
});

# Set up a timeout
my $timeout = EV::timer(30, 0, sub {
    print "Timeout reached, stopping.\n";
    EV::break;
});

print "Starting event loop...\n";
EV::run;
print "\nDone.\n";
