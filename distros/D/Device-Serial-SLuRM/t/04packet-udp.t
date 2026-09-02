#!/usr/bin/perl

use v5.28;
use warnings;

use Test2::V0;
use Test::Future::IO 0.07;

use Future::Buffer 0.05; # immediate fill bugfix

use constant HAVE_TEST_METRICS_ANY => eval { require Test::Metrics::Any };

use Future::AsyncAwait;

use Device::Serial::SLuRM::Protocol;

use Digest::CRC qw( crc8 );

my $controller = Test::Future::IO->controller;

$controller->use_sysread_buffer( "DummyFH" )
   ->indefinitely;

my $proto = Device::Serial::SLuRM::Protocol->new(
   fh => "DummyFH",
   transport => "udp",
   multidrop => 1,  # UDP requires multidrop
);

sub with_crc8
{
   my ( $data ) = @_;
   return pack "a* C", $data, crc8( $data );
}

# recv
{
   # TODO: add recv buffering to Test::Future::IO
   $controller->expect_recv( "DummyFH", 512 )
      ->will_done(
         "udpSLuRM" . "\x00\x00\x00\x01" .
         with_crc8( with_crc8( "\x10\x00\x03" ) . "ABC" ) );

   is( [ await $proto->recv ], [ 0x10, 0, "ABC" ],
      'One packet received by ->recv' );

   # TODO: metrics

   $controller->check_and_clear( '->recv' );
}

# send
{
   $controller->expect_send( "DummyFH",
      "udpSLuRM" . "\x00\x00\x00\x01" .
         with_crc8( with_crc8( "\x18\x00\x03" ) . "DEF" ) );

   await $proto->send( 0x18, 0, "DEF" );

   # TODO: metrics

   $controller->check_and_clear( '->send' );
}

done_testing;
