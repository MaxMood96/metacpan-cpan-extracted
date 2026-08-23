use v5.36;
use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use FindBin qw($Bin);

my $root = "$Bin/..";
my $tmp = tempdir(CLEANUP => 1);
my $json = "$tmp/result.json";
my $html = "$tmp/result.html";

my @cmd = (
    $^X, "$root/bench/run-reactor-comparison.pl",
    '--systems', 'linuxevent',
    '--clients', '4',
    '--warmup', '0',
    '--messages', '1',
    '--bytes', '64',
    '--client-workers', '1',
    '--repeats', '1',
    '--timeout', '10',
    '--json', $json,
    '--out', $html,
);

is(system(@cmd), 0, 'reactor report smoke run completes');
ok(-s $html, 'HTML report written');

open my $fh, '<', $html or die "open $html: $!";
local $/;
my $src = <$fh>;
close $fh;

like($src, qr/id="row-filter"/, 'text filter is present');
like($src, qr/id="system-filter"/, 'system filter is present');
like($src, qr/id="clients-filter"/, 'client-count filter is present');
like($src, qr/id="reset-filters"/, 'filter reset control is present');
like($src, qr/function sortTable\(/, 'sortable-table JavaScript is present');
like($src, qr/function applyFilters\(/, 'filter JavaScript is present');
like($src, qr/table class="sortable" data-filterable="1"/, 'generated result tables opt into sorting/filtering');
like($src, qr/data-system="Linux::Event XSLoop same-work Perl echo"/, 'rows carry system metadata for exact filtering');
like($src, qr/data-clients="4"/, 'rows carry client-count metadata for exact filtering');

done_testing;
