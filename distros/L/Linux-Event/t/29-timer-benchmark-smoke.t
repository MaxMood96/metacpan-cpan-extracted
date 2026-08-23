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
    $root, 'bench', 'run-timer-microbench.pl',
);
my $temporary = tempdir(CLEANUP => 1);
my $json = File::Spec->catfile($temporary, 'timer.json');

is(system(
    $^X, $script,
    '--counts=10',
    '--repeats=1',
    "--json=$json",
), 0, 'Timer microbenchmark smoke run succeeds');
ok(-s $json, 'Timer benchmark writes JSON');

open my $fh, '<', $json or die "open $json: $!";
local $/;
my $report = decode_json(<$fh>);
close $fh;

is($report->{benchmark}, 'linux-event-timer-microbench',
    'report identifies Timer benchmark');
is($report->{benchmark_contract_version}, 1,
    'report records benchmark contract');
is(scalar @{ $report->{summary} }, 3,
    'report contains every Timer mode');

done_testing;
