use strict;
use warnings;
use Test::More;

BEGIN {
    use_ok('Uniform::Upload')       || print "Bail out!\n";
    use_ok('Uniform::Upload::File') || print "Bail out!\n";
}

diag("Testing Uniform::Upload $Uniform::Upload::VERSION, Perl $], $^X");

done_testing();
