use v5.36;
use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use JSON::PP qw(decode_json);
use Test::More;

my $script = File::Spec->catfile(
    $Bin, '..', 'bench', 'run-process-microbench.pl',
);
my $json = File::Spec->catfile(tempdir(CLEANUP => 1), 'process.json');

is(system(
    $^X, '-Mblib', $script,
    '--processes=6', '--concurrency=1,2', '--repeats=1', "--json=$json",
), 0, 'Process microbenchmark smoke run succeeds');
ok(-s $json, 'Process benchmark writes JSON');

open my $fh, '<', $json or die "open $json: $!";
local $/;
my $report = decode_json(<$fh>);
close $fh;

is($report->{benchmark}, 'linux-event-process-microbench',
    'report identifies Process benchmark');
is($report->{benchmark_contract_version}, 1,
    'report records Process benchmark contract');
is(scalar @{ $report->{summary} }, 2,
    'report contains every Process concurrency');

done_testing;
