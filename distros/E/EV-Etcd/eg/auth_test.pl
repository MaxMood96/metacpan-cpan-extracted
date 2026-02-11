#!/usr/bin/env perl
use strict;
use warnings;
use lib 'blib/lib', 'blib/arch';
use EV;
use EV::Etcd;
use Data::Dumper;

# Note: For this test to work, you need to:
# 1. Enable auth in etcd:
#    etcdctl user add root:rootpassword
#    etcdctl auth enable
# 2. Or create a non-root user:
#    etcdctl user add testuser:testpass
#    etcdctl role add testrole
#    etcdctl role grant-permission testrole readwrite /authtest --prefix
#    etcdctl user grant-role testuser testrole

my $username = $ENV{ETCD_USER} // 'root';
my $password = $ENV{ETCD_PASSWORD} // 'rootpassword';

my $client = EV::Etcd->new(
    endpoints => ['127.0.0.1:2379'],
);

print "=== Authentication Test ===\n\n";

# Step 1: Authenticate
print "1. Authenticating as '$username'...\n";
$client->authenticate($username, $password, sub {
    my ($resp, $err) = @_;

    if ($err) {
        print "Authentication error: $err->{message}\n";
        print "\nNote: Make sure etcd has authentication enabled.\n";
        print "To enable auth:\n";
        print "  etcdctl user add root:rootpassword\n";
        print "  etcdctl auth enable\n";
        EV::break;
        return;
    }

    print "   Authentication successful!\n";
    print "   Token length: " . length($resp->{token}) . " bytes\n\n";

    # Step 2: Use authenticated client to put a key
    print "2. Putting key '/authtest' (using auth token)...\n";
    $client->put('/authtest', 'authenticated-value', sub {
        my ($resp, $err) = @_;

        if ($err) {
            print "Put error: $err->{message}\n";
            EV::break;
            return;
        }

        print "   Key stored (revision: $resp->{header}{revision})\n\n";

        # Step 3: Get the key
        print "3. Getting key '/authtest'...\n";
        $client->get('/authtest', sub {
            my ($resp, $err) = @_;

            if ($err) {
                print "Get error: $err->{message}\n";
                EV::break;
                return;
            }

            if (@{$resp->{kvs}}) {
                print "   Key: $resp->{kvs}[0]{key}\n";
                print "   Value: $resp->{kvs}[0]{value}\n\n";
            }

            # Step 4: Use transaction with auth
            print "4. Running transaction with auth...\n";
            $client->txn(
                [],
                [
                    { put => { key => '/authtest/txn1', value => 'txn-value-1' } },
                    { put => { key => '/authtest/txn2', value => 'txn-value-2' } },
                ],
                [],
                sub {
                    my ($resp, $err) = @_;

                    if ($err) {
                        print "Transaction error: $err->{message}\n";
                        EV::break;
                        return;
                    }

                    print "   Transaction succeeded: $resp->{succeeded}\n\n";

                    # Cleanup
                    cleanup();
                }
            );
        });
    });
});

sub cleanup {
    print "5. Cleanup: Deleting test keys...\n";

    $client->delete('/authtest', { range_end => '/authtest0' }, sub {
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
