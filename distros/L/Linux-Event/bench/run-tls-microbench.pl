#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use FindBin qw($Bin);
use Getopt::Long qw(GetOptions);
use JSON::PP qw(encode_json);
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);
use Time::HiRes qw(time clock_gettime CLOCK_PROCESS_CPUTIME_ID);

use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::TLS;

{
    package Linux::Event::TLS::Bench::Echo;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_data ($stream, $bytes) {
        $stream->write($bytes)
            or die "benchmark echo entered backpressure\n";
    }
    sub on_error ($stream, $error) { die "echo Stream error: $error\n" }
}

{
    package Linux::Event::TLS::Bench::Client;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_transport_ready ($stream) { main::client_ready($stream) }
    sub on_data ($stream, $bytes) { main::client_data($stream, $bytes) }
    sub on_error ($stream, $error) { die "client Stream error: $error\n" }
}

my @clients = (1, 10, 100);
my $messages = 1_000;
my $warmup = 100;
my $bytes = 64;
my $repeats = 6;
my $json_file;
my $cert_file = "$Bin/../t/tls-certs/server-cert.pem";
my $key_file = "$Bin/../t/tls-certs/server-key.pem";

GetOptions(
    'clients=s'  => sub { @clients = split /,/, $_[1] },
    'messages=i' => \$messages,
    'warmup=i'   => \$warmup,
    'bytes=i'    => \$bytes,
    'repeats=i'  => \$repeats,
    'json=s'     => \$json_file,
    'cert-file=s' => \$cert_file,
    'key-file=s'  => \$key_file,
) or die "bad options\n";

die "messages must be > 0\n" if $messages <= 0;
die "warmup must be >= 0\n" if $warmup < 0;
die "bytes must be > 0\n" if $bytes <= 0;
die "repeats must be > 0\n" if $repeats <= 0;
die "each client count must be > 0\n" if grep { $_ <= 0 } @clients;
die "TLS certificate file not found: $cert_file\n" if !-f $cert_file;
die "TLS private-key file not found: $key_file\n" if !-f $key_file;

my @systems = qw(plain tls);
my @rows;

for my $count (@clients) {
    for my $repeat (1 .. $repeats) {
        my @order = $repeat % 2 ? @systems : reverse @systems;
        for my $system (@order) {
            my $row = run_case($system, $count);
            $row->{repeat} = $repeat;
            push @rows, $row;
            printf "%s clients=%d repeat=%d %.1f msg/s cpu=%.3f us/msg\n",
                $system, $count, $repeat,
                $row->{messages_per_second}, $row->{cpu_us_per_message};
        }
    }
}

say "\nMedian established-connection Stream transport benchmark";
printf "%-8s %8s %14s %14s\n", 'system', 'clients', 'msg/s', 'cpu us/msg';
for my $count (@clients) {
    for my $system (@systems) {
        my @set = grep {
            $_->{clients} == $count && $_->{system} eq $system
        } @rows;
        printf "%-8s %8d %14.1f %14.3f\n",
            $system, $count,
            median(map { $_->{messages_per_second} } @set),
            median(map { $_->{cpu_us_per_message} } @set);
    }
}

if (defined $json_file) {
    open my $json_fh, '>', $json_file
        or die "open $json_file: $!\n";
    print {$json_fh} encode_json({
        benchmark => 'linux-event-stream-plain-vs-tls',
        clients   => \@clients,
        messages  => $messages,
        warmup    => $warmup,
        bytes     => $bytes,
        repeats   => $repeats,
        rows      => \@rows,
    });
    print {$json_fh} "\n";
    close $json_fh or die "close $json_file: $!\n";
}

say "\nBoth rows use Linux::Event::IO::Sock::Stream on AF_UNIX socketpairs.";
say "The TLS row uses verified protocol machinery with local test identity";
say "and excludes construction/handshake from the timed message interval.";

sub run_case ($system, $count) {
    my $loop = Linux::Event::Loop->new;
    my $bench = {
        loop          => $loop,
        system        => $system,
        clients       => $count,
        payload       => 'x' x $bytes,
        bytes         => $bytes,
        warmup        => $warmup,
        messages      => $messages,
        ready         => 0,
        warmup_done   => 0,
        measured_done => 0,
        states        => [],
    };
    my (@streams, @providers);

    for my $index (0 .. $count - 1) {
        socketpair(my $client_fh, my $server_fh,
            AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!\n";
        my $state = {
            bench     => $bench,
            received  => 0,
            completed => 0,
            phase     => $warmup ? 'warmup' : 'measure',
        };
        push @{ $bench->{states} }, $state;

        my ($client_provider, $server_provider);
        if ($system eq 'tls') {
            $client_provider = Linux::Event::TLS->client(
                server_name => 'localhost', ca_file => $cert_file,
            );
            $server_provider = Linux::Event::TLS->server(
                cert_file => $cert_file, key_file => $key_file,
            );
            push @providers, $client_provider, $server_provider;
        }

        my $server = Linux::Event::TLS::Bench::Echo->new(
            loop => $loop,
            fh => $server_fh,
            data => $state,
            ($server_provider ? (transport => $server_provider) : ()),
        );
        my $client = Linux::Event::TLS::Bench::Client->new(
            loop => $loop,
            fh => $client_fh,
            data => $state,
            ($client_provider ? (transport => $client_provider) : ()),
        );
        $state->{client} = $client;
        push @streams, $server, $client;
        client_ready($client) if $system eq 'plain';
    }

    $loop->run;

    my $wall = $bench->{wall_end} - $bench->{wall_start};
    my $cpu = $bench->{cpu_end} - $bench->{cpu_start};
    my $total = $count * $messages;
    my %tls_stats;
    if ($system eq 'tls') {
        for my $provider (@providers) {
            my $stats = $provider->stats;
            $tls_stats{$_} += $stats->{$_} for keys %$stats;
        }
    }
    $_->close for grep { !$_->is_closed } @streams;

    return {
        system              => $system,
        clients             => $count,
        measured_messages   => $total,
        wall_seconds        => $wall,
        cpu_seconds         => $cpu,
        messages_per_second => $total / $wall,
        cpu_us_per_message  => ($cpu * 1_000_000) / $total,
        tls_stats            => \%tls_stats,
    };
}

sub client_ready ($stream) {
    my $bench = $stream->data->{bench};
    $bench->{ready}++;
    return if $bench->{ready} != $bench->{clients};

    if (!$bench->{warmup}) {
        $bench->{wall_start} = time;
        $bench->{cpu_start} = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
    }
    $_->{client}->write($bench->{payload}) for @{ $bench->{states} };
}

sub client_data ($stream, $input) {
    my $state = $stream->data;
    my $bench = $state->{bench};
    $state->{received} += length($input);

    while ($state->{received} >= $bench->{bytes}) {
        $state->{received} -= $bench->{bytes};
        $state->{completed}++;
        my $target = $state->{phase} eq 'warmup'
            ? $bench->{warmup} : $bench->{messages};

        if ($state->{completed} < $target) {
            $stream->write($bench->{payload});
            next;
        }

        if ($state->{phase} eq 'warmup') {
            $bench->{warmup_done}++;
            if ($bench->{warmup_done} == $bench->{clients}) {
                $_->{phase} = 'measure' for @{ $bench->{states} };
                $_->{completed} = 0 for @{ $bench->{states} };
                $bench->{wall_start} = time;
                $bench->{cpu_start} = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
                $_->{client}->write($bench->{payload})
                    for @{ $bench->{states} };
            }
        } else {
            $bench->{measured_done}++;
            if ($bench->{measured_done} == $bench->{clients}) {
                $bench->{wall_end} = time;
                $bench->{cpu_end} = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
                $bench->{loop}->stop;
            }
        }
    }
}

sub median (@values) {
    @values = sort { $a <=> $b } @values;
    return $values[int(@values / 2)] if @values % 2;
    return ($values[@values / 2 - 1] + $values[@values / 2]) / 2;
}
