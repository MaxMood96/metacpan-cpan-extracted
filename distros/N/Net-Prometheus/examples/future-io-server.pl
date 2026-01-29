#!/usr/bin/perl

use v5.20;
use warnings;

use Future::IO 0.18; # ->load_best_impl
use Metrics::Any::Adapter 'Prometheus';
use Net::Prometheus;

use constant LISTEN_PORT => 8200;

Future::IO->load_best_impl;

$Net::Prometheus::PerlCollector::DETAIL = 1;

my $client = Net::Prometheus->new;

$client->new_gauge(
   name => "ten",
   help => "The number ten",
)->set( 10 );

printf STDERR "Serving metrics on http://[::]:%d\n", LISTEN_PORT;

$client->export_to_Future_IO( port => LISTEN_PORT )->await;
