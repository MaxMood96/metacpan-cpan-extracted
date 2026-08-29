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

my $status = system(
    $^X, $script,
    '--counts=1',
    '--repeats=1',
    '--cpu-clock=times',
    "--json=$json",
);
is($status, 0, 'Timer microbenchmark smoke run succeeds');
my $has_json = ok(-s $json, 'Timer benchmark writes JSON');

SKIP: {
    skip 'benchmark did not produce a report', 6 if !$has_json;

    open my $fh, '<', $json or die "open $json: $!";
    local $/;
    my $report = decode_json(<$fh>);
    close $fh;

    is($report->{benchmark}, 'linux-event-timer-microbench',
        'report identifies Timer benchmark');
    is($report->{benchmark_contract_version}, 2,
        'report records benchmark contract');
    is($report->{configuration}{cpu_clock}, 'times',
        'report records requested CPU clock policy');
    is(scalar @{ $report->{summary} }, 3,
        'report contains every Timer mode');
    ok(!(grep {
        $_->{cpu_clock} ne 'times' && $_->{cpu_clock} ne 'unavailable'
    } @{ $report->{records} }), 'records identify the effective CPU clock');
    ok(!(grep {
        ($_->{cpu_clock} eq 'unavailable') != !defined($_->{cpu_seconds})
    } @{ $report->{records} }),
        'unavailable CPU clocks produce explicit null measurements');
}

done_testing;
