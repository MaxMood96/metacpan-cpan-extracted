use v5.36;
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

my $script = "$Bin/../bench/run-signal-microbench.pl";
ok(-s $script, 'Signal benchmark is present');
my $output = qx{$^X -Mblib "$script" --help 2>&1};
is($?, 0, 'Signal benchmark help exits successfully');
like($output, qr/--deliveries=N/, 'benchmark documents delivery count');
like($output, qr/--subscribers=LIST/,
    'benchmark documents fan-out subscriber counts');

done_testing;
