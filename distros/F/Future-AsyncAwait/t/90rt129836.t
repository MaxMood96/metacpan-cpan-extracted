#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

use Future::AsyncAwait;

async sub outer {
   my $inner = async sub {
      return "inner";
   };

   return await $inner->();
}

is( outer()->get, "inner", 'result of anon inside named' );

done_testing;
