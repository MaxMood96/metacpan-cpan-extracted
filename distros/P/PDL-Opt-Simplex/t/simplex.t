use strict;
use warnings;
use Test::More;
use PDL::LiteF;
use PDL::Opt::Simplex;
use Test::PDL -atol => 1e-3;

sub test_simplex {
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  my ($init, $initsize, $dis, $nolog) = @_;
  my $log_called = 0;
  my $logsub = sub {$log_called++};
  my ( $opt, $ssize, $optval ) = simplex(
    $init->copy, $initsize, 1e-4, 1e4, sub {
      # f = x^2 + (y-1)^2 + 1
      sumover( ( $_[0] - $dis )**2 ) + 1;
    }, $nolog ? () : $logsub,
  );
  is_pdl $opt, $dis, 'optimum' or diag "got=$opt";
  is_pdl $ssize, pdl(0), 'ssize' or diag "got=$ssize";
  is_pdl $optval, pdl(1), 'optval' or diag "got=$optval";
  ok $log_called, 'log called' if !$nolog;
  my @init_dims = $init->dims;
  my @exp_dims = ($init_dims[0], 1, @init_dims[2..$#init_dims]);
  is_deeply [$opt->dims], \@exp_dims, 'dims optimum right';
}

test_simplex(pdl(2,2), 0.01, pdl([[0,1]]));
test_simplex(pdl(2,2), pdl(0.01,0.01), pdl([[0,1]]));
test_simplex(pdl(2,2), pdl(0.01,0.01), pdl([[0,1]]), 1);
test_simplex(pdl(2,2,2), pdl(0.01,0.01,0.01), pdl([[0,1,2]]));
test_simplex(my $p = pdl(q[-1 -1; -1.1 -1; -1.1 -0.9]), pdl(0.01,0.01), pdl([[0,1]]));
test_simplex($p, undef, pdl([[-1,1]]));

my $s = make_simplex(pdl(0,0,0), pdl(0.12,0.12,0.12));
is_pdl $s, pdl '0 -0.06 -0.08; 0.12 -0.06 -0.08; 0 0.06 -0.08; 0 0 0.04';

done_testing;
