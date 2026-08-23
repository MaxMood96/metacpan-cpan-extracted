#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

use Linux::Event::Loop;
use Linux::Event::Stream::_Resolver ();

my $requests = 1_000;
my $repeats = 5;
my $host = 'localhost';
my $service = 80;
my $help;

GetOptions(
    'requests=i' => \$requests,
    'repeats=i'  => \$repeats,
    'host=s'     => \$host,
    'service=i'  => \$service,
    'help'       => \$help,
) or usage(1);
usage(0) if $help;
die "requests must be positive\n" if $requests < 1;
die "repeats must be positive\n" if $repeats < 1;
die "service must be between 0 and 65535\n"
    if $service < 0 || $service > 65_535;

{
    package BenchResolverTarget;
    sub new ($class, $run) { bless { run => $run }, $class }
    sub _resolver_completed ($self, $result) {
        my $run = $self->{run};
        die "resolver benchmark failed: $result->{message}\n"
            if $result->{error_code};
        my $started = delete $run->{started}{ $result->{id} };
        push @{ $run->{latencies} }, main::now() - $started;
        $run->{completed}++;
        $run->{loop}->stop if $run->{completed} == $run->{requests};
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

my (@rates, @latencies);
for (1 .. $repeats) {
    my $loop = Linux::Event::Loop->new;
    my $resolver = Linux::Event::Stream::_Resolver->for_loop($loop);
    my $run = {
        loop => $loop, requests => $requests, completed => 0,
        started => {}, latencies => [],
    };
    my $target = BenchResolverTarget->new($run);
    my $batch_start = now();
    for (1 .. $requests) {
        my $submitted = now();
        my $id = $resolver->submit($target, $host, $service);
        $run->{started}{$id} = $submitted;
    }
    $loop->run;
    my $elapsed = now() - $batch_start;
    push @rates, $requests / $elapsed;
    push @latencies, @{ $run->{latencies} };
}

printf "resolver host=%s requests=%d repeats=%d\n", $host, $requests, $repeats;
printf "median rate: %.0f resolutions/s\n", median(@rates);
printf "median completion latency: %.3f ms\n", median(@latencies) * 1_000;

sub usage ($exit) {
    print <<'USAGE';
Usage: run-resolver-microbench.pl [options]
  --requests=N       resolutions per repeat (default: 1000)
  --repeats=N        measured repeats (default: 5)
  --host=NAME        hostname to resolve (default: localhost)
  --service=PORT     numeric service (default: 80)
  --help             show this help
USAGE
    exit $exit;
}
