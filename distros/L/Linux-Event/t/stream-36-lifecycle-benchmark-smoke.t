use v5.36;
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use IPC::Open3 qw(open3);
use Symbol qw(gensym);

my $script = "$Bin/../bench/run-stream-lifecycle-bench.pl";
my @cmd = (
    $^X,
    "-I$Bin/../blib/lib",
    "-I$Bin/../blib/arch",
    $script,
    '--api-style=loop-add',
    '--iterations=20',
    '--pool=2',
    '--live=8',
    '--warmup=2',
    '--repeats=1',
    '--memory-repeats=1',
    '--cases=registration,raw-named,framed-minimal,framed-full-named',
);

my $err = gensym;
my $pid = open3(my $in, my $out, $err, @cmd);
close $in;

my $stdout = do { local $/; <$out> // '' };
my $stderr = do { local $/; <$err> // '' };
waitpid($pid, 0);

my $status = $?;
my $output = $stdout . $stderr;

is($status, 0, 'Stream lifecycle benchmark smoke exits successfully')
    or diag $output;
like($output, qr/registration repeat=1 .* ops\/s/,
    'registration lifecycle row ran');
like($output, qr/contract=2 api_style=loop-add/,
    'benchmark contract and API adapter are identified');
like($output, qr/raw-named repeat=1 .* ops\/s/, 'raw Stream lifecycle row ran');
like($output, qr/framed-full-named repeat=1 .* ops\/s/,
    'named framed Stream lifecycle row ran');
like($output, qr/Median lifecycle construction summary/,
    'lifecycle summary was printed');
like($output, qr/Median live retained-memory summary/,
    'retained-memory summary was printed');

done_testing;
