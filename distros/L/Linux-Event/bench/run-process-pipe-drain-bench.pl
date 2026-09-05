#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use JSON::PP;
use Time::HiRes qw(
    clock_gettime CLOCK_MONOTONIC CLOCK_PROCESS_CPUTIME_ID
);

use Linux::Event;
use Linux::Event::Loop;
use Linux::Event::Kernel::Process;
use Linux::Event::Kernel::Timer;

my @engines = qw(perl native);
my @streams = qw(stdout stderr both);
my @workers = (1, 8, 32);
my @read_sizes = (4_096, 65_536);
my $bytes_per_stream = 16 * 1024 * 1024;
my $max_reads_per_tick = 64;
my $heartbeat_us = 0;
my $warmups = 1;
my $repeats = 7;
my $json_path;
my $help;

GetOptions(
    'engines=s' => sub { @engines = split /,/, $_[1] },
    'streams=s' => sub { @streams = split /,/, $_[1] },
    'workers=s' => sub { @workers = map { 0 + $_ } split /,/, $_[1] },
    'read-sizes=s' => sub {
        @read_sizes = map { 0 + $_ } split /,/, $_[1];
    },
    'bytes-per-stream=i' => \$bytes_per_stream,
    'max-reads-per-tick=i' => \$max_reads_per_tick,
    'heartbeat-us=i' => \$heartbeat_us,
    'warmups=i' => \$warmups,
    'repeats=i' => \$repeats,
    'json=s' => \$json_path,
    'help' => \$help,
) or usage(1);
usage(0) if $help;

my %valid_engine = map { $_ => 1 } qw(perl native);
my %valid_stream = map { $_ => 1 } qw(stdout stderr both);
die "engines must contain perl and/or native\n"
    if !@engines || grep { !$valid_engine{$_} } @engines;
die "streams must contain stdout, stderr, and/or both\n"
    if !@streams || grep { !$valid_stream{$_} } @streams;
die "workers must be positive\n" if !@workers || grep { $_ < 1 } @workers;
die "read sizes must be positive\n"
    if !@read_sizes || grep { $_ < 1 } @read_sizes;
die "bytes-per-stream must be positive\n" if $bytes_per_stream < 1;
die "max-reads-per-tick must be positive\n" if $max_reads_per_tick < 1;
die "heartbeat-us must be nonnegative\n" if $heartbeat_us < 0;
die "warmups must be nonnegative\n" if $warmups < 0;
die "repeats must be positive\n" if $repeats < 1;

my $CHILD = <<'CHILD';
use v5.36;
use strict;
use warnings;
my ($bytes, $mode) = @ARGV;
my $gate = '';
exit 91 if sysread(STDIN, $gate, 1) != 1;
my $chunk = 'x' x 65_536;
my ($stdout_left, $stderr_left) = (
    $mode eq 'stderr' ? 0 : $bytes,
    $mode eq 'stdout' ? 0 : $bytes,
);
while ($stdout_left || $stderr_left) {
    if ($stdout_left) {
        my $length = $stdout_left < length($chunk)
            ? $stdout_left : length($chunk);
        my $offset = 0;
        while ($offset < $length) {
            my $count = syswrite(STDOUT, $chunk, $length - $offset, $offset);
            exit 92 if !defined $count;
            $offset += $count;
        }
        $stdout_left -= $length;
    }
    if ($stderr_left) {
        my $length = $stderr_left < length($chunk)
            ? $stderr_left : length($chunk);
        my $offset = 0;
        while ($offset < $length) {
            my $count = syswrite(STDERR, $chunk, $length - $offset, $offset);
            exit 93 if !defined $count;
            $offset += $count;
        }
        $stderr_left -= $length;
    }
}

CHILD

{
    package BenchPipeHeartbeat;
    use parent 'Linux::Event::Kernel::Timer';

    sub on_timer ($timer) {
        my $run = $timer->data;
        my $now = main::now();
        my $gap = $now - $run->{heartbeat_last};
        $run->{heartbeat_max_gap} = $gap
            if $gap > $run->{heartbeat_max_gap};
        $run->{heartbeat_last} = $now;
        $run->{heartbeat_callbacks}++;
        $run->{heartbeat_expirations} += $timer->expirations;
    }
}

{
    package BenchPipeProcess;
    use parent 'Linux::Event::Kernel::Process';

    sub on_stdout ($process, $bytes) {
        my $run = $process->data;
        $run->{stdout_bytes} += length($bytes);
        $run->{stdout_callbacks}++;
    }

    sub on_stderr ($process, $bytes) {
        my $run = $process->data;
        $run->{stderr_bytes} += length($bytes);
        $run->{stderr_callbacks}++;
    }

    sub on_stdout_eof ($process) { $process->data->{stdout_eof}++ }
    sub on_stderr_eof ($process) { $process->data->{stderr_eof}++ }

    sub on_exit ($process) {
        my $run = $process->data;
        die "pipe benchmark child did not exit successfully\n"
            if !defined($process->exit_code) || $process->exit_code != 0;
        $run->{completed}++;
        if ($run->{completed} == $run->{workers}) {
            $run->{finished} = main::now();
            $run->{loop}->stop;
        }
    }

    sub on_error ($process, $error) { die "$error\n" }
}

sub now () { clock_gettime(CLOCK_MONOTONIC) }
sub cpu_now () { clock_gettime(CLOCK_PROCESS_CPUTIME_ID) }

sub median (@values) {
    @values = sort { $a <=> $b } @values;
    my $middle = int(@values / 2);
    return @values % 2
        ? $values[$middle]
        : ($values[$middle - 1] + $values[$middle]) / 2;
}

sub run_once ($engine, $stream, $workers, $read_size, $measured) {
    local $Linux::Event::Kernel::Process::_PIPE_DRAIN_ENGINE = $engine;
    my $loop = Linux::Event::Loop->new;
    my $run = {
        loop => $loop,
        workers => $workers,
        completed => 0,
        stdout_bytes => 0,
        stderr_bytes => 0,
        stdout_callbacks => 0,
        stderr_callbacks => 0,
        stdout_eof => 0,
        stderr_eof => 0,
        heartbeat_callbacks => 0,
        heartbeat_expirations => 0,
        heartbeat_max_gap => 0,
    };
    my @processes;
    for (1 .. $workers) {
        push @processes, $loop->add(BenchPipeProcess->spawn(
            command => [$^X, '-e', $CHILD, $bytes_per_stream, $stream],
            stdin => 'pipe',
            stdout => 'pipe',
            stderr => 'pipe',
            read_size => $read_size,
            max_reads_per_tick => $max_reads_per_tick,
            data => $run,
        ));
    }

    if ($heartbeat_us) {
        my $interval = $heartbeat_us / 1_000_000;
        $run->{heartbeat_last} = now();
        $loop->add(BenchPipeHeartbeat->new(
            every => $interval, data => $run,
        ));
    }

    my $cpu_start = cpu_now();
    $run->{started} = now();
    for my $process (@processes) {
        $process->write_stdin('x');
        $process->close_stdin;
    }
    $loop->run;
    my $cpu_end = cpu_now();
    my $elapsed = $run->{finished} - $run->{started};
    my $cpu = $cpu_end - $cpu_start;
    my $expected_stdout = $stream eq 'stderr'
        ? 0 : $bytes_per_stream * $workers;
    my $expected_stderr = $stream eq 'stdout'
        ? 0 : $bytes_per_stream * $workers;
    die "stdout mismatch: got $run->{stdout_bytes}, expected $expected_stdout\n"
        if $run->{stdout_bytes} != $expected_stdout;
    die "stderr mismatch: got $run->{stderr_bytes}, expected $expected_stderr\n"
        if $run->{stderr_bytes} != $expected_stderr;
    die "stdout EOF mismatch\n" if $run->{stdout_eof} != $workers;
    die "stderr EOF mismatch\n" if $run->{stderr_eof} != $workers;

    my $bytes = $expected_stdout + $expected_stderr;
    return {
        engine => $engine,
        stream => $stream,
        workers => $workers,
        read_size => $read_size,
        measured => $measured ? JSON::PP::true : JSON::PP::false,
        bytes => $bytes,
        elapsed_seconds => 0 + $elapsed,
        gib_per_second => $bytes / $elapsed / (1024 ** 3),
        parent_cpu_seconds => 0 + $cpu,
        parent_cpu_ns_per_kib => $cpu * 1_000_000_000 / ($bytes / 1024),
        stdout_callbacks => $run->{stdout_callbacks},
        stderr_callbacks => $run->{stderr_callbacks},
        callback_bytes => $run->{stdout_callbacks} + $run->{stderr_callbacks}
            ? $bytes / ($run->{stdout_callbacks} + $run->{stderr_callbacks})
            : 0,
        heartbeat_callbacks => $run->{heartbeat_callbacks},
        heartbeat_expirations => $run->{heartbeat_expirations},
        heartbeat_max_gap_seconds => $run->{heartbeat_max_gap},
    };
}

my @raw;
for my $read_size (@read_sizes) {
    for my $stream (@streams) {
        for my $workers (@workers) {
            for my $warmup (1 .. $warmups) {
                run_once($_, $stream, $workers, $read_size, 0) for @engines;
            }
            for my $repeat (1 .. $repeats) {
                my @order = @engines;
                push @order, shift @order if @order > 1 && $repeat % 2 == 0;
                for my $engine (@order) {
                    my $row = run_once(
                        $engine, $stream, $workers, $read_size, 1,
                    );
                    $row->{repeat} = $repeat;
                    push @raw, $row;
                }
            }
        }
    }
}

my @summary;
for my $read_size (@read_sizes) {
    for my $stream (@streams) {
        for my $workers (@workers) {
            for my $engine (@engines) {
                my @rows = grep {
                    $_->{engine} eq $engine
                        && $_->{stream} eq $stream
                        && $_->{workers} == $workers
                        && $_->{read_size} == $read_size
                } @raw;
                push @summary, {
                    engine => $engine,
                    stream => $stream,
                    workers => $workers,
                    read_size => $read_size,
                    median_gib_per_second => median(
                        map { $_->{gib_per_second} } @rows,
                    ),
                    median_parent_cpu_ns_per_kib => median(
                        map { $_->{parent_cpu_ns_per_kib} } @rows,
                    ),
                    median_callback_bytes => median(
                        map { $_->{callback_bytes} } @rows,
                    ),
                    median_heartbeat_max_gap_seconds => median(
                        map { $_->{heartbeat_max_gap_seconds} } @rows,
                    ),
                };
            }
        }
    }
}

printf "Process pipe drain benchmark: bytes/stream=%d max_reads/tick=%d repeats=%d\n",
    $bytes_per_stream, $max_reads_per_tick, $repeats;
printf "%8s %7s %7s %10s %12s %17s %15s\n",
    qw(engine stream workers read_size GiB/s cpu_ns/KiB callback_bytes);
for my $row (@summary) {
    printf "%8s %7s %7d %10d %12.3f %17.3f %15.1f\n",
        $row->{engine}, $row->{stream}, $row->{workers}, $row->{read_size},
        $row->{median_gib_per_second},
        $row->{median_parent_cpu_ns_per_kib},
        $row->{median_callback_bytes};
}

if (defined $json_path) {
    my $report = {
        benchmark => 'linux-event-process-pipe-drain-bench',
        benchmark_contract_version => 1,
        linux_event_version => $Linux::Event::VERSION,
        workload => 'pre-spawned gated child pipe output and Process callbacks',
        configuration => {
            engines => \@engines,
            streams => \@streams,
            workers => \@workers,
            read_sizes => \@read_sizes,
            bytes_per_stream => $bytes_per_stream,
            max_reads_per_tick => $max_reads_per_tick,
            heartbeat_us => $heartbeat_us,
            warmups => $warmups,
            repeats => $repeats,
        },
        raw => \@raw,
        summary => \@summary,
    };
    open my $json, '>', $json_path or die "open $json_path: $!\n";
    print {$json} JSON::PP->new->canonical->pretty->encode($report);
    close $json or die "close $json_path: $!\n";
}

sub usage ($exit) {
    print <<'USAGE';
Usage: run-process-pipe-drain-bench.pl [options]
  --engines=LIST           perl,native (default: both)
  --streams=LIST           stdout,stderr,both (default: all)
  --workers=LIST           simultaneous pre-spawned children (default: 1,8,32)
  --read-sizes=LIST        Process read sizes (default: 4096,65536)
  --bytes-per-stream=N     bytes written by each child per stream (default: 16777216)
  --max-reads-per-tick=N   Process fairness limit (default: 64)
  --heartbeat-us=N         recurring fairness probe interval (default: disabled)
  --warmups=N              warmup runs per case and engine (default: 1)
  --repeats=N              measured balanced repeats (default: 7)
  --json=PATH              write a machine-readable report
  --help                   show this help
USAGE
    exit $exit;
}
