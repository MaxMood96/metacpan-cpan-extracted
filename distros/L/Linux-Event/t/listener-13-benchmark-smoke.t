use v5.36;
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Spec;

my $root = File::Spec->catdir($Bin, '..');
my $script = File::Spec->catfile($root, 'bench',
    'run-listen-microbench.pl');
my $command = qq{$^X -Mblib "$script" --help 2>&1};
my $output = qx{$command};
is($? >> 8, 0, 'Listen benchmark help exits successfully');
like($output, qr/Listen lifecycle benchmark|run-listen-microbench/,
    'Listen benchmark help identifies the permanent script');
like($output, qr/manual,add,loop/,
    'help lists raw baseline and both Listener attachment modes');
like($output, qr/--timeout=SECONDS/, 'help documents catastrophic deadline');

done_testing;
