#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Hades::Realm::Exporter' ) || print "Bail out!\n";
}

diag( "Testing Hades::Realm::Exporter $Hades::Realm::Exporter::VERSION, Perl $], $^X" );
