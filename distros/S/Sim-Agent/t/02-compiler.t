use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);

use Sim::Agent::Parser;
use Sim::Agent::Compiler;

my ($fh, $path) = tempfile();
print $fh <<'SEXP';
(system
  (entry Worker1)
  (agent Worker1 (role worker) (model "m") (prompt-file "p") (self-critic-file "s") (revision-file "r") (send-to Critic1))
  (agent Critic1 (role critic) (parse-file "c") (on-ok (Chief1)) (on-fail (Worker1)))
  (agent Chief1 (role chief) (parse-file "k"))
)
SEXP
close $fh;

my $ast = Sim::Agent::Parser->new->parse_file($path);
my $g   = Sim::Agent::Compiler->new->compile($ast);

is($g->{entry}, 'Worker1', 'entry');
ok(exists $g->{agents}->{Worker1}, 'has Worker1');
ok(exists $g->{agents}->{Critic1}, 'has Critic1');
ok(exists $g->{agents}->{Chief1},  'has Chief1');

done_testing;
