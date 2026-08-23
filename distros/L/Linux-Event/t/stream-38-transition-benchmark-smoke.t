use v5.36;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use JSON::PP qw(decode_json);

my $dir = tempdir(CLEANUP => 1);
my $json = "$dir/transition.json";
my @command = (
    $^X,
    "-I$Bin/../blib/lib",
    "-I$Bin/../blib/arch",
    "$Bin/../bench/run-stream-transition-bench.pl",
    '--iterations=30',
    '--pool=4',
    '--warmup=6',
    '--repeats=1',
    '--json', $json,
);

open my $run, '-|', @command or die "run transition benchmark: $!";
my $output = do { local $/; <$run> // '' };
my $ok = close $run;
ok($ok, 'transition benchmark smoke run exits successfully');
like($output, qr/contract=1 cases=raw-raw,framed-framed,raw-framed/,
    'transition benchmark reports its contract and cases');
like($output, qr/Median protocol-transition summary/,
    'transition benchmark prints summary');

open my $in, '<', $json or die "open $json: $!";
my $report = decode_json(do { local $/; <$in> });
close $in;
is($report->{benchmark}, 'linux-event-stream-transition',
    'transition JSON identifies benchmark');
is($report->{benchmark_contract_version}, 1,
    'transition JSON carries contract version');
is(scalar @{ $report->{summary} }, 3,
    'transition JSON summarizes every default case');

done_testing;
