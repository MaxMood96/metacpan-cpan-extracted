use v5.36;
use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use JSON::PP qw(decode_json);
use Test::More;

my $script = File::Spec->catfile(
    $Bin, '..', 'bench', 'run-wakeup-microbench.pl',
);
my $json = File::Spec->catfile(tempdir(CLEANUP => 1), 'wakeup.json');

is(system(
    $^X, '-Mblib', $script,
    '--signals=20', '--batch-sizes=1,4', '--repeats=1', "--json=$json",
), 0, 'Wakeup microbenchmark smoke run succeeds');
ok(-s $json, 'Wakeup benchmark writes JSON');

open my $fh, '<', $json or die "open $json: $!";
local $/;
my $report = decode_json(<$fh>);
close $fh;

is($report->{benchmark}, 'linux-event-wakeup-microbench',
    'report identifies Wakeup benchmark');
is($report->{benchmark_contract_version}, 1,
    'report records Wakeup benchmark contract');
is(scalar @{ $report->{summary} }, 2,
    'report contains every Wakeup batch size');

done_testing;
