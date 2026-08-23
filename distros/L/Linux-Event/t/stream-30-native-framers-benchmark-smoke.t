use v5.36;
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use IPC::Open3 qw(open3);
use Symbol qw(gensym);

my $script = "$Bin/../bench/run-native-framers-microbench.pl";
my @cmd = (
    $^X,
    $script,
    '--framers=fixed,length,u32be,netstring,varint,decimal',
    '--clients=1',
    '--warmup=1',
    '--messages=5',
    '--bytes=8',
    '--repeats=2',
);

my $err = gensym;
my $pid = open3(my $in, my $out, $err, @cmd);
close $in;

my $stdout = do { local $/; <$out> // '' };
my $stderr = do { local $/; <$err> // '' };
waitpid($pid, 0);

my $status = $?;
my $output = $stdout . $stderr;

is($status, 0, 'native-framers benchmark smoke exits successfully') or diag $output;
like($output, qr/fixed\/native\s+clients=1/, 'fixed native row ran');
like($output, qr/length\/native\s+clients=1/, 'length native row ran');
like($output, qr/u32be\/native\s+clients=1/, 'u32be native row ran');
like($output, qr/netstring\/native\s+clients=1/, 'netstring native row ran');
like($output, qr/varint\/native\s+clients=1/, 'varint native row ran');
like($output, qr/decimal\/native\s+clients=1/, 'decimal-length native row ran');

done_testing;
