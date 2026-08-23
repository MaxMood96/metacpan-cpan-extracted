#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use POSIX qw();
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

use Linux::Event::Loop;
use Linux::Event::Signal;

my $deliveries = 10_000;
my @subscribers = (1, 10, 100);
my $repeats = 5;
my $help;

GetOptions(
    'deliveries=i' => \$deliveries,
    'subscribers=s' => sub {
        @subscribers = map { 0 + $_ } split /,/, $_[1];
    },
    'repeats=i' => \$repeats,
    'help'      => \$help,
) or usage(1);
usage(0) if $help;
die "deliveries must be positive\n" if $deliveries < 1;
die "repeats must be positive\n" if $repeats < 1;
die "subscribers must be positive\n" if grep { $_ < 1 } @subscribers;

my $signal_number = POSIX::SIGRTMIN();

{
    package BenchSignal;
    use parent 'Linux::Event::Signal';

    sub on_signal ($signal, $number, $count) {
        my $run = $signal->data;
        $run->{callbacks}++;
        return if $run->{callbacks} % $run->{subscribers};
        $run->{delivered} += $count;
        if ($run->{delivered} >= $run->{deliveries}) {
            $run->{loop}->stop;
        }
        else {
            kill $run->{signal_number}, $$
                or die "benchmark kill failed: $!\n";
        }
    }
}

sub now () { clock_gettime(CLOCK_MONOTONIC) }

sub median (@values) {
    @values = sort { $a <=> $b } @values;
    my $middle = int(@values / 2);
    return @values % 2
        ? $values[$middle]
        : ($values[$middle - 1] + $values[$middle]) / 2;
}

printf "Signal signalfd microbenchmark: deliveries=%d repeats=%d signal=%d\n",
    $deliveries, $repeats, $signal_number;
printf "%11s %18s %18s %16s\n",
    'subscribers', 'signals/s', 'callbacks/s', 'cpu us/signal';

for my $subscriber_count (@subscribers) {
    my (@signal_rates, @callback_rates, @cpu_costs);
    for (1 .. $repeats) {
        my $loop = Linux::Event::Loop->new;
        my $run = {
            loop          => $loop,
            subscribers   => $subscriber_count,
            deliveries    => $deliveries,
            delivered     => 0,
            callbacks     => 0,
            signal_number => $signal_number,
        };
        my @signal = map {
            $loop->add(BenchSignal->new(
                signals => $signal_number, data => $run,
            ))
        } 1 .. $subscriber_count;
        my ($user_start, $system_start) = (times)[0, 1];
        my $started = now();
        kill $signal_number, $$ or die "benchmark kill failed: $!\n";
        $loop->run;
        my $elapsed = now() - $started;
        my ($user_end, $system_end) = (times)[0, 1];
        my $cpu = ($user_end - $user_start) + ($system_end - $system_start);
        $_->cancel for @signal;
        push @signal_rates, $deliveries / $elapsed;
        push @callback_rates, $run->{callbacks} / $elapsed;
        push @cpu_costs, $cpu * 1_000_000 / $deliveries;
    }
    printf "%11d %18.1f %18.1f %16.3f\n",
        $subscriber_count,
        median(@signal_rates),
        median(@callback_rates),
        median(@cpu_costs);
}

sub usage ($exit) {
    print <<'USAGE';
Usage: run-signal-microbench.pl [options]
  --deliveries=N       delivered signals per repeat (default: 10000)
  --subscribers=LIST   fan-out subscriber counts (default: 1,10,100)
  --repeats=N          measured repeats (default: 5)
  --help               show this help
USAGE
    exit $exit;
}
