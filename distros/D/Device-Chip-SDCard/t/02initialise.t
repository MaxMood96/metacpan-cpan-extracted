#!/usr/bin/perl

use v5.26;
use warnings;

use Test2::V0;
use Test::Device::Chip::Adapter;

use Future::AsyncAwait;

use Device::Chip::SDCard;

my $chip = Device::Chip::SDCard->new;

await $chip->mount(
   my $adapter = Test::Device::Chip::Adapter->new,
);

{
   # Initalisation first writes >9 bytes of all-high-bits
   $adapter->expect_write( "\xFF" x 10 );
   # Then CMD0 arg=0
   $adapter->expect_readwrite( "\x40" . "\0\0\0\0" . "\x95" . "\xFF" x 8 )
      ->returns( "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" . "\x01" );
   # Then CMD1 arg=0 until the response is not idle. Lets do it twice just
   #   to check this
   $adapter->expect_readwrite( "\x41" . "\0\0\0\0" . "\x95" . "\xFF" x 8 )
      ->returns( "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" . "\x01" );
   $adapter->expect_readwrite( "\x41" . "\0\0\0\0" . "\x95" . "\xFF" x 8 )
      ->returns( "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" . "\x00" );
   # Set block length to 512
   $adapter->expect_readwrite( "\x50" . "\0\0\2\0" . "\x95" . "\xFF" x 8 )
      ->returns( "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" . "\x00" );

   await $chip->initialise;

   $adapter->check_and_clear( '$chip->initialise' );
}

done_testing;
