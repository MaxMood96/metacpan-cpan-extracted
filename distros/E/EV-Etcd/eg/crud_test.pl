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

print "=== CRUD Test ===\n\n";

# Step 1: Put
print "1. PUT /test = 'hello world'\n";
$client->put('/test', 'hello world', sub {
    my ($resp, $err) = @_;
    die "Put error: $err->{message}" if $err;
    print "   Put OK, revision: $resp->{header}{revision}\n\n";

    # Step 2: Get
    print "2. GET /test\n";
    $client->get('/test', sub {
        my ($resp, $err) = @_;
        die "Get error: $err->{message}" if $err;
        print "   Value: '$resp->{kvs}[0]{value}'\n\n";

        # Step 3: Delete
        print "3. DELETE /test\n";
        $client->delete('/test', sub {
            my ($resp, $err) = @_;
            die "Delete error: $err->{message}" if $err;
            print "   Deleted: $resp->{deleted} key(s)\n\n";

            # Step 4: Get again (should be empty)
            print "4. GET /test (should be empty)\n";
            $client->get('/test', sub {
                my ($resp, $err) = @_;
                die "Get error: $err->{message}" if $err;
                my $count = scalar @{$resp->{kvs}};
                print "   Found: $count key(s)\n";
                print "   " . ($count == 0 ? "OK - key was deleted" : "ERROR - key still exists") . "\n\n";

                print "=== Test Complete ===\n";
                EV::break;
            });
        });
    });
});

EV::run;
