#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use Time::HiRes qw(time clock_gettime CLOCK_PROCESS_CPUTIME_ID);

use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::IO::Sock::Stream;

{
    package Linux::Event::Bench::RawDelimiterEcho;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_data ($stream, $bytes) {
        my $state = $stream->data;
        $state->{buffer} .= $bytes;
        while ((my $at = index($state->{buffer}, $state->{delimiter})) >= 0) {
            my $message = substr($state->{buffer}, 0, $at, '');
            substr($state->{buffer}, 0, length($state->{delimiter}), '');
            die "framing payload mismatch\n" if $message ne $state->{payload};
            $stream->write($state->{wire})
                or die "framing benchmark unexpectedly hit backpressure\n";
        }
    }
    sub on_error ($stream, $error) { die "Stream error: $error\n" }
}

{
    package Linux::Event::Bench::NativeDelimiterEcho;
    use parent 'Linux::Event::IO::Sock::Stream';
    use Linux::Event::Framer 'Delimiter', "\x02END\x03";
    sub on_message ($stream, $message) {
        my $state = $stream->data;
        die "framing payload mismatch\n" if $message ne $state->{payload};
        $stream->write($state->{wire})
            or die "framing benchmark unexpectedly hit backpressure\n";
    }
    sub on_error ($stream, $error) { die "Stream error: $error\n" }
}

my @clients = (1, 10, 100, 1000);
my $messages = 100;
my $warmup = 10;
my $bytes = 64;
my $repeats = 6;
my $delimiter = "\x02END\x03";

GetOptions(
    'clients=s'  => sub { @clients = split /,/, $_[1] },
    'messages=i' => \$messages,
    'warmup=i'   => \$warmup,
    'bytes=i'    => \$bytes,
    'repeats=i'  => \$repeats,
) or die "bad options\n";

die "messages must be > 0\n" if $messages <= 0;
die "warmup must be >= 0\n" if $warmup < 0;
die "bytes must be > 0\n" if $bytes <= 0;
die "repeats must be > 0\n" if $repeats <= 0;

my @systems = ('raw-on-data', 'native-delimiter');
my @rows;

for my $count (@clients) {
    die "client count must be > 0\n" if $count <= 0;
    for my $repeat (1 .. $repeats) {
        my $shift = ($repeat - 1) % @systems;
        my @order = (@systems[$shift .. $#systems], @systems[0 .. $shift - 1]);
        for my $system (@order) {
            my $r = run_case($system, $count);
            push @rows, $r;
            printf "%s clients=%d repeat=%d %.1f msg/s cpu=%.3f us/msg\n",
                $system, $count, $repeat,
                $r->{messages_per_second}, $r->{cpu_us_per_message};
        }
    }
}

say "\nMedian framing microbenchmark";
printf "%-18s %8s %14s %14s\n", 'system', 'clients', 'msg/s', 'cpu us/msg';
for my $count (@clients) {
    for my $system (@systems) {
        my @set = grep { $_->{clients} == $count && $_->{system} eq $system } @rows;
        printf "%-18s %8d %14.1f %14.3f\n",
            $system, $count,
            median(map { $_->{messages_per_second} } @set),
            median(map { $_->{cpu_us_per_message} } @set);
    }
}

say "\nBoth paths use the same XS read/write transport and wire format.";
say "The raw row parses in on_data; the native row finds frame boundaries in XS.";

sub run_case ($system, $count) {
    my $loop = Linux::Event::Loop->new;
    my $payload = 'x' x $bytes;
    my $wire = $payload . $delimiter;
    my $wire_len = length($wire);
    my @server_fh;
    my @client_fh;
    my @streams;
    my @client_watchers;
    my @states;

    my $bench = {
        loop => $loop,
        wire => $wire,
        wire_len => $wire_len,
        clients => $count,
        warmup => $warmup,
        messages => $messages,
        warmup_done => 0,
        measured_done => 0,
        phase => $warmup ? 'warmup' : 'measure',
    };

    for my $i (0 .. $count - 1) {
        socketpair(my $server, my $client, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
            or die "socketpair: $!";
        set_nonblocking($server);
        set_nonblocking($client);
        push @server_fh, $server;
        push @client_fh, $client;

        my $state_data = {
            payload => $payload,
            wire => $wire,
            delimiter => $delimiter,
            buffer => '',
        };
        my $class = $system eq 'raw-on-data'
            ? 'Linux::Event::Bench::RawDelimiterEcho'
            : 'Linux::Event::Bench::NativeDelimiterEcho';
        push @streams, $class->new(
            loop => $loop,
            fh => $server,
            data => $state_data,
        );

        my $state = {
            bench => $bench,
            fh => $client,
            buffer => '',
            completed => 0,
            warmup_complete => 0,
            measured_complete => 0,
        };
        push @states, $state;
        push @client_watchers, $loop->watch(
            fh => $client,
            data => $state,
            read => \&_client_read,
        );
    }

    $bench->{states} = \@states;
    if ($warmup) {
        syswrite_all($_->{fh}, $wire) for @states;
    } else {
        start_measurement($bench);
    }

    $loop->run;
    my $elapsed = $bench->{wall_end} - $bench->{wall_start};
    my $cpu = $bench->{cpu_end} - $bench->{cpu_start};
    my $total = $count * $messages;

    $_->close for grep { !$_->is_closed } @streams;
    $_->cancel for @client_watchers;
    close $_ for @client_fh;

    return {
        system => $system,
        clients => $count,
        messages_per_second => $total / $elapsed,
        cpu_us_per_message => ($cpu * 1_000_000) / $total,
    };
}

sub _client_read ($watcher) {
    my $state = $watcher->data;
    my $bench = $state->{bench};
    while (1) {
        my $chunk = '';
        my $n = sysread($state->{fh}, $chunk, 65_536);
        if (defined $n) {
            die "client unexpected EOF\n" if $n == 0;
            $state->{buffer} .= $chunk;
            while (length($state->{buffer}) >= $bench->{wire_len}) {
                my $got = substr($state->{buffer}, 0, $bench->{wire_len}, '');
                die "client wire mismatch\n" if $got ne $bench->{wire};
                $state->{completed}++;
                if ($bench->{phase} eq 'warmup') {
                    if ($state->{completed} < $bench->{warmup}) {
                        syswrite_all($state->{fh}, $bench->{wire});
                    } elsif (!$state->{warmup_complete}++) {
                        $bench->{warmup_done}++;
                        start_measurement($bench)
                            if $bench->{warmup_done} == $bench->{clients};
                    }
                } else {
                    if ($state->{completed} < $bench->{messages}) {
                        syswrite_all($state->{fh}, $bench->{wire});
                    } elsif (!$state->{measured_complete}++) {
                        $bench->{measured_done}++;
                        if ($bench->{measured_done} == $bench->{clients}) {
                            $bench->{wall_end} = time;
                            $bench->{cpu_end} = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
                            $bench->{loop}->stop;
                            return;
                        }
                    }
                }
            }
            next;
        }
        return if $!{EAGAIN} || $!{EWOULDBLOCK};
        next if $!{EINTR};
        die "client read: $!";
    }
}

sub start_measurement ($bench) {
    return if $bench->{phase} eq 'measure' && defined $bench->{wall_start};
    $bench->{phase} = 'measure';
    for my $state (@{ $bench->{states} }) {
        $state->{completed} = 0;
        $state->{buffer} = '';
    }
    $bench->{cpu_start} = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
    $bench->{wall_start} = time;
    syswrite_all($_->{fh}, $bench->{wire}) for @{ $bench->{states} };
}

sub syswrite_all ($fh, $bytes) {
    my $off = 0;
    my $len = length($bytes);
    while ($off < $len) {
        my $n = syswrite($fh, $bytes, $len - $off, $off);
        if (defined $n) { $off += $n; next }
        next if $!{EINTR};
        die "benchmark write would block unexpectedly\n" if $!{EAGAIN} || $!{EWOULDBLOCK};
        die "benchmark write: $!";
    }
}

sub set_nonblocking ($fh) {
    my $flags = fcntl($fh, F_GETFL, 0);
    die "fcntl F_GETFL: $!" if !defined $flags;
    fcntl($fh, F_SETFL, $flags | O_NONBLOCK)
        or die "fcntl F_SETFL: $!";
}

sub median (@values) {
    @values = sort { $a <=> $b } @values;
    my $n = @values;
    return 0 if !$n;
    return $values[int($n / 2)] if $n % 2;
    return ($values[$n / 2 - 1] + $values[$n / 2]) / 2;
}
