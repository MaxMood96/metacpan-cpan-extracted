#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'CLI::Files::Utils' ) || print "Bail out!\n";
}

diag( "Testing CLI::Files::Utils $CLI::Files::Utils::VERSION, Perl $], $^X" );
