use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok('Uniform::HTMX::PAGI') || print "Bail out!\n";
}

diag("Testing Uniform::HTMX::PAGI $Uniform::HTMX::PAGI::VERSION, Perl $], $^X");
