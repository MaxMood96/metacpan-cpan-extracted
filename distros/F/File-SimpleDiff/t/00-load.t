#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'File::SimpleDiff' ) || print "Bail out!\n";
}

diag( "Testing File::SimpleDiff $File::SimpleDiff::VERSION, Perl $], $^X" );
