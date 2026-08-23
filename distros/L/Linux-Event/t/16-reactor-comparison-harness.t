use v5.36;
use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use JSON::PP qw(decode_json);
use FindBin qw($Bin);

my $root = "$Bin/..";
my $tmp = tempdir(CLEANUP => 1);
my $json = "$tmp/result.json";
my $html = "$tmp/result.html";

my @cmd = (
    $^X, "$root/bench/run-reactor-comparison.pl",
    '--systems', 'linuxevent',
    '--clients', '20',
    '--warmup', '1',
    '--messages', '2',
    '--bytes', '64',
    '--client-workers', '2',
    '--repeats', '1',
    '--timeout', '10',
    '--json', $json,
    '--out', $html,
);

is(system(@cmd), 0, 'strict same-work harness completes');
ok(-s $json, 'JSON result written');
ok(-s $html, 'HTML result written');

open my $fh, '<', $json or die "open $json: $!";
local $/;
my $data = decode_json(<$fh>);
close $fh;

my $fair = $data->{fairness_contract};
ok($fair->{preconnected}, 'preconnected contract recorded');
ok($fair->{accept_outside_timing}, 'accept is outside timing');
ok($fair->{warmup_outside_timing}, 'warmup is outside timing');
ok($fair->{teardown_outside_timing}, 'teardown is outside timing');
ok($fair->{framework_timer_outside_timing}, 'no framework timeout watcher in measurement');

my $r = $data->{results}[0];
ok($r->{ok}, 'Linux::Event smoke result rankable');
is($r->{messages}, 40, 'measured message count exact');
is($r->{bytes_read}, 40 * 64, 'measured bytes read exact');
is($r->{bytes_written}, 40 * 64, 'measured bytes written exact');
is($r->{unexpected_closes}, 0, 'no teardown/EOF in timed phase');
is($r->{write_eagain}, 0, 'no dropped write from EAGAIN in smoke');
is($r->{partial_writes}, 0, 'no partial write in smoke');
is($r->{shared_perl_echo_body}, 1, 'shared Perl echo body recorded');

done_testing;
