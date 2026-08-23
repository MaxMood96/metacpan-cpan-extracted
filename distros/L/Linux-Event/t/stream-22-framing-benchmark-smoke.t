use v5.36;
use strict;
use warnings;
use Test::More;

my $out = qx{$^X bench/run-framing-microbench.pl --clients 1 --warmup 1 --messages 5 --bytes 16 --repeats 1 2>&1};
is($?, 0, 'framing microbenchmark exits successfully') or diag $out;
like($out, qr/raw-on-data clients=1/, 'raw on_data parser path ran');
like($out, qr/native-delimiter clients=1/, 'native delimiter path ran');
like($out, qr/Median framing microbenchmark/, 'framing summary emitted');

done_testing;
