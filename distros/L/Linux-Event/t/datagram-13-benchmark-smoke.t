use v5.36;
use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use JSON::PP qw(decode_json);
use Test::More;

my $script = File::Spec->catfile(
    $Bin, '..', 'bench', 'run-datagram-microbench.pl',
);
my $json = File::Spec->catfile(tempdir(CLEANUP => 1), 'datagram.json');

is(system(
    $^X, '-Mblib', $script,
    '--packets=20', '--bytes=8', '--repeats=1', "--json=$json",
), 0, 'Datagram microbenchmark smoke run succeeds');
ok(-s $json, 'Datagram benchmark writes JSON');

open my $fh, '<', $json or die "open $json: $!";
local $/;
my $report = decode_json(<$fh>);
close $fh;

is($report->{benchmark}, 'linux-event-datagram-microbench',
    'report identifies Datagram benchmark');
is($report->{benchmark_contract_version}, 1,
    'report records Datagram benchmark contract');
is(scalar @{ $report->{summary} }, 2,
    'report contains connected and unconnected modes');

done_testing;
