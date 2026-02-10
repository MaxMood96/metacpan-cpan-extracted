#!perl
use 5.010;
use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
  use_ok ('Term::CmdLine') || print "Bail out!\n";
}

diag ("Testing Term::CmdLine $Term::CmdLine::VERSION, Perl $], $^X");

ok (defined $Term::CmdLine::VERSION, 'VERSION is defined');

diag ('');
diag ('NOTE: Additional tests require creating Term::ReadLine instances.');
diag ('Term::ReadLine::Gnu only allows one instance per process,');
diag ('so comprehensive testing should be done interactively.');
diag ('See t/99-scaffolding.t for a demonstration of module functionality.');
