use v5.36;
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

my $script = "$Bin/../bench/run-connect-microbench.pl";
ok(-s $script, 'Connect lifecycle benchmark is present');

my $output = qx{$^X -Mblib "$script" --help 2>&1};
is($?, 0, 'Connect lifecycle benchmark help exits successfully');
like($output, qr/--connections=N/, 'benchmark help documents connection count');
like($output, qr/manual,add,loop/,
    'benchmark help documents raw baseline and both attachment rows');
like($output, qr/--timeout=SECONDS/, 'benchmark help documents catastrophic deadline');
like($output, qr/--json=PATH/, 'benchmark help documents structured output');

done_testing;
