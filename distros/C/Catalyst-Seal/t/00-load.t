#!perl
use 5.008003;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Catalyst::Seal' ) || print "Bail out!\n";
}

diag( "Testing Catalyst::Seal $Catalyst::Seal::VERSION, Perl $], $^X" );
