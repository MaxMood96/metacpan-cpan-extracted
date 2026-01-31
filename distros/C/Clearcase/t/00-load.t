#!perl

use Test::More tests => 1;

BEGIN {
  use_ok ('Clearcase');
}

diag ("Testing Clearcase $Clearcase::VERSION, Perl $], $^X");
