#!perl
use 5.008003;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Bored' ) || print "Bail out!\n";
}

diag( "Testing Bored $Bored::VERSION, Perl $], $^X" );
