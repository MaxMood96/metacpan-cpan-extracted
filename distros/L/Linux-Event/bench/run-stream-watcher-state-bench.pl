#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Errno qw(EAGAIN EWOULDBLOCK EINTR);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use Fcntl qw(
    F_GETFD F_SETFD FD_CLOEXEC
    F_GETFL F_SETFL O_NONBLOCK
);
use FindBin qw($Bin);
use Getopt::Long qw(GetOptions);
use JSON::PP ();
use POSIX qw(strftime uname);
use Socket qw(
    AF_UNIX SOCK_STREAM PF_UNSPEC
    SOL_SOCKET SO_SNDBUF
);
use Time::HiRes qw(time clock_gettime CLOCK_PROCESS_CPUTIME_ID);

use Linux::Event::Loop;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::IO::Sock::Stream;
use Linux::Event::TLS;

{
    package Linux::Event::Bench::WatcherState::Stream;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_data ($stream, $bytes) { return }
}

{
    package Linux::Event::Bench::WatcherState::TLSStream;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_transport_ready ($stream) { $stream->data->{ready}++ }
    sub on_data ($stream, $bytes) { return }
    sub on_eof ($stream) { $stream->data->{eof}++ }
    sub on_error ($stream, $error) {
        $stream->data->{error} //= "$error";
        $stream->loop->stop;
        return;
    }
}

my @all_cases = qw(
    watcher-read-toggle
    xsstate-pause-toggle
    stream-pause-resume
    raw-register-cancel
    stream-attach-detach
    stream-half-close
    stream-close
    queued-write-drain
    tls-handshake
    tls-shutdown
);
my %known_case = map { $_ => 1 } @all_cases;

my $contract_version = 1;
my $operations = 10_000;
my $pool_size = 256;
my $warmup = 1_000;
my $repeats = 7;
my $queue_bytes = 12_288;
my $send_buffer = 4_096;
my $tls_pairs = 64;
my $timeout = 10;
my @cases = @all_cases;
my $cert_file = "$Bin/../t/tls-certs/server-cert.pem";
my $key_file = "$Bin/../t/tls-certs/server-key.pem";
my $json_path;
my $help;

GetOptions(
    'operations=i'  => \$operations,
    'pool=i'        => \$pool_size,
    'warmup=i'      => \$warmup,
    'repeats=i'     => \$repeats,
    'queue-bytes=i' => \$queue_bytes,
    'send-buffer=i' => \$send_buffer,
    'tls-pairs=i'   => \$tls_pairs,
    'timeout=f'     => \$timeout,
    'cases=s'       => sub { @cases = split /,/, $_[1] },
    'cert-file=s'   => \$cert_file,
    'key-file=s'    => \$key_file,
    'json=s'        => \$json_path,
    'help'          => \$help,
) or usage(2);

usage(0) if $help;
die "operations must be > 0\n" if $operations <= 0;
die "pool must be > 0\n" if $pool_size <= 0;
die "warmup must be >= 0\n" if $warmup < 0;
die "repeats must be > 0\n" if $repeats <= 0;
die "queue-bytes must be > 0\n" if $queue_bytes <= 0;
die "send-buffer must be > 0\n" if $send_buffer <= 0;
die "tls-pairs must be > 0\n" if $tls_pairs <= 0;
die "timeout must be > 0\n" if $timeout <= 0;
die "at least one case is required\n" if !@cases;
die "unknown case: $_\n" for grep { !$known_case{$_} } @cases;

if (grep { /^tls-/ } @cases) {
    die "TLS certificate not found: $cert_file\n" if !-f $cert_file;
    die "TLS private key not found: $key_file\n" if !-f $key_file;
}

say 'Linux::Event Stream watcher-state benchmark';
say "version=$Linux::Event::IO::Sock::Stream::VERSION perl=$^V pid=$$";
say "contract=$contract_version cases=" . join(',', @cases);
say "native_timing=enabled";

my @records;
for my $repeat (1 .. $repeats) {
    for my $case (rotated_cases($repeat)) {
        my $row = run_case($case);
        $row->{repeat} = $repeat;
        push @records, $row;
        printf "%s repeat=%d %.1f ops/s cpu=%.3f us/op ctl=%.3f/%.3f/%.3f mod=%.1f ns/op\n",
            $case, $repeat, $row->{operations_per_second},
            $row->{cpu_us_per_operation},
            $row->{epoll_ctl_add_calls_per_operation},
            $row->{epoll_ctl_mod_calls_per_operation},
            $row->{epoll_ctl_del_calls_per_operation},
            $row->{epoll_ctl_mod_ns_per_operation};
    }
}

my @summary;
say "\nMedian watcher-state summary";
printf "%-26s %14s %12s %9s %9s %9s %12s\n",
    'case', 'ops/s', 'cpu us/op', 'add/op', 'mod/op', 'del/op', 'mod ns/op';
for my $case (@cases) {
    my @set = grep { $_->{case} eq $case } @records;
    my $row = {
        benchmark_contract_version => $contract_version,
        case => $case,
        operation_unit => $set[0]{operation_unit},
        operations => $set[0]{operations},
    };
    for my $key (qw(
        operations_per_second cpu_us_per_operation
        epoll_ctl_add_calls_per_operation
        epoll_ctl_mod_calls_per_operation
        epoll_ctl_del_calls_per_operation
        epoll_ctl_add_ns_per_operation
        epoll_ctl_mod_ns_per_operation
        epoll_ctl_del_ns_per_operation
        callback_calls_per_operation
        ready_events_returned_per_operation
    )) {
        $row->{$key} = median(map { $_->{$key} } @set);
    }
    push @summary, $row;
    printf "%-26s %14.1f %12.3f %9.3f %9.3f %9.3f %12.1f\n",
        $case, $row->{operations_per_second}, $row->{cpu_us_per_operation},
        $row->{epoll_ctl_add_calls_per_operation},
        $row->{epoll_ctl_mod_calls_per_operation},
        $row->{epoll_ctl_del_calls_per_operation},
        $row->{epoll_ctl_mod_ns_per_operation};
}

if (defined $json_path) {
    my $report = {
        benchmark => 'linux-event-stream-watcher-state',
        benchmark_contract_version => $contract_version,
        generated_at => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime),
        environment => environment_info(),
        configuration => {
            operations => $operations,
            pool => $pool_size,
            warmup => $warmup,
            repeats => $repeats,
            queue_bytes => $queue_bytes,
            send_buffer => $send_buffer,
            tls_pairs => $tls_pairs,
            timeout => $timeout,
            cases => \@cases,
            native_timing => JSON::PP::true,
        },
        records => \@records,
        summary => \@summary,
        notes => [
            'Loop profiling is enabled so epoll_ctl nanoseconds are diagnostic, not release-throughput numbers.',
            'watcher-read-toggle is the public native-registration floor for two real interest changes.',
            'xsstate-pause-toggle isolates two Stream XSState boundary calls without epoll changes.',
            'stream-pause-resume performs the public state and readiness transition pair.',
            'raw-register-cancel and stream-attach-detach reuse pre-created socketpairs.',
            'stream-half-close and stream-close time only terminal operations on pre-attached Streams.',
            'queued-write-drain prefills the send buffer, forces EAGAIN, and validates exact byte delivery.',
            'TLS rows count one client/server pair per operation and retain provider WANT counters.',
            'Compare reports only when contract, configuration, build, kernel, Perl, and host match.',
        ],
    };

    my $dir = dirname($json_path);
    make_path($dir) if $dir ne '.' && !-d $dir;
    open my $out, '>', $json_path or die "open $json_path: $!\n";
    print {$out} JSON::PP->new->canonical->pretty->encode($report);
    close $out or die "close $json_path: $!\n";
    say "\nWrote $json_path";
}

sub run_case ($case) {
    return run_watcher_read_toggle() if $case eq 'watcher-read-toggle';
    return run_xsstate_pause_toggle() if $case eq 'xsstate-pause-toggle';
    return run_stream_pause_resume() if $case eq 'stream-pause-resume';
    return run_lifecycle($case) if $case eq 'raw-register-cancel'
        || $case eq 'stream-attach-detach';
    return run_stream_half_close() if $case eq 'stream-half-close';
    return run_stream_close() if $case eq 'stream-close';
    return run_queued_write_drain() if $case eq 'queued-write-drain';
    return run_tls_handshake() if $case eq 'tls-handshake';
    return run_tls_shutdown() if $case eq 'tls-shutdown';
    die "unimplemented case: $case\n";
}

sub run_watcher_read_toggle () {
    my $loop = Linux::Event::Loop->new;
    my ($stream_fh, $peer_fh) = socket_pair();
    my $watcher = raw_registration($loop, $stream_fh);
    toggle_watcher($watcher, $warmup);
    my $row = measure('watcher-read-toggle', 'toggle-cycle', $operations,
        $loop, sub { toggle_watcher($watcher, $operations) });
    $watcher->cancel;
    close $stream_fh;
    close $peer_fh;
    return $row;
}

sub run_xsstate_pause_toggle () {
    my $loop = Linux::Event::Loop->new;
    my ($stream_fh, $peer_fh) = socket_pair();
    my $stream = Linux::Event::Bench::WatcherState::Stream->new(
        loop => $loop, fh => $stream_fh,
    );
    my $xs_state = $stream->{xs_state};
    toggle_xsstate($xs_state, $warmup);
    my $row = measure('xsstate-pause-toggle', 'toggle-cycle', $operations,
        $loop, sub { toggle_xsstate($xs_state, $operations) });
    my $detached = $stream->detach;
    close $detached;
    close $peer_fh;
    return $row;
}

sub run_stream_pause_resume () {
    my $loop = Linux::Event::Loop->new;
    my ($stream_fh, $peer_fh) = socket_pair();
    my $stream = Linux::Event::Bench::WatcherState::Stream->new(
        loop => $loop, fh => $stream_fh,
    );
    toggle_stream($stream, $warmup);
    my $row = measure('stream-pause-resume', 'toggle-cycle', $operations,
        $loop, sub { toggle_stream($stream, $operations) });
    my $detached = $stream->detach;
    close $detached;
    close $peer_fh;
    return $row;
}

sub run_lifecycle ($case) {
    my $loop = Linux::Event::Loop->new;
    my ($stream_fh, $peer_fh) = socket_pool($pool_size);
    lifecycle_many($case, $loop, $stream_fh, $warmup);
    my $row = measure($case, 'lifecycle', $operations, $loop,
        sub { lifecycle_many($case, $loop, $stream_fh, $operations) });
    close $_ for @$stream_fh;
    close $_ for @$peer_fh;
    return $row;
}

sub run_stream_half_close () {
    my $loop = Linux::Event::Loop->new;
    my ($stream_fh, $peer_fh) = socket_pool($pool_size);
    my @streams = map {
        Linux::Event::Bench::WatcherState::Stream->new(
            loop => $loop, fh => $_,
        )
    } @$stream_fh;
    my $row = measure('stream-half-close', 'stream', scalar(@streams),
        $loop, sub {
            $_->end for @streams;
            die "plain Stream half-close did not complete synchronously\n"
                if grep { !$_->is_write_ended } @streams;
        });
    close $_->detach for @streams;
    close $_ for @$peer_fh;
    return $row;
}

sub run_stream_close () {
    my $loop = Linux::Event::Loop->new;
    my ($stream_fh, $peer_fh) = socket_pool($pool_size);
    my @streams = map {
        Linux::Event::Bench::WatcherState::Stream->new(
            loop => $loop, fh => $_,
        )
    } @$stream_fh;
    my $row = measure('stream-close', 'stream', scalar(@streams),
        $loop, sub { $_->close for @streams });
    die "Stream close case left an object open\n"
        if grep { !$_->is_closed } @streams;
    close $_ for @$peer_fh;
    return $row;
}

sub run_queued_write_drain () {
    my $loop = Linux::Event::Loop->new;
    my (@streams, @peers);
    for my $i (0 .. $pool_size - 1) {
        my ($stream_fh, $peer_fh) = socket_pair(send_buffer => $send_buffer);
        push @streams, Linux::Event::Bench::WatcherState::Stream->new(
            loop => $loop, fh => $stream_fh,
        );
        push @peers, $peer_fh;
    }
    my $payload = 'x' x $queue_bytes;
    queue_many($loop, \@streams, \@peers, $payload, $warmup);
    my $before = sum_stream_stats(\@streams);
    my $row = measure('queued-write-drain', 'queue-cycle', $operations,
        $loop, sub {
            queue_many($loop, \@streams, \@peers, $payload, $operations);
        });
    my $after = sum_stream_stats(\@streams);
    add_extra_stats($row, 'stream', counter_delta($before, $after),
        scalar($operations));
    close $_->detach for @streams;
    close $_ for @peers;
    return $row;
}

sub run_tls_handshake () {
    my ($loop, $state, $spec) = tls_setup($tls_pairs);
    my (@clients, @servers);
    my $row = measure('tls-handshake', 'tls-pair', $tls_pairs, $loop, sub {
        for my $item (@$spec) {
            push @servers, Linux::Event::Bench::WatcherState::TLSStream->new(
                loop => $loop, fh => $item->{server_fh}, data => $state,
                transport => $item->{server_tls},
            );
            push @clients, Linux::Event::Bench::WatcherState::TLSStream->new(
                loop => $loop, fh => $item->{client_fh}, data => $state,
                transport => $item->{client_tls},
            );
        }
        drive_until($loop, $state,
            sub { $state->{ready} == $tls_pairs * 2 }, 'TLS handshake');
    });
    add_extra_stats($row, 'tls', sum_tls_stats($spec), $tls_pairs);
    $_->close for @clients, @servers;
    return $row;
}

sub run_tls_shutdown () {
    my ($loop, $state, $spec) = tls_setup($tls_pairs);
    my (@clients, @servers);
    for my $item (@$spec) {
        push @servers, Linux::Event::Bench::WatcherState::TLSStream->new(
            loop => $loop, fh => $item->{server_fh}, data => $state,
            transport => $item->{server_tls},
        );
        push @clients, Linux::Event::Bench::WatcherState::TLSStream->new(
            loop => $loop, fh => $item->{client_fh}, data => $state,
            transport => $item->{client_tls},
        );
    }
    drive_until($loop, $state,
        sub { $state->{ready} == $tls_pairs * 2 }, 'TLS setup handshake');
    my $before = sum_tls_stats($spec);
    my $row = measure('tls-shutdown', 'tls-pair', $tls_pairs, $loop, sub {
        $_->end for @clients;
        drive_until($loop, $state,
            sub { $state->{eof} == $tls_pairs }, 'TLS shutdown');
        die "TLS shutdown left a client write side open\n"
            if grep { !$_->is_write_ended } @clients;
    });
    my $after = sum_tls_stats($spec);
    add_extra_stats($row, 'tls', counter_delta($before, $after), $tls_pairs);
    $_->close for @clients, @servers;
    return $row;
}

sub measure ($case, $unit, $count, $loop, $code) {
    $loop->profile(1);
    $loop->reset_stats;
    my $wall_start = time;
    my $cpu_start = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
    $code->();
    my $cpu_seconds = clock_gettime(CLOCK_PROCESS_CPUTIME_ID) - $cpu_start;
    my $elapsed_seconds = time - $wall_start;
    die "timer produced a non-positive interval for $case\n"
        if $elapsed_seconds <= 0;

    my $stats = $loop->stats;
    my $row = {
        benchmark_contract_version => $contract_version,
        case => $case,
        operation_unit => $unit,
        operations => $count,
        elapsed_seconds => $elapsed_seconds,
        cpu_seconds => $cpu_seconds,
        operations_per_second => $count / $elapsed_seconds,
        cpu_us_per_operation => ($cpu_seconds * 1_000_000) / $count,
        loop_stats => {
            map { $_ => 0 + $stats->{$_} } loop_stat_keys()
        },
    };
    for my $key (loop_stat_keys()) {
        $row->{"${key}_per_operation"} = $stats->{$key} / $count;
    }
    return $row;
}

sub raw_registration ($loop, $fh) {
    my $watcher = $loop->watch_fd(
        fileno($fh),
        fh => $fh,
        data => {},
        read => \&_watch_ready,
        write => \&_watch_ready,
        error => \&_watch_ready,
        _callback_data_arg => 1,
    );
    $watcher->disable_write;
    return $watcher;
}

sub _watch_ready ($data) { return }

sub toggle_watcher ($watcher, $count) {
    for (1 .. $count) {
        $watcher->disable_read;
        $watcher->enable_read;
    }
}

sub toggle_xsstate ($xs_state, $count) {
    for (1 .. $count) {
        $xs_state->_pause;
        $xs_state->_resume;
    }
}

sub toggle_stream ($stream, $count) {
    for (1 .. $count) {
        $stream->pause_read;
        $stream->resume_read;
    }
}

sub lifecycle_many ($case, $loop, $stream_fh, $count) {
    for my $i (0 .. $count - 1) {
        my $fh = $stream_fh->[$i % @$stream_fh];
        if ($case eq 'raw-register-cancel') {
            raw_registration($loop, $fh)->cancel;
            next;
        }
        my $stream = Linux::Event::Bench::WatcherState::Stream->new(fh => $fh);
        $loop->add($stream);
        my $detached = $stream->detach;
        die "detach returned the wrong filehandle\n"
            if fileno($detached) != fileno($fh);
    }
}

sub queue_many ($loop, $streams, $peers, $payload, $count) {
    for my $i (0 .. $count - 1) {
        queue_once($loop, $streams->[$i % @$streams],
            $peers->[$i % @$peers], $payload);
    }
}

sub queue_once ($loop, $stream, $peer, $payload) {
    die "queue cycle began with pending output\n" if $stream->pending_bytes;
    my $prefilled = fill_send_buffer($stream->fh);
    $stream->write($payload);
    die "prefilled send buffer did not force queued output\n"
        if !$stream->pending_bytes;

    my $received = drain_peer($peer);
    my $turns = 0;
    while ($stream->pending_bytes) {
        die "queued write did not drain after 1000 Loop turns\n"
            if ++$turns > 1_000;
        my $ready = $loop->run_once(1_000);
        die "queued write timed out waiting for writable readiness\n"
            if !$ready;
        $received += drain_peer($peer);
    }
    $received += drain_peer($peer);
    my $expected = $prefilled + length($payload);
    die "queued write delivered $received bytes, expected $expected\n"
        if $received != $expected;
}

sub fill_send_buffer ($fh) {
    state $filler = 'f' x 65_536;
    my $total = 0;
    while (1) {
        my $written = syswrite($fh, $filler);
        if (defined $written) {
            die "send-buffer prefill made no progress\n" if $written == 0;
            $total += $written;
            next;
        }
        next if $! == EINTR;
        return $total if $! == EAGAIN || $! == EWOULDBLOCK;
        die "send-buffer prefill syswrite: $!\n";
    }
}

sub drain_peer ($fh) {
    my $total = 0;
    while (1) {
        my $read = sysread($fh, my $buffer, 65_536);
        if (defined $read) {
            die "queued write peer reached EOF\n" if $read == 0;
            $total += $read;
            next;
        }
        next if $! == EINTR;
        return $total if $! == EAGAIN || $! == EWOULDBLOCK;
        die "queued write peer sysread: $!\n";
    }
}

sub tls_setup ($count) {
    my $loop = Linux::Event::Loop->new;
    my $state = { ready => 0, eof => 0 };
    my @spec;
    for my $i (0 .. $count - 1) {
        my ($client_fh, $server_fh) = socket_pair();
        push @spec, {
            client_fh => $client_fh,
            server_fh => $server_fh,
            client_tls => Linux::Event::TLS->client(
                server_name => 'localhost', ca_file => $cert_file,
            ),
            server_tls => Linux::Event::TLS->server(
                cert_file => $cert_file, key_file => $key_file,
            ),
        };
    }
    return ($loop, $state, \@spec);
}

sub drive_until ($loop, $state, $done, $label) {
    my $deadline = time + $timeout;
    while (!$done->()) {
        die "$label failed: $state->{error}\n" if defined $state->{error};
        die "$label exceeded ${timeout}s\n" if time >= $deadline;
        $loop->run_once(100);
    }
}

sub socket_pool ($count) {
    my (@stream_fh, @peer_fh);
    for my $i (0 .. $count - 1) {
        my ($stream, $peer) = socket_pair();
        push @stream_fh, $stream;
        push @peer_fh, $peer;
    }
    return (\@stream_fh, \@peer_fh);
}

sub socket_pair (%opt) {
    socketpair(my $stream, my $peer, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
        or die "socketpair: $!";
    prepare_fh($stream);
    prepare_fh($peer);
    if (defined $opt{send_buffer}) {
        setsockopt($stream, SOL_SOCKET, SO_SNDBUF,
            pack('i', $opt{send_buffer}))
            or die "setsockopt(SO_SNDBUF): $!\n";
    }
    return ($stream, $peer);
}

sub prepare_fh ($fh) {
    my $status = fcntl($fh, F_GETFL, 0);
    die "fcntl(F_GETFL): $!\n" if !defined $status;
    fcntl($fh, F_SETFL, $status | O_NONBLOCK)
        or die "fcntl(F_SETFL): $!\n";
    my $descriptor = fcntl($fh, F_GETFD, 0);
    die "fcntl(F_GETFD): $!\n" if !defined $descriptor;
    fcntl($fh, F_SETFD, $descriptor | FD_CLOEXEC)
        or die "fcntl(F_SETFD): $!\n";
}

sub loop_stat_keys () {
    return qw(
        epoll_wait_calls ready_events_returned callback_calls
        epoll_ctl_add_calls epoll_ctl_mod_calls epoll_ctl_del_calls
        epoll_wait_ns epoll_ctl_add_ns epoll_ctl_mod_ns epoll_ctl_del_ns
        dispatch_ns
    );
}

sub sum_stream_stats ($streams) {
    my %sum;
    for my $stream (@$streams) {
        my $stats = $stream->{xs_state}->stats;
        $sum{$_} += $stats->{$_} for qw(
            write_submit_calls write_ready_calls write_calls writev_calls
            write_eagain_count empty_calls bytes_written
        );
    }
    return \%sum;
}

sub sum_tls_stats ($spec) {
    my %sum;
    for my $item (@$spec) {
        for my $tls ($item->{client_tls}, $item->{server_tls}) {
            my $stats = $tls->stats;
            $sum{$_} += $stats->{$_} for qw(
                handshake_calls handshake_successes read_calls write_calls
                writev_calls shutdown_calls want_read_count want_write_count
                interrupt_count error_count clean_eof_count unclean_eof_count
            );
        }
    }
    return \%sum;
}

sub counter_delta ($before, $after) {
    return { map { $_ => ($after->{$_} // 0) - ($before->{$_} // 0) }
        keys %$after };
}

sub add_extra_stats ($row, $name, $stats, $count) {
    $row->{"${name}_stats"} = $stats;
    $row->{"${name}_stats_per_operation"} = {
        map { $_ => $stats->{$_} / $count } keys %$stats
    };
}

sub rotated_cases ($repeat) {
    my $shift = ($repeat - 1) % @cases;
    return (@cases[$shift .. $#cases], @cases[0 .. $shift - 1]);
}

sub median (@values) {
    die "median requires at least one value\n" if !@values;
    @values = sort { $a <=> $b } @values;
    my $middle = int(@values / 2);
    return $values[$middle] if @values % 2;
    return ($values[$middle - 1] + $values[$middle]) / 2;
}

sub environment_info () {
    my ($sysname, $nodename, $release, $version, $machine) = uname();
    return {
        linux_event_version => $Linux::Event::IO::Sock::Stream::VERSION,
        perl_version => "$^V",
        perl_executable => $^X,
        os => $^O,
        uname => {
            sysname => $sysname,
            release => $release,
            version => $version,
            machine => $machine,
        },
        git_commit => git_commit(),
    };
}

sub git_commit () {
    return undef if !-e "$Bin/../.git";
    open my $git, '-|', 'git', '-C', "$Bin/..", 'rev-parse', 'HEAD'
        or return undef;
    my $commit = <$git>;
    my $ok = close $git;
    return undef if !$ok || !defined $commit;
    chomp $commit;
    return $commit;
}

sub usage ($status) {
    my $fh = $status ? *STDERR : *STDOUT;
    print {$fh} <<'USAGE';
Usage: perl -Mblib bench/run-stream-watcher-state-bench.pl [options]

  --operations=N       operations for toggle/lifecycle/queue cases (default 10000)
  --pool=N             reusable or pre-attached plain Streams (default 256)
  --warmup=N           untimed operations for reusable cases (default 1000)
  --repeats=N          repeats per case (default 7)
  --queue-bytes=N      bytes submitted per forced queue cycle (default 12288)
  --send-buffer=N      requested queue-case SO_SNDBUF bytes (default 4096)
  --tls-pairs=N        client/server pairs in each TLS row (default 64)
  --timeout=N          catastrophic TLS timeout in seconds (default 10)
  --cases=A,B          comma-separated watcher-state cases
  --cert-file=PATH     TLS localhost certificate
  --key-file=PATH      TLS private key
  --json=PATH          write raw records and summaries as JSON
  --help               show this help

Cases:
  watcher-read-toggle, xsstate-pause-toggle, stream-pause-resume,
  raw-register-cancel, stream-attach-detach, stream-half-close,
  stream-close, queued-write-drain, tls-handshake, tls-shutdown
USAGE
    exit $status;
}
