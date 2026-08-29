use v5.36;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use JSON::PP qw(decode_json);

my $dir = tempdir(CLEANUP => 1);
my $json = "$dir/watcher-state.json";
my @cases = qw(
    watcher-read-toggle
    xsstate-pause-toggle
    stream-pause-resume
    raw-register-cancel
    stream-attach-detach
    stream-half-close
    stream-close
    queued-write-drain
    tls-handshake
    tls-shutdown
);
my @command = (
    $^X,
    "-I$Bin/../blib/lib",
    "-I$Bin/../blib/arch",
    "$Bin/../bench/run-stream-watcher-state-bench.pl",
    '--operations=4',
    '--pool=2',
    '--warmup=1',
    '--repeats=1',
    '--tls-pairs=1',
    '--cases=' . join(',', @cases),
    '--json', $json,
);

open my $run, '-|', @command or die "run watcher-state benchmark: $!";
my $output = do { local $/; <$run> // '' };
my $ok = close $run;
ok($ok, 'watcher-state benchmark smoke run exits successfully')
    or diag $output;
like($output, qr/contract=1 cases=watcher-read-toggle,.*tls-shutdown/,
    'watcher-state benchmark reports contract and cases');
like($output, qr/Median watcher-state summary/,
    'watcher-state benchmark prints summary');

open my $in, '<', $json or die "open $json: $!";
my $report = decode_json(do { local $/; <$in> });
close $in;
is($report->{benchmark}, 'linux-event-stream-watcher-state',
    'watcher-state JSON identifies benchmark');
is($report->{benchmark_contract_version}, 1,
    'watcher-state JSON carries contract version');
is(scalar @{ $report->{summary} }, scalar(@cases),
    'watcher-state JSON summarizes every selected case');

my %summary = map { $_->{case} => $_ } @{ $report->{summary} };
is($summary{'watcher-read-toggle'}{epoll_ctl_mod_calls_per_operation}, 2,
    'raw watcher toggle performs two MOD calls per cycle');
is($summary{'xsstate-pause-toggle'}{epoll_ctl_mod_calls_per_operation}, 0,
    'XSState-only toggle performs no MOD calls');
is($summary{'stream-pause-resume'}{epoll_ctl_mod_calls_per_operation}, 2,
    'public pause/resume performs two MOD calls per cycle');
for my $case (qw(raw-register-cancel stream-attach-detach)) {
    is($summary{$case}{epoll_ctl_add_calls_per_operation}, 1,
        "$case performs one ADD per lifecycle");
    is($summary{$case}{epoll_ctl_mod_calls_per_operation}, 1,
        "$case performs one initial MOD per lifecycle");
    is($summary{$case}{epoll_ctl_del_calls_per_operation}, 1,
        "$case performs one DEL per lifecycle");
}
is($summary{'stream-close'}{epoll_ctl_del_calls_per_operation}, 1,
    'Stream close performs one DEL per object');
is($summary{'queued-write-drain'}{epoll_ctl_mod_calls_per_operation}, 2,
    'forced queue/drain performs two MOD calls per cycle');
my ($queue_record) = grep { $_->{case} eq 'queued-write-drain' }
    @{ $report->{records} };
cmp_ok($queue_record->{stream_stats_per_operation}{write_eagain_count}, '>=', 1,
    'forced queue/drain reaches native write EAGAIN');

done_testing;
