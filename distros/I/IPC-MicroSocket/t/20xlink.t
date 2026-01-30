#!/usr/bin/perl

use v5.36;

use Test2::V0;

use Object::Pad 0.800;
use Future::AsyncAwait;

use IPC::MicroSocket::Server;
use IPC::MicroSocket::Client;

use Future::IO;

eval { Future::IO->load_best_impl } and $Future::IO::IMPL->HAVE_MULTIPLE_FILEHANDLES or
   plan skip_all => "No suitable Future::IO implementation";

my $latest_command;

class TestServer {
   inherit IPC::MicroSocket::Server;

   async method on_connection_request ( $conn, $cmd, @args )
   {
      $latest_command = $cmd;
      return $cmd + $args[0];
   }

   method on_connection_subscribe ( @ ) {}
}

my $server = TestServer->new( fh => undef );

my $client = IPC::MicroSocket::Client->new_inprocess( $server );

# request OK
{
   is( [ await $client->request( "123", "456" ) ], [ "579" ],
      'Result of ->request' );
   is( $latest_command, "123", 'Server saw request' );
}

done_testing;
