#!/usr/bin/perl

use v5.20;
use warnings;

use Test::Builder::Tester;
use Test2::V0;

use Test::Future::IO;

my $test_fio = Test::Future::IO->controller;

# pass recv
{
   test_out q[ok 1 - Future::IO->recv yields data];
   test_out q[# Subtest: ->recv];
   test_out q[    ok 1 - ->recv('dummyFH', 5, undef)];
   test_out q[    1..1];
   test_out q[ok 2 - ->recv];

   $test_fio->expect_recv( "dummyFH", 5 )
      ->will_done( "Hello" );

   is( Future::IO->recv( "dummyFH", 5 )->get, "Hello",
         'Future::IO->recv yields data' );

   $test_fio->check_and_clear( '->recv' );

   test_test( 'recv OK' );
}

# pass recvfrom
{
   test_out q[ok 1 - Future::IO->recvfrom yields data];
   test_out q[# Subtest: ->recvfrom];
   test_out q[    ok 1 - ->recvfrom('dummyFH', 5, undef)];
   test_out q[    1..1];
   test_out q[ok 2 - ->recvfrom];

   $test_fio->expect_recvfrom( "dummyFH", 5 )
      ->will_done( "Hello", "ADDR" );

   is( [ Future::IO->recvfrom( "dummyFH", 5 )->get ], [ "Hello", "ADDR" ],
         'Future::IO->recvfrom yields data' );

   $test_fio->check_and_clear( '->recvfrom' );

   test_test( 'recvfrom OK' );
}

done_testing;
