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
my $pipe_json = File::Spec->catfile(
    tempdir(CLEANUP => 1), 'process-pipe.json',
);

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

my $pipe_script = File::Spec->catfile(
    $Bin, '..', 'bench', 'run-process-pipe-drain-bench.pl',
);
is(system(
    $^X, '-Mblib', $pipe_script,
    '--engines=perl,native', '--streams=both', '--workers=1',
    '--read-sizes=1024', '--bytes-per-stream=32768',
    '--warmups=0', '--repeats=1', "--json=$pipe_json",
), 0, 'Process pipe drain benchmark smoke run succeeds');
ok(-s $pipe_json, 'Process pipe drain benchmark writes JSON');

open my $pipe_fh, '<', $pipe_json or die "open $pipe_json: $!";
my $pipe_report = decode_json(do { local $/; <$pipe_fh> });
close $pipe_fh;

is($pipe_report->{benchmark}, 'linux-event-process-pipe-drain-bench',
    'pipe report identifies the benchmark');
is($pipe_report->{benchmark_contract_version}, 1,
    'pipe report records its benchmark contract');
is(scalar @{ $pipe_report->{summary} }, 2,
    'pipe report contains Perl reference and native engine rows');
is_deeply(
    [sort map { $_->{engine} } @{ $pipe_report->{summary} }],
    [qw(native perl)],
    'pipe report labels both comparison engines',
);

done_testing;
