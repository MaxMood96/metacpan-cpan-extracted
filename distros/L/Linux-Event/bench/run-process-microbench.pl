#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use JSON::PP;
use Scalar::Util qw(refaddr);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

use Linux::Event;
use Linux::Event::Loop;
use Linux::Event::Kernel::Process;

my $processes = 1_000;
my @concurrency = (1, 8, 32);
my $repeats = 5;
my $program = '/bin/true';
my $json_path;
my $help;

GetOptions(
    'processes=i'   => \$processes,
    'concurrency=s' => sub {
        @concurrency = map { 0 + $_ } split /,/, $_[1];
    },
    'repeats=i'     => \$repeats,
    'program=s'     => \$program,
    'json=s'        => \$json_path,
    'help'          => \$help,
) or usage(1);
usage(0) if $help;
die "processes must be positive\n" if $processes < 1;
die "concurrency values must be positive\n" if grep { $_ < 1 } @concurrency;
die "repeats must be positive\n" if $repeats < 1;
die "program must be executable\n" if !-x $program;

{
    package BenchProcess;
    use parent 'Linux::Event::Kernel::Process';

    sub on_exit ($process) {
        my $run = $process->data;
        die "benchmark child did not exit successfully\n"
            if !defined($process->exit_code) || $process->exit_code != 0;
        delete $run->{active}{ Scalar::Util::refaddr($process) };
        $run->{completed}++;
        if ($run->{completed} == $run->{processes}) {
            $run->{finished} = main::now();
            $run->{loop}->stop;
        } else {
            main::launch_available($run);
        }
    }

    sub on_error ($process, $error) { die "$error\n" }
}

sub now () { clock_gettime(CLOCK_MONOTONIC) }

sub median (@value) {
    @value = sort { $a <=> $b } @value;
    my $middle = int(@value / 2);
    return @value % 2
        ? $value[$middle]
        : ($value[$middle - 1] + $value[$middle]) / 2;
}

sub launch_available ($run) {
    while ($run->{launched} < $run->{processes}
        && keys(%{ $run->{active} }) < $run->{concurrency}) {
        my $process = BenchProcess->spawn(
            command => [$run->{program}], # required
            stdin   => 'null',            # optional
            stdout  => 'null',            # optional
            stderr  => 'null',            # optional
            data    => $run,              # optional
        );
        $run->{active}{ refaddr($process) } = $process;
        $run->{launched}++;
        $run->{loop}->add($process);
    }
    return;
}

my @raw;
for my $concurrency (@concurrency) {
    for my $repeat (1 .. $repeats) {
        my $loop = Linux::Event::Loop->new;
        my $run = {
            loop => $loop,
            program => $program,
            processes => $processes,
            concurrency => $concurrency,
            launched => 0,
            completed => 0,
            active => {},
        };
        my ($user_start, $system_start) = (times)[0, 1];
        $run->{started} = now();
        launch_available($run);
        $loop->run;
        my ($user_end, $system_end) = (times)[0, 1];
        my $elapsed = $run->{finished} - $run->{started};
        my $cpu = ($user_end - $user_start) + ($system_end - $system_start);
        die "Process benchmark completed $run->{completed} of $processes children\n"
            if $run->{completed} != $processes;
        push @raw, {
            concurrency => $concurrency,
            repeat => $repeat,
            processes => $processes,
            elapsed_seconds => 0 + $elapsed,
            processes_per_second => $processes / $elapsed,
            parent_cpu_us_per_process => $cpu * 1_000_000 / $processes,
        };
    }
}

my @summary;
for my $concurrency (@concurrency) {
    my @row = grep { $_->{concurrency} == $concurrency } @raw;
    push @summary, {
        concurrency => $concurrency,
        median_processes_per_second => median(
            map { $_->{processes_per_second} } @row,
        ),
        median_parent_cpu_us_per_process => median(
            map { $_->{parent_cpu_us_per_process} } @row,
        ),
    };
}

printf "Process pidfd spawn benchmark: processes=%d repeats=%d program=%s\n",
    $processes, $repeats, $program;
printf "%11s %18s %22s\n",
    'concurrency', 'processes/s', 'parent cpu us/process';
for my $row (@summary) {
    printf "%11d %18.1f %22.3f\n",
        $row->{concurrency},
        $row->{median_processes_per_second},
        $row->{median_parent_cpu_us_per_process};
}

if (defined $json_path) {
    my $report = {
        benchmark => 'linux-event-process-microbench',
        benchmark_contract_version => 1,
        linux_event_version => $Linux::Event::VERSION,
        workload => 'posix_spawnp plus pidfd exit notification',
        configuration => {
            processes => $processes,
            concurrency => \@concurrency,
            repeats => $repeats,
            program => $program,
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
Usage: run-process-microbench.pl [options]
  --processes=N        children per repeat (default: 1000)
  --concurrency=LIST   maximum live children (default: 1,8,32)
  --repeats=N          measured repeats (default: 5)
  --program=PATH       no-argument executable (default: /bin/true)
  --json=PATH          write a machine-readable report
  --help               show this help
USAGE
    exit $exit;
}
