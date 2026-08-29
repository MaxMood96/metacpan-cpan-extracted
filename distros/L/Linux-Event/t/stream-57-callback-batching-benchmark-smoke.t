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
my $json = "$dir/callback-batching.json";
my $script = "$Bin/../bench/run-callback-batching-microbench.pl";
my @cmd = (
    $^X, '-Mblib', $script,
    '--messages=1000', '--bytes=16', '--read-size=64',
    '--raw-batch-bytes=0,256', '--message-batch-sizes=0,4',
    '--transports=unix', '--warmup=0', '--repeats=1',
    "--json=$json",
);

my $err = gensym;
my $pid = open3(my $in, my $out, $err, @cmd);
close $in;
my $stdout = do { local $/; <$out> // '' };
my $stderr = do { local $/; <$err> // '' };
waitpid($pid, 0);

is($?, 0, 'callback-batching benchmark exits successfully')
    or diag $stdout . $stderr;
like($stdout, qr/unix\/raw batch=0/, 'ordinary raw row ran');
like($stdout, qr/unix\/raw batch=256/, 'coalesced raw row ran');
like($stdout, qr/unix\/framed batch=0/, 'ordinary framed row ran');
like($stdout, qr/unix\/framed batch=4/, 'batched framed row ran');

open my $fh, '<', $json or die "open benchmark JSON: $!";
my $report = decode_json(do { local $/; <$fh> });
close $fh;
is($report->{benchmark}, 'linux-event-callback-batching-microbench',
    'report identifies benchmark contract');
is(scalar @{ $report->{raw} }, 4, 'report includes every measured case');
is(scalar @{ $report->{summary} }, 4, 'report summarizes every case');

my ($ordinary) = grep {
    $_->{mode} eq 'framed' && $_->{batch} == 0
} @{ $report->{summary} };
my ($batched) = grep {
    $_->{mode} eq 'framed' && $_->{batch} == 4
} @{ $report->{summary} };
is($ordinary->{median_callback_calls}, 1000,
    'ordinary row invokes one callback per message');
is($batched->{median_callback_calls}, 250,
    'batch-four row invokes one callback per four messages');

done_testing;
