#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Acme::InputRecordSeparatorIsRegexp' ) || print "Bail out!\n";
}

diag( "Testing Acme::InputRecordSeparatorIsRegexp $Acme::InputRecordSeparatorIsRegexp::VERSION, Perl $], $^X" );

if ($] < 5.010000) {
    diag "readline on this package is sloooow for Perl $]. ",
        "Please be patient with some of these tests.";
}

