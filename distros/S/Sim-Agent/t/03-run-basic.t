use strict;
use warnings;
use Test::More;

use Sim::Agent::Parser;
use Sim::Agent::Compiler;

my $ast = Sim::Agent::Parser->new->parse_file('examples/join.sexpr');
my $g   = Sim::Agent::Compiler->new->compile($ast);

ok($g->{entry}, 'join example compiles');

done_testing;
