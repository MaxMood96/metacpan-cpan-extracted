use v5.36;
use strict;
use warnings;
use Test::More;

my $cmd = join ' ',
    $^X,
    'bench/run-stream-microbench.pl',
    '--clients', 1,
    '--warmup', 1,
    '--messages', 5,
    '--bytes', 16,
    '--repeats', 1,
    '2>&1';

my $out = qx{$cmd};
is($?, 0, 'Stream microbenchmark exits successfully') or diag $out;
like($out, qr/raw-reactor clients=1/, 'raw reactor baseline ran');
like($out, qr/subclass-stream clients=1/, 'subclass-defined Stream ran');
like($out, qr/subclass-stream-deadline clients=1/,
    'deadline-tracked subclass-defined Stream ran');
like($out, qr/subclass-stream-capped clients=1/,
    'hard-capped subclass-defined Stream ran');
like($out, qr/Median Stream microbenchmark/, 'summary emitted');

done_testing;
