#!perl
use v5.38;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Logic::Relational' ) || print "Bail out!\n";
}

diag( "Testing Logic::Relational $Logic::Relational::VERSION, Perl $], $^X" );
