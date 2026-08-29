use v5.36;
use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use JSON::PP qw(decode_json);
use Test::More;

my $root = File::Spec->catdir($Bin, '..');
my $script = File::Spec->catfile(
    $root, 'bench', 'run-performance-regression.pl',
);
my $temporary = tempdir(CLEANUP => 1);
my $baseline = File::Spec->catfile($temporary, 'baseline.json');
my $candidate = File::Spec->catfile($temporary, 'candidate.json');

# Keep every measured workload above coarse process-CPU clock resolution.
my @common = (
    '--repeats=1',
    '--iterations=25000',
    '--pool=64',
    '--clients=16',
    '--messages=500',
    '--connections=500',
    '--warmup-iterations=100',
    '--warmup-messages=10',
    '--warmup-connections=10',
);

is(system($^X, $script, @common, "--json=$baseline"), 0,
    'performance baseline smoke run succeeds');
ok(-s $baseline, 'baseline JSON is written');

is(system(
    $^X, $script, @common,
    "--baseline=$baseline",
    '--threshold-percent=1000000',
    '--fail-on-regression',
    "--json=$candidate",
), 0, 'compatible candidate comparison succeeds');
ok(-s $candidate, 'candidate JSON is written');

open my $fh, '<', $candidate or die "open $candidate: $!";
local $/;
my $report = decode_json(<$fh>);
close $fh;

is($report->{benchmark}, 'linux-event-performance-regression',
    'report identifies the benchmark');
is($report->{benchmark_contract_version}, 3,
    'report records the contract version');
is(scalar @{ $report->{summary} }, 9,
    'report contains every default workload');
is(scalar @{ $report->{comparison}{workloads} }, 9,
    'comparison contains every default workload');

done_testing;
