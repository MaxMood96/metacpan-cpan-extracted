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
    package Linux::Event::Bench::NativeFramerBase;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_message ($stream, $message) {
        my $state = $stream->data;
        die "framing payload mismatch\n" if $message ne $state->{payload};
        $stream->write($state->{wire})
            or die "benchmark unexpectedly hit backpressure\n";
    }
    sub on_error ($stream, $error) { die "Stream error: $error\n" }
}

{
    package Linux::Event::Bench::NativeDelimiter;
    use parent -norequire, 'Linux::Event::Bench::NativeFramerBase';
    use Linux::Event::Framer 'Delimiter', "\x02END\x03";
}

{
    package Linux::Event::Bench::NativeLength;
    use parent -norequire, 'Linux::Event::Bench::NativeFramerBase';
    use Linux::Event::Framer 'LengthPrefix', bytes => 4, endian => 'big';
}

{
    package Linux::Event::Bench::NativeU32BE;
    use parent -norequire, 'Linux::Event::Bench::NativeFramerBase';
    use Linux::Event::Framer 'U32BE';
}

{
    package Linux::Event::Bench::NativeNetstring;
    use parent -norequire, 'Linux::Event::Bench::NativeFramerBase';
    use Linux::Event::Framer 'Netstring';
}

{
    package Linux::Event::Bench::NativeVarint;
    use parent -norequire, 'Linux::Event::Bench::NativeFramerBase';
    use Linux::Event::Framer 'Varint';
}

{
    package Linux::Event::Bench::NativeDecimal;
    use parent -norequire, 'Linux::Event::Bench::NativeFramerBase';
    use Linux::Event::Framer 'DecimalLength';
}

my @clients = (1, 10, 100, 1000);
my $messages = 100;
my $warmup = 10;
my $bytes = 64;
my $repeats = 6;
my @framers = qw(delimiter fixed length u32be netstring varint decimal);

GetOptions(
    'clients=s'  => sub { @clients = split /,/, $_[1] },
    'messages=i' => \$messages,
    'warmup=i'   => \$warmup,
    'bytes=i'    => \$bytes,
    'repeats=i'  => \$repeats,
    'framers=s'  => sub { @framers = split /,/, $_[1] },
) or die "bad options\n";

die "messages must be > 0\n" if $messages <= 0;
die "warmup must be >= 0\n" if $warmup < 0;
die "bytes must be > 0\n" if $bytes <= 0;
die "repeats must be > 0\n" if $repeats <= 0;

my %valid = map { $_ => 1 } qw(delimiter fixed length u32be netstring varint decimal);
die "unknown framer in --framers\n" if grep { !$valid{$_} } @framers;

eval qq{
    package Linux::Event::Bench::NativeFixed;
    use parent -norequire, 'Linux::Event::Bench::NativeFramerBase';
    use Linux::Event::Framer 'Fixed', size => $bytes;
    1;
} or die "define fixed-size benchmark Stream: $@";

my %stream_class = (
    delimiter => 'Linux::Event::Bench::NativeDelimiter',
    fixed     => 'Linux::Event::Bench::NativeFixed',
    length    => 'Linux::Event::Bench::NativeLength',
    u32be     => 'Linux::Event::Bench::NativeU32BE',
    netstring => 'Linux::Event::Bench::NativeNetstring',
    varint    => 'Linux::Event::Bench::NativeVarint',
    decimal   => 'Linux::Event::Bench::NativeDecimal',
);
my @rows;

for my $framer_name (@framers) {
    for my $count (@clients) {
        die "client count must be > 0\n" if $count <= 0;
        for my $repeat (1 .. $repeats) {
            my $r = run_case($framer_name, $count);
            push @rows, $r;
            printf "%s/native clients=%d repeat=%d %.1f msg/s cpu=%.3f us/msg\n",
                $framer_name, $count, $repeat,
                $r->{messages_per_second}, $r->{cpu_us_per_message};
        }
    }
}

say "\nMedian native built-in framing microbenchmark";
printf "%-10s %8s %14s %14s\n", 'framer', 'clients', 'msg/s', 'cpu us/msg';
for my $framer_name (@framers) {
    for my $count (@clients) {
        my @set = grep {
            $_->{framer} eq $framer_name && $_->{clients} == $count
        } @rows;
        printf "%-10s %8d %14.1f %14.3f\n",
            $framer_name, $count,
            median(map { $_->{messages_per_second} } @set),
            median(map { $_->{cpu_us_per_message} } @set);
    }
}

say "\nEach row uses a canonical Stream subclass and its native built-in parser.";
say "Compare framers only within the same payload, client, and host settings.";

sub wire_for ($name, $payload) {
    if ($name eq 'delimiter') {
        return $payload . "\x02END\x03";
    }
    if ($name eq 'fixed') {
        return $payload;
    }
    if ($name eq 'length') {
        return pack('N', length($payload)) . $payload;
    }
    if ($name eq 'u32be') {
        return pack('N', length($payload)) . $payload;
    }
    if ($name eq 'netstring') {
        return length($payload) . ':' . $payload . ',';
    }
    if ($name eq 'varint') {
        my $value = length($payload);
        my @prefix;
        do {
            my $byte = $value % 128;
            $value = int($value / 128);
            $byte |= 0x80 if $value;
            push @prefix, $byte;
        } while ($value);
        return pack('C*', @prefix) . $payload;
    }
    if ($name eq 'decimal') {
        return length($payload) . ' ' . $payload;
    }
    die "unknown framer $name\n";
}

sub run_case ($framer_name, $count) {
    my $loop = Linux::Event::Loop->new;
    my $payload = 'x' x $bytes;
    my $wire = wire_for($framer_name, $payload);
    my $wire_len = length($wire);
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
        push @client_fh, $client;

        my $class = $stream_class{$framer_name};
        push @streams, $class->new(
            loop => $loop,
            fh => $server,
            data => { payload => $payload, wire => $wire },
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
        framer => $framer_name,
        mode => 'native',
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
