use strict;
use warnings;
use Test::More;

BEGIN {
    use_ok('Uniform::HTMX::Dancer2') || print "Bail out!\n";
}

diag("Testing Uniform::HTMX::Dancer2 $Uniform::HTMX::Dancer2::VERSION, Perl $], $^X");

done_testing();
