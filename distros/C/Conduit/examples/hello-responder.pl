#!/usr/bin/perl

use v5.36;

use Future::AsyncAwait;

use Conduit;

use Future::IO 0.18; # ->load_best_impl

Future::IO->load_best_impl;

my $server = Conduit->new(
   port => 8080,
   responder => async sub ( $req ) {
      my $resp = HTTP::Response->new( 200 );
      $resp->content_type( "text/plain" );
      $resp->content( "Hello, world!" );
      return $resp;
   },
);

await $server->run;
