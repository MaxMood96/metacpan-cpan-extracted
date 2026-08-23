use v5.36;
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

my $script = "$Bin/../bench/run-resolver-microbench.pl";
ok(-s $script, 'resolver benchmark is present');
my $output = qx{$^X -Mblib "$script" --help 2>&1};
is($?, 0, 'resolver benchmark help exits successfully');
like($output, qr/--requests=N/, 'benchmark documents request count');
like($output, qr/--host=NAME/, 'benchmark documents resolver target');

done_testing;
