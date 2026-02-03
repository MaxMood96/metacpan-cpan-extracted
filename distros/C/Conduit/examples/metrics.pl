#!/usr/bin/perl

use v5.36;

use Future::AsyncAwait;

use Conduit;

use Future::IO 0.18; # ->load_best_impl
use Metrics::Any::Adapter 'Prometheus';
use Net::Prometheus;

Future::IO->load_best_impl;

my $conduit = Conduit->new(
   port => 8080,
   psgi_app => Net::Prometheus->new->psgi_app,
);

await $conduit->run;
