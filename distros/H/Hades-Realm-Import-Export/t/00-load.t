#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Hades::Realm::Import::Export' ) || print "Bail out!\n";
}

diag( "Testing Hades::Realm::Import::Export $Hades::Realm::Import::Export::VERSION, Perl $], $^X" );
