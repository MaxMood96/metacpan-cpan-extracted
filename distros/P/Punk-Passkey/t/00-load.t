#!perl
use 5.010;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Punk::Passkey' ) || print "Bail out!\n";
}

diag( "Testing Punk::Passkey $Punk::Passkey::VERSION, Perl $], $^X" );
