#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok('Test::PostgreSQL::v2') || print "Bail out!\n";
}

diag( "Testing Test::PostgreSQL::v2 $Test::PostgreSQL::v2::VERSION, Perl $], $^X" );

done_testing;
