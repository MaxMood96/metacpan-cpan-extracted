#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'File::Record' ) || print "Bail out!\n";
}

diag( "Testing File::Record $File::Record::VERSION, Perl $], $^X" );
