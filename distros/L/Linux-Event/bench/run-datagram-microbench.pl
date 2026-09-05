#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use JSON::PP;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

use Linux::Event;
use Linux::Event::IO::Sock::Dgram;
use Linux::Event::Loop;

my $packets = 100_000;
my $bytes = 64;
my @modes = qw(connected unconnected);
my $repeats = 5;
my $json_path;
my $help;

GetOptions(
    'packets=i' => \$packets,
    'bytes=i'   => \$bytes,
    'modes=s'   => sub { @modes = split /,/, $_[1] },
    'repeats=i' => \$repeats,
    'json=s'    => \$json_path,
    'help'      => \$help,
) or usage(1);
usage(0) if $help;
die "packets must be positive\n" if $packets < 1;
die "bytes must be between 1 and 65507\n" if $bytes < 1 || $bytes > 65_507;
die "repeats must be positive\n" if $repeats < 1;
die "modes must contain connected and/or unconnected\n"
    if !@modes || grep { $_ ne 'connected' && $_ ne 'unconnected' } @modes;

{
    package BenchDatagramServer;
    use parent 'Linux::Event::IO::Sock::Dgram';

    sub on_datagram ($socket, $payload, $peer) {
        $socket->send($payload, to => $peer)
            // die "server could not echo packet\n";
    }

    sub on_error ($socket, $error) { die "$error\n" }
}

{
    package BenchDatagramClient;
    use parent 'Linux::Event::IO::Sock::Dgram';

    sub on_ready ($socket) {
        my $run = $socket->data;
        $run->{started} = main::now();
        main::send_next($socket, $run);
    }

    sub on_datagram ($socket, $payload, $peer) {
        my $run = $socket->data;
        die "Datagram benchmark received a corrupt payload\n"
            if $payload ne $run->{payload};
        $run->{received}++;
        if ($run->{received} == $run->{packets}) {
            $run->{finished} = main::now();
            $run->{loop}->stop;
        } else {
            main::send_next($socket, $run);
        }
    }

    sub on_error ($socket, $error) { die "$error\n" }
}

sub now () { clock_gettime(CLOCK_MONOTONIC) }

sub median (@value) {
    @value = sort { $a <=> $b } @value;
    my $middle = int(@value / 2);
    return @value % 2
        ? $value[$middle]
        : ($value[$middle - 1] + $value[$middle]) / 2;
}

sub send_next ($socket, $run) {
    my $accepted = $run->{mode} eq 'connected'
        ? $socket->send($run->{payload})
        : $socket->send($run->{payload}, to => $run->{server_address});
    die "Datagram benchmark output was rejected\n" if !defined $accepted;
    return;
}

my @raw;
for my $mode (@modes) {
    for my $repeat (1 .. $repeats) {
        my $loop = Linux::Event::Loop->new;
        my $server = $loop->add(BenchDatagramServer->new(
            host => '127.0.0.1', # required
            port => 0,           # required; select an ephemeral port
        ));
        my $run = {
            loop => $loop,
            mode => $mode,
            packets => $packets,
            payload => 'x' x $bytes,
            received => 0,
            server_address => $server->local,
        };
        my $client = $mode eq 'connected'
            ? BenchDatagramClient->connect(
                host => '127.0.0.1',       # required
                port => $server->local->port, # required
                data => $run,              # optional
            )
            : BenchDatagramClient->new(
                host => '127.0.0.1', # required
                port => 0,           # required
                data => $run,        # optional
            );
        $loop->add($client);
        my ($user_start, $system_start) = (times)[0, 1];
        $loop->run;
        my ($user_end, $system_end) = (times)[0, 1];
        my $elapsed = $run->{finished} - $run->{started};
        my $cpu = ($user_end - $user_start) + ($system_end - $system_start);
        $client->close;
        $server->close;
        die "Datagram benchmark received $run->{received} of $packets packets\n"
            if $run->{received} != $packets;
        push @raw, {
            mode => $mode,
            repeat => $repeat,
            packets => $packets,
            bytes => $bytes,
            elapsed_seconds => 0 + $elapsed,
            packets_per_second => $packets / $elapsed,
            mebibytes_per_second => ($packets * $bytes) / $elapsed / 1_048_576,
            cpu_us_per_packet => $cpu * 1_000_000 / $packets,
        };
    }
}

my @summary;
for my $mode (@modes) {
    my @row = grep { $_->{mode} eq $mode } @raw;
    push @summary, {
        mode => $mode,
        median_packets_per_second => median(
            map { $_->{packets_per_second} } @row,
        ),
        median_mebibytes_per_second => median(
            map { $_->{mebibytes_per_second} } @row,
        ),
        median_cpu_us_per_packet => median(
            map { $_->{cpu_us_per_packet} } @row,
        ),
    };
}

printf "Datagram UDP serial echo: packets=%d bytes=%d repeats=%d\n",
    $packets, $bytes, $repeats;
printf "%-12s %18s %14s %16s\n",
    'mode', 'packets/s', 'MiB/s', 'cpu us/packet';
for my $row (@summary) {
    printf "%-12s %18.1f %14.2f %16.3f\n",
        $row->{mode},
        $row->{median_packets_per_second},
        $row->{median_mebibytes_per_second},
        $row->{median_cpu_us_per_packet};
}

if (defined $json_path) {
    my $report = {
        benchmark => 'linux-event-datagram-microbench',
        benchmark_contract_version => 1,
        linux_event_version => $Linux::Event::VERSION,
        workload => 'IPv4 loopback serial UDP echo',
        configuration => {
            packets => $packets,
            bytes => $bytes,
            modes => \@modes,
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
Usage: run-datagram-microbench.pl [options]
  --packets=N       serial echo round trips per repeat (default: 100000)
  --bytes=N         payload bytes per packet, 1..65507 (default: 64)
  --modes=LIST      connected,unconnected (default: both)
  --repeats=N       measured repeats (default: 5)
  --json=PATH       write a machine-readable report
  --help            show this help
USAGE
    exit $exit;
}
