#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'WebService::MIAB' ) || print "Bail out!\n";
}

diag( "Testing WebService::MIAB $WebService::MIAB::VERSION, Perl $], $^X" );
