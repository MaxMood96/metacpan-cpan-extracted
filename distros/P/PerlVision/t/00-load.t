#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'PerlVision' ) || print "Bail out!
";
}

diag( "Testing PerlVision $PerlVision::VERSION, Perl $], $^X" );
