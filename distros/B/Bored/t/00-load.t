#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
    use_ok('Bored') or BAIL_OUT("Cannot load Bored");
}

diag("Testing Bored $Bored::VERSION");
ok($Bored::VERSION, "version is defined: $Bored::VERSION");
