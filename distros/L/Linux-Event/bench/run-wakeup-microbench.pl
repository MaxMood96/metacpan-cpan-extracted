#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use JSON::PP;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

use Linux::Event;
use Linux::Event::Loop;
use Linux::Event::Wakeup;

my $signals = 100_000;
my @batch_sizes = (1, 16, 256);
my $repeats = 5;
my $json_path;
my $help;

GetOptions(
    'signals=i'     => \$signals,
    'batch-sizes=s' => sub {
        @batch_sizes = map { 0 + $_ } split /,/, $_[1];
    },
    'repeats=i'     => \$repeats,
    'json=s'        => \$json_path,
    'help'          => \$help,
) or usage(1);
usage(0) if $help;
die "signals must be positive\n" if $signals < 1;
die "repeats must be positive\n" if $repeats < 1;
die "batch sizes must be positive\n" if grep { $_ < 1 } @batch_sizes;

{
    package BenchWakeup;
    use parent 'Linux::Event::Wakeup';

    sub on_wakeup ($wakeup, $count) {
        my $run = $wakeup->data;
        $run->{delivered} += $count;
        $run->{callbacks}++;
        if ($run->{delivered} >= $run->{signals}) {
            $run->{loop}->stop;
        } else {
            main::issue_batch($wakeup, $run);
        }
    }
}

sub now () { clock_gettime(CLOCK_MONOTONIC) }

sub median (@value) {
    @value = sort { $a <=> $b } @value;
    my $middle = int(@value / 2);
    return @value % 2
        ? $value[$middle]
        : ($value[$middle - 1] + $value[$middle]) / 2;
}

sub issue_batch ($wakeup, $run) {
    my $remaining = $run->{signals} - $run->{issued};
    my $count = $remaining < $run->{batch_size}
        ? $remaining : $run->{batch_size};
    for (1 .. $count) {
        $wakeup->signal;
    }
    $run->{issued} += $count;
    return;
}

my @raw;
for my $batch_size (@batch_sizes) {
    for my $repeat (1 .. $repeats) {
        my $loop = Linux::Event::Loop->new;
        my $run = {
            loop       => $loop,
            signals    => $signals,
            batch_size => $batch_size,
            issued     => 0,
            delivered  => 0,
            callbacks  => 0,
        };
        my $wakeup = $loop->add(BenchWakeup->new(data => $run));
        my ($user_start, $system_start) = (times)[0, 1];
        my $started = now();
        issue_batch($wakeup, $run);
        $loop->run;
        my $elapsed = now() - $started;
        my ($user_end, $system_end) = (times)[0, 1];
        my $cpu = ($user_end - $user_start) + ($system_end - $system_start);
        $wakeup->cancel;
        die "Wakeup benchmark delivered $run->{delivered} of $signals signals\n"
            if $run->{delivered} != $signals;
        push @raw, {
            batch_size        => $batch_size,
            repeat            => $repeat,
            signals           => $signals,
            callbacks         => $run->{callbacks},
            elapsed_seconds   => 0 + $elapsed,
            signals_per_second => $signals / $elapsed,
            callbacks_per_second => $run->{callbacks} / $elapsed,
            cpu_us_per_signal => $cpu * 1_000_000 / $signals,
        };
    }
}

my @summary;
for my $batch_size (@batch_sizes) {
    my @row = grep { $_->{batch_size} == $batch_size } @raw;
    push @summary, {
        batch_size => $batch_size,
        median_signals_per_second => median(
            map { $_->{signals_per_second} } @row,
        ),
        median_callbacks_per_second => median(
            map { $_->{callbacks_per_second} } @row,
        ),
        median_cpu_us_per_signal => median(
            map { $_->{cpu_us_per_signal} } @row,
        ),
        median_callbacks => median(map { $_->{callbacks} } @row),
    };
}

printf "Wakeup eventfd microbenchmark: signals=%d repeats=%d\n",
    $signals, $repeats;
printf "%10s %18s %18s %16s %12s\n",
    'batch', 'signals/s', 'callbacks/s', 'cpu us/signal', 'callbacks';
for my $row (@summary) {
    printf "%10d %18.1f %18.1f %16.3f %12.0f\n",
        $row->{batch_size},
        $row->{median_signals_per_second},
        $row->{median_callbacks_per_second},
        $row->{median_cpu_us_per_signal},
        $row->{median_callbacks};
}

if (defined $json_path) {
    my $report = {
        benchmark => 'linux-event-wakeup-microbench',
        benchmark_contract_version => 1,
        linux_event_version => $Linux::Event::VERSION,
        configuration => {
            signals => $signals,
            batch_sizes => \@batch_sizes,
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
Usage: run-wakeup-microbench.pl [options]
  --signals=N          logical eventfd increments per repeat (default: 100000)
  --batch-sizes=LIST   increments issued per Loop turn (default: 1,16,256)
  --repeats=N          measured repeats (default: 5)
  --json=PATH          write a machine-readable report
  --help               show this help
USAGE
    exit $exit;
}
