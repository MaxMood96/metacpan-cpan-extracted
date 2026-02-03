#!/usr/bin/perl

use v5.36;

use Future::AsyncAwait;

use Conduit;

use Future::IO 0.18; # ->load_best_impl

Future::IO->load_best_impl;

my $server = Conduit->new(
   port => 8080,
   psgi_app => sub ( $env ) {
      return [
         200,
         [ "Content-Type" => "text/plain" ],
         [ "Hello, world!" ],
      ];
   },
);

await $server->run;
