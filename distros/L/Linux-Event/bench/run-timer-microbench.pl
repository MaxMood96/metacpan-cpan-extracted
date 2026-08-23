#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use File::Basename qw(dirname);
use File::Path qw(make_path);
use FindBin qw($Bin);
use Getopt::Long qw(GetOptions);
use JSON::PP qw();
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC CLOCK_PROCESS_CPUTIME_ID);

use lib "$Bin/../blib/lib", "$Bin/../blib/arch", "$Bin/../lib";

use Linux::Event;
use Linux::Event::Loop;
use Linux::Event::Timer;

{
    package Linux::Event::Bench::Timer;
    use parent 'Linux::Event::Timer';
    sub on_timer ($timer) {
        my $state = $timer->data;
        $state->{completed}++;
        $state->{loop}->stop
            if $state->{completed} == $state->{target};
    }
}

my @counts = (1_000, 10_000, 100_000);
my $repeats = 5;
my $json_path = 'bench/results/timer-microbench.json';
my $help = 0;

GetOptions(
    'counts=s' => sub { @counts = split /,/, $_[1] },
    'repeats=i' => \$repeats,
    'json=s' => \$json_path,
    'help' => \$help,
) or usage(2);
usage(0) if $help;
die "counts must be positive integers\n"
    if !@counts || grep { !/\A[1-9]\d*\z/ } @counts;
die "repeats must be positive\n" if $repeats < 1;

my @modes = qw(lifecycle reschedule expiration);
my @records;
say "Linux::Event Timer microbenchmark version=$Linux::Event::VERSION";
say 'counts=' . join(',', @counts) . " repeats=$repeats";

for my $count (@counts) {
    warmup($count < 1_000 ? $count : 1_000);
    for my $repeat (1 .. $repeats) {
        my $offset = ($repeat - 1) % @modes;
        my @order = (@modes[$offset .. $#modes], @modes[0 .. $offset - 1]);
        for my $mode (@order) {
            my $row = run_mode($mode, $count);
            $row->{mode} = $mode;
            $row->{count} = 0 + $count;
            $row->{repeat} = $repeat;
            push @records, $row;
            printf "%-12s timers=%7d repeat=%d %12.1f/s %9.3f cpu us/op\n",
                $mode, $count, $repeat,
                $row->{operations_per_second},
                $row->{cpu_us_per_operation};
        }
    }
}

my @summary;
for my $count (@counts) {
    for my $mode (@modes) {
        my @set = grep {
            $_->{count} == $count && $_->{mode} eq $mode
        } @records;
        push @summary, {
            mode => $mode,
            count => 0 + $count,
            operations_per_second => median(
                map { $_->{operations_per_second} } @set
            ),
            cpu_us_per_operation => median(
                map { $_->{cpu_us_per_operation} } @set
            ),
        };
    }
}

say "\nMedian summary";
printf "%-12s %9s %14s %14s\n", 'mode', 'timers', 'operations/s', 'cpu us/op';
for my $row (@summary) {
    printf "%-12s %9d %14.1f %14.3f\n",
        $row->{mode}, $row->{count},
        $row->{operations_per_second}, $row->{cpu_us_per_operation};
}

my $report = {
    benchmark => 'linux-event-timer-microbench',
    benchmark_contract_version => 1,
    linux_event_version => "$Linux::Event::VERSION",
    configuration => {
        counts => [map { 0 + $_ } @counts],
        repeats => $repeats,
        modes => \@modes,
    },
    records => \@records,
    summary => \@summary,
};
write_json($json_path, $report);
say "\nWrote $json_path";

sub warmup ($count) {
    timer_lifecycle($count);
    timer_reschedule($count);
    timer_expiration($count);
    return;
}

sub run_mode ($mode, $count) {
    return timer_lifecycle($count) if $mode eq 'lifecycle';
    return timer_reschedule($count) if $mode eq 'reschedule';
    return timer_expiration($count);
}

sub timer_lifecycle ($count) {
    my $loop = Linux::Event::Loop->new;
    my ($wall, $cpu) = timed(sub {
        for (1 .. $count) {
            my $timer = $loop->add(
                Linux::Event::Bench::Timer->new(after => 3_600)
            );
            $timer->cancel;
        }
    });
    return measurement($count, $wall, $cpu);
}

sub timer_reschedule ($count) {
    my $loop = Linux::Event::Loop->new;
    my @timers = map {
        $loop->add(Linux::Event::Bench::Timer->new(after => 3_600))
    } 1 .. $count;
    my $at = 0;
    my ($wall, $cpu) = timed(sub {
        for my $timer (@timers) {
            $timer->reschedule(after => 3_600 + (++$at % 100) / 1_000);
        }
    });
    $_->cancel for @timers;
    return measurement($count, $wall, $cpu);
}

sub timer_expiration ($count) {
    my $loop = Linux::Event::Loop->new;
    my $state = { loop => $loop, completed => 0, target => $count };
    for (1 .. $count) {
        $loop->add(Linux::Event::Bench::Timer->new(
            after => 0,
            data => $state,
        ));
    }
    my ($wall, $cpu) = timed(sub { $loop->run });
    die "expiration completed $state->{completed} of $count Timers\n"
        if $state->{completed} != $count;
    return measurement($count, $wall, $cpu);
}

sub timed ($code) {
    my $wall_start = clock_gettime(CLOCK_MONOTONIC);
    my $cpu_start = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
    $code->();
    my $cpu = clock_gettime(CLOCK_PROCESS_CPUTIME_ID) - $cpu_start;
    my $wall = clock_gettime(CLOCK_MONOTONIC) - $wall_start;
    return ($wall, $cpu);
}

sub measurement ($operations, $wall, $cpu) {
    die "benchmark clock returned a non-positive duration\n"
        if $wall <= 0 || $cpu <= 0;
    return {
        operations => $operations,
        elapsed_seconds => $wall,
        cpu_seconds => $cpu,
        operations_per_second => $operations / $wall,
        cpu_us_per_operation => $cpu * 1_000_000 / $operations,
    };
}

sub median (@values) {
    @values = sort { $a <=> $b } @values;
    my $middle = int(@values / 2);
    return @values % 2
        ? $values[$middle]
        : ($values[$middle - 1] + $values[$middle]) / 2;
}

sub write_json ($path, $document) {
    my $directory = dirname($path);
    make_path($directory) if $directory ne '.' && !-d $directory;
    open my $fh, '>', $path or die "open $path: $!\n";
    print {$fh} JSON::PP->new->canonical->pretty->encode($document);
    close $fh or die "close $path: $!\n";
    return;
}

sub usage ($status) {
    print <<'USAGE';
Usage:
  perl -Mblib bench/run-timer-microbench.pl [options]

Options:
  --counts LIST   comma-separated Timer counts (default 1000,10000,100000)
  --repeats N     repeats per mode and count (default 5)
  --json PATH     JSON output path
USAGE
    exit $status;
}
