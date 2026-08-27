#!perl
use 5.010;
use strict;
use warnings;
use Test::More;

# No BEGIN block around use_ok. A BEGIN runs at compile time, which is before
# the runtime `plan`, so the first test would be emitted ahead of the plan and
# the harness reports "Plan must be at the beginning or end of the TAP output"
# - a FAIL with every subtest passing, which is a confusing way to fail.
plan tests => 2;

use_ok('Punk::Observe') || print "Bail out!\n";

# The XS bootstrapped if a symbol from it answers. use_ok alone would pass on
# a .pm whose XSLoader::load silently found nothing to do.
ok(defined Punk::Observe::rec_size(), 'the XS bootstrapped');

diag("Testing Punk::Observe $Punk::Observe::VERSION, Perl $], $^X");
