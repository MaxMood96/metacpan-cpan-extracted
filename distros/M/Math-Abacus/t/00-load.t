#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Math::Abacus' ) || print "Bail out!\n";
}

diag( "Testing Math::Abacus $Math::Abacus::VERSION, Perl $], $^X" );
