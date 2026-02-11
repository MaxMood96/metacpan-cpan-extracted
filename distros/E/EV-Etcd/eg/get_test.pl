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

print "Created client, fetching key '/test'...\n";

$client->get('/test', sub {
    my ($resp, $err) = @_;

    if ($err) {
        print "Error: $err->{message}\n";
    } else {
        print "Response:\n";
        print Dumper($resp);
    }

    # Stop the event loop after we get a response
    EV::break;
});

print "Starting event loop...\n";
EV::run;
print "Done.\n";
