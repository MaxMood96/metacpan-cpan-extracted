#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'DateTime::Ordinal' ) || print "Bail out!\n";
}

diag( "Testing DateTime::Ordinal $DateTime::Ordinal::VERSION, Perl $], $^X" );
