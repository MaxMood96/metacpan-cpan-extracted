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

print "Created client\n";

# First, put a value
print "Putting key '/test' with value 'hello from perl'...\n";

$client->put('/test', 'hello from perl', sub {
    my ($resp, $err) = @_;

    if ($err) {
        print "Put error: $err->{message}\n";
        EV::break;
        return;
    }

    print "Put succeeded!\n";
    print "Response: ", Dumper($resp);

    # Now get it back
    print "\nGetting key '/test'...\n";

    $client->get('/test', sub {
        my ($resp, $err) = @_;

        if ($err) {
            print "Get error: $err->{message}\n";
        } else {
            print "Get succeeded!\n";
            print "Response: ", Dumper($resp);

            if (@{$resp->{kvs}}) {
                print "\nKey: $resp->{kvs}[0]{key}\n";
                print "Value: $resp->{kvs}[0]{value}\n";
            }
        }

        EV::break;
    });
});

print "Starting event loop...\n";
EV::run;
print "Done.\n";
