#!/usr/bin/perl

use v5.28;
use warnings;

use Test2::V0;
use Test::Future::Deferred 0.52;  # ->flush method
use Test::Future::IO 0.05;

use Future::AsyncAwait;

use Device::Serial::MSLuRM;

use Digest::CRC qw( crc8 );

my $controller = Test::Future::IO->controller;

my $slurm = Device::Serial::MSLuRM->new( fh => "DummyFH" );

$controller->use_sysread_buffer( "DummyFH" )
   ->indefinitely;

sub with_crc8
{
   my ( $data ) = @_;
   return pack "a* C", $data, crc8( $data );
}

# Implicit reset sending is tested in t/23multi-request.t

# Accept reset
{
   $controller->expect_sysread( "DummyFH", 8192 )
      ->will_done( "\x55" . with_crc8( with_crc8( "\x01\x05\x01" ) . "\x09" ) );
   $controller->expect_syswrite( "DummyFH", "\x55" . with_crc8( with_crc8( "\x02\x05\x01" ) . "\x00" ) );
   $controller->expect_sysread( "DummyFH", 8192 )
      ->remains_pending
      ->will_also_later( sub { $slurm->stop } );

   my $f = $slurm->run;
   Test::Future::Deferred->flush;

   ok( !$f->is_cancelled, '->run future is cancelled' );

   $controller->check_and_clear( 'Accepted RESET' );
}

done_testing;
