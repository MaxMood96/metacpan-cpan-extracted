use strict;
use warnings;
use Test::More;

use lru;

diag("Testing lru $lru::VERSION, Perl $], $^X");

ok(1, 'lru loaded');

done_testing;
