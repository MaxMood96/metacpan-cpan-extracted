use v5.36;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use IPC::Open3 qw(open3);
use JSON::PP qw(decode_json);
use Symbol qw(gensym);

my $dir = tempdir(CLEANUP => 1);
my $json = "$dir/callback-batching-fairness.json";
my $script = "$Bin/../bench/run-callback-batching-fairness.pl";
my @cmd = (
    $^X, '-Mblib', $script,
    '--duration=0.1', '--ping-interval-us=5000',
    '--bytes=16', '--read-size=64', '--batch-sizes=0,4',
    '--transports=unix', '--warmup=0', '--repeats=1',
    "--json=$json",
);

my $err = gensym;
my $pid = open3(my $in, my $out, $err, @cmd);
close $in;
my $stdout = do { local $/; <$out> // '' };
my $stderr = do { local $/; <$err> // '' };
waitpid($pid, 0);

is($?, 0, 'callback-batching fairness benchmark exits successfully')
    or diag $stdout . $stderr;
like($stdout, qr/unix batch=0/, 'ordinary fairness row ran');
like($stdout, qr/unix batch=4/, 'batched fairness row ran');

open my $fh, '<', $json or die "open fairness JSON: $!";
my $report = decode_json(do { local $/; <$fh> });
close $fh;
is($report->{benchmark}, 'linux-event-callback-batching-fairness',
    'report identifies fairness contract');
is(scalar @{ $report->{raw} }, 2, 'report includes both fairness cases');
ok(!grep({ $_->{ping_count} < 1 } @{ $report->{raw} }),
    'each fairness case receives latency probes');

done_testing;
