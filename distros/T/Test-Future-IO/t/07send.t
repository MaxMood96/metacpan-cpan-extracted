#!/usr/bin/perl

use v5.20;
use warnings;

use Test::Builder::Tester;
use Test2::V0;

use Test::Future::IO;

my $test_fio = Test::Future::IO->controller;

# pass
{
   test_out q[ok 1 - Future::IO->send consumes data];
   test_out q[# Subtest: ->send];
   test_out q[    ok 1 - ->send('dummyFH', 'Hello', undef, undef)];
   test_out q[    1..1];
   test_out q[ok 2 - ->send];

   $test_fio->expect_send( "dummyFH", "Hello" );

   is( Future::IO->send( "dummyFH", "Hello" )->get, 5,
         'Future::IO->send consumes data' );

   $test_fio->check_and_clear( '->send' );

   test_test( 'send OK' );
}

done_testing;
