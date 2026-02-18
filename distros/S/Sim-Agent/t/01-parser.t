use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);

use Sim::Agent::Parser;

my ($fh, $path) = tempfile();
print $fh <<'SEXP';
; comment
(system
  (limits (max_iterations 3))
  (entry Worker1)
  (agent Worker1 (role worker) (model "m") (prompt-file "p") (self-critic-file "s") (revision-file "r") (send-to Critic1))
  (agent Critic1 (role critic) (parse-file "c") (on-ok (Chief1)) (on-fail (Worker1)))
  (agent Chief1 (role chief) (parse-file "k"))
)
SEXP
close $fh;

my $p = Sim::Agent::Parser->new;
my $ast = $p->parse_file($path);

is(ref($ast), 'ARRAY', 'AST is array');
is($ast->[0], 'system', 'root is system');

done_testing;
