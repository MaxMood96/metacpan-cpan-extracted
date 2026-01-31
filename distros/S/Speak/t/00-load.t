#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
  use_ok ('Speak') || print "Bail out!\n";
}

diag ("Testing Speak $Speak::VERSION, Perl $], $^X");
