#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Config ();
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use Getopt::Long qw(GetOptions);
use JSON::PP ();
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC SOL_SOCKET SO_RCVBUF SO_SNDBUF);
use Sys::Hostname qw(hostname);
use Time::HiRes qw(time clock_gettime CLOCK_PROCESS_CPUTIME_ID);

use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;

{
    package Linux::Event::Bench::SendLength;
    use parent 'Linux::Event::IO::Sock::Stream';
    use Linux::Event::Framer 'LengthPrefix', bytes => 4, endian => 'big';
    sub on_message ($stream, $message) { }
    sub on_error ($stream, $error) { die "Stream error: $error\n" }
}

{
    package Linux::Event::Bench::SendVarint;
    use parent 'Linux::Event::IO::Sock::Stream';
    use Linux::Event::Framer 'Varint';
    sub on_message ($stream, $message) { }
    sub on_error ($stream, $error) { die "Stream error: $error\n" }
}

my @original_argv = @ARGV;
my @sizes = (64, 256, 1_024, 4_096, 16_384, 32_768,
    65_536, 131_072, 200_000);
my @framers = qw(length varint);
my $repeats = 5;
my $warmup = 1;
my $target_bytes = 16 * 1024 * 1024;
my $min_messages = 128;
my $max_messages = 200_000;
my $variant = 'unspecified';
my $commit = 'unspecified';
my $output;

GetOptions(
    'sizes=s' => sub { @sizes = split /,/, $_[1] },
    'framers=s' => sub { @framers = split /,/, $_[1] },
    'repeats=i' => \$repeats,
    'warmup=i' => \$warmup,
    'target-bytes=i' => \$target_bytes,
    'min-messages=i' => \$min_messages,
    'max-messages=i' => \$max_messages,
    'variant=s' => \$variant,
    'commit=s' => \$commit,
    'output=s' => \$output,
) or die "bad options\n";

my %valid_framer = map { $_ => 1 } qw(length varint);
die "sizes must be positive\n" if grep { $_ <= 0 } @sizes;
die "unknown framer\n" if grep { !$valid_framer{$_} } @framers;
die "repeats must be positive\n" if $repeats <= 0;
die "warmup must be non-negative\n" if $warmup < 0;
die "target-bytes must be positive\n" if $target_bytes <= 0;
die "message bounds are invalid\n"
    if $min_messages <= 0 || $max_messages < $min_messages;

my %class_for = (
    length => 'Linux::Event::Bench::SendLength',
    varint => 'Linux::Event::Bench::SendVarint',
);
my @samples;
my %effective_by_case;

for my $framer (@framers) {
    for my $size (@sizes) {
        my $messages = int($target_bytes / $size);
        $messages = $min_messages if $messages < $min_messages;
        $messages = $max_messages if $messages > $max_messages;
        run_once($framer, $size, $messages) for 1 .. $warmup;
        for my $repeat (1 .. $repeats) {
            my ($sample, $effective) = run_once($framer, $size, $messages);
            $sample->{repeat} = $repeat;
            push @samples, $sample;
            $effective_by_case{"$framer/$size"} = $effective;
            printf "%s %7d B repeat=%d %10.1f msg/s %8.3f ns/B\n",
                $framer, $size, $repeat, $sample->{messages_per_second},
                $sample->{cpu_ns_per_payload_byte};
        }
    }
}

my @summary;
for my $framer (@framers) {
    for my $size (@sizes) {
        my @case = grep {
            $_->{framer} eq $framer && $_->{payload_bytes} == $size
        } @samples;
        push @summary, {
            framer => $framer,
            payload_bytes => 0 + $size,
            messages => $case[0]{messages},
            median_messages_per_second => median(
                map { $_->{messages_per_second} } @case),
            median_payload_mib_per_second => median(
                map { $_->{payload_mib_per_second} } @case),
            median_cpu_ns_per_payload_byte => median(
                map { $_->{cpu_ns_per_payload_byte} } @case),
        };
    }
}

my $report = {
    benchmark => 'framer-send',
    benchmark_contract_version => 1,
    variant => $variant,
    commit => $commit,
    command => join(' ', $^X, $0, @original_argv),
    generated_at_epoch => time,
    runtime => {
        hostname => hostname(),
        perl => "$^V",
        os => $^O,
        architecture => $Config::Config{archname},
        compiler => $Config::Config{cc},
        compiler_flags => $Config::Config{ccflags},
    },
    requested_config => {
        sizes => [map { 0 + $_ } @sizes],
        framers => [@framers],
        repeats => $repeats,
        warmup => $warmup,
        target_payload_bytes_per_sample => $target_bytes,
        min_messages => $min_messages,
        max_messages => $max_messages,
    },
    effective_config_by_case => \%effective_by_case,
    samples => \@samples,
    summary => \@summary,
};

my $json = JSON::PP->new->canonical->pretty->encode($report);
if (defined $output) {
    open my $fh, '>:raw', $output or die "open $output: $!\n";
    print {$fh} $json or die "write $output: $!\n";
    close $fh or die "close $output: $!\n";
} else {
    print $json;
}

sub run_once ($framer, $payload_size, $messages) {
    socketpair(my $producer, my $peer, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
        or die "socketpair: $!";
    set_nonblocking($peer);
    my $loop = Linux::Event::Loop->new;
    my $class = $class_for{$framer};
    my $stream = $class->new(loop => $loop, fh => $producer);
    my $payload = 'x' x $payload_size;
    my $prefix_bytes = $framer eq 'length' ? 4 : varint_width($payload_size);
    my $wire_bytes = $messages * ($payload_size + $prefix_bytes);
    my $received = 0;
    my ($wall_end, $cpu_end);
    my $watcher = $loop->watch(
        fh => $peer,
        read => sub ($watcher) {
            while (1) {
                my $chunk = '';
                my $count = sysread($peer, $chunk, 262_144);
                if (defined $count) {
                    die "unexpected benchmark EOF\n" if $count == 0;
                    $received += $count;
                    die "received too many framed bytes\n"
                        if $received > $wire_bytes;
                    if ($received == $wire_bytes) {
                        $wall_end = time;
                        $cpu_end = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
                        $loop->stop;
                        return;
                    }
                    next;
                }
                return if $!{EAGAIN} || $!{EWOULDBLOCK};
                next if $!{EINTR};
                die "peer read: $!\n";
            }
        },
    );

    my $send_buffer = socket_buffer($producer, SO_SNDBUF);
    my $receive_buffer = socket_buffer($peer, SO_RCVBUF);
    my $cpu_start = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
    my $wall_start = time;
    $stream->send($payload) for 1 .. $messages;
    $loop->run if $received < $wire_bytes;
    die "benchmark did not receive every byte\n" if $received != $wire_bytes;

    my $elapsed = $wall_end - $wall_start;
    my $cpu = $cpu_end - $cpu_start;
    my $payload_bytes = $messages * $payload_size;
    my $stats = $stream->{xs_state}->stats;
    my $options = $stream->{descriptor}{options};
    my $native = $stream->{descriptor}{framer}{native};
    my $sample = {
        framer => $framer,
        payload_bytes => $payload_size,
        prefix_bytes => $prefix_bytes,
        messages => $messages,
        payload_total_bytes => $payload_bytes,
        wire_total_bytes => $wire_bytes,
        elapsed_seconds => $elapsed,
        cpu_seconds => $cpu,
        messages_per_second => $messages / $elapsed,
        payload_mib_per_second => ($payload_bytes / 1_048_576) / $elapsed,
        cpu_ns_per_payload_byte => $cpu * 1_000_000_000 / $payload_bytes,
        stream_stats => {
            map { $_ => $stats->{$_} } qw(
                write_submit_calls write_calls writev_calls bytes_written
                write_eagain_count write_eintr_count queued_segments
                queue_peak_bytes pending_bytes
            )
        },
    };
    my $effective = {
        delivery => 'write-only framed Stream send()',
        framer_class => $framer eq 'length'
            ? 'Linux::Event::Framer::LengthPrefix'
            : 'Linux::Event::Framer::Varint',
        framer_parameters => $framer eq 'length'
            ? { bytes => 4, endian => 'big', include_prefix => 0,
                max_frame => undef }
            : { include_prefix => 0, max_frame => undef },
        transport => 'AF_UNIX SOCK_STREAM socketpair',
        concurrency => 1,
        producer_topology => 'one Stream producer, one Loop peer drain',
        readiness => 'level-triggered',
        peer_read_size => 262_144,
        read_size => 0 + $options->{read_size},
        read_budget_bytes => 0 + $options->{read_budget_bytes},
        read_batch_bytes => 0 + $options->{read_batch_bytes},
        message_batch_size => 0 + $options->{message_batch_size},
        max_buffer => 0 + $options->{max_buffer},
        high_watermark => 0 + $options->{high_watermark},
        low_watermark => 0 + $options->{low_watermark},
        max_pending_bytes => 0 + $options->{max_pending_bytes},
        write_queue => 'native segmented queue with writev drain',
        tls => JSON::PP::false,
        socket_nonblocking => JSON::PP::true,
        socket_send_buffer => $send_buffer,
        socket_receive_buffer => $receive_buffer,
        socket_options => 'OS defaults',
        native_descriptor => { %$native },
    };

    $stream->close;
    $watcher->cancel;
    close $peer;
    return ($sample, $effective);
}

sub varint_width ($value) {
    my $width = 1;
    $width++, $value >>= 7 while $value >= 128;
    return $width;
}

sub socket_buffer ($fh, $name) {
    my $packed = getsockopt($fh, SOL_SOCKET, $name);
    return undef if !defined $packed;
    return unpack('i', $packed);
}

sub set_nonblocking ($fh) {
    my $flags = fcntl($fh, F_GETFL, 0);
    die "fcntl F_GETFL: $!\n" if !defined $flags;
    fcntl($fh, F_SETFL, $flags | O_NONBLOCK)
        or die "fcntl F_SETFL: $!\n";
}

sub median (@values) {
    @values = sort { $a <=> $b } @values;
    return 0 if !@values;
    return $values[int(@values / 2)] if @values % 2;
    return ($values[@values / 2 - 1] + $values[@values / 2]) / 2;
}
