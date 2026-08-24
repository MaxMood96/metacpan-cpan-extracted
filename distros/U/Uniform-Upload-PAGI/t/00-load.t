use strict;
use warnings;
use Test::More;

BEGIN {
    use_ok('Uniform::Upload::PAGI') || print "Bail out!\n";
}

diag("Testing Uniform::Upload::PAGI $Uniform::Upload::PAGI::VERSION, Perl $], $^X");

done_testing();
