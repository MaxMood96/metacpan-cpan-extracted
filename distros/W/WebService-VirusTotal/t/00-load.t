#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'WebService::VirusTotal' ) || print "Bail out!\n";
}

diag( "Testing WebService::VirusTotal $WebService::VirusTotal::VERSION, Perl $], $^X" );
