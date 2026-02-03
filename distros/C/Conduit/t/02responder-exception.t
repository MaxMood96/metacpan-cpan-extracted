#!/usr/bin/perl

use v5.36;

use Test2::V0;
use Test::Future::IO;

use Conduit;

my $controller = Test::Future::IO->controller;

{
   my $server = Conduit->new(
      listensock => "LISTEN",
      responder => sub ( $req ) {
         die "Oopsie\n";
      },
   );

   my $run_f;

   $controller->expect_accept( "LISTEN" )
      ->will_done( "CLIENT" );
   $controller->expect_sysread( "CLIENT", 8192 )
      ->will_done( <<'EOF' =~ s/\n/\x0D\x0A/gr );
GET / HTTP/1.1

EOF
   $controller->expect_accept( "LISTEN" )
      ->remains_pending;
   # TODO: This is fragile for buffer splitting
   $controller->expect_syswrite( "CLIENT", <<'EOF' =~ s/\n/\x0D\x0A/gr
HTTP/1.1 500 Internal Server Error
Content-Length: 6
Content-Type: text/plain

EOF
      . "Oopsie" );
   $controller->expect_sysread( "CLIENT", 8192 )
      ->will_done() # EOF
      ->will_also_later( sub () { $run_f->done("STOP") } );

   $run_f = $server->run;

   is( [ $run_f->get ], [ "STOP" ],
      '->run future yields STOP placeholder' );

   $controller->check_and_clear( 'Simple HTTP responder' );
}

done_testing;
