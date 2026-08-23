#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use IO::Socket::INET;
use IO::Poll qw(POLLIN POLLOUT POLLERR POLLHUP);
use IO::Select;
use Time::HiRes qw(time usleep);
use POSIX qw(:sys_wait_h);
use Getopt::Long qw(GetOptions);
use JSON::PP qw(encode_json decode_json);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use lib "$Bin/../blib/lib", "$Bin/../blib/arch", "$Bin/../lib";

my $systems = 'native,native-empty,perl';
my $clients = '1000,5000,10000';
my $messages = 10;
my $warmup = 1;
my $bytes = 64;
my $host = '127.0.0.1';
my $timeout = 90;
my $repeats = 5;
my $client_workers = 4;
my $build = 0;
my $out = 'bench/results/callback-ceiling.html';
my $json_out = 'bench/results/callback-ceiling.json';

GetOptions(
    'systems=s' => \$systems,
    'clients=s' => \$clients,
    'messages=i' => \$messages,
    'warmup=i' => \$warmup,
    'bytes=i' => \$bytes,
    'timeout=f' => \$timeout,
    'repeats=i' => \$repeats,
    'client-workers=i' => \$client_workers,
    'build!' => \$build,
    'out=s' => \$out,
    'json=s' => \$json_out,
) or die usage();

my @systems = grep length, split /,/, $systems;
my @clients = map { int($_) } grep length, split /,/, $clients;
die "unknown callback-ceiling system\n" if grep { $_ ne 'native' && $_ ne 'native-empty' && $_ ne 'perl' } @systems;
die "messages must be > 0\n" unless $messages > 0;
die "warmup must be >= 0\n" unless $warmup >= 0;
die "bytes must be > 0\n" unless $bytes > 0;
die "repeats must be > 0\n" unless $repeats > 0;
die "client-workers must be > 0\n" unless $client_workers > 0;

if ($build) {
    system($^X, 'Makefile.PL') == 0 or die "Makefile.PL failed\n";
    system('make') == 0 or die "make failed\n";
}

my @results;
for my $system (@systems) {
    for my $count (@clients) {
        for my $repeat (1 .. $repeats) {
            warn "== $system clients=$count repeat=$repeat ==\n";
            my $result = eval { run_case_isolated($system, $count, $repeat) };
            if (!$result) {
                my $err = $@ || 'unknown case error';
                chomp $err;
                $result = {
                    system => display_system($system),
                    system_key => $system,
                    clients => $count,
                    messages => $count * $messages,
                    messages_per_client => $messages,
                    warmup_per_client => $warmup,
                    bytes => $bytes,
                    client_workers => $client_workers,
                    repeat => $repeat,
                    ok => JSON::PP::false,
                    rankable => JSON::PP::false,
                    failure_reason => $err,
                    messages_per_second => undef,
                };
                warn "FAILED: $err\n";
            }
            push @results, $result;
        }
    }
}

my @summary = summarize(\@results);
write_json($json_out, { results => \@results, summary => \@summary });
write_html($out, \@results, \@summary);
print "wrote $json_out\n";
print "wrote $out\n";

sub usage {
    return <<'USAGE';
Usage:
  perl bench/run-callback-ceiling.pl --build \
    --systems native,native-empty,perl \
    --clients 1000,5000,10000,15000,20000 \
    --warmup 1 --messages 10 --bytes 64 \
    --client-workers 4 --repeats 5 --timeout 90 \
    --out bench/results/callback-ceiling.html \
    --json bench/results/callback-ceiling.json

This diagnostic pre-connects and accepts all TCP clients before timing begins, resets
XS statistics, then releases all client workers into the unchanged serial
request/reply echo protocol.

A (native XS echo):
  native XS read/write echo, no Perl client read callback
B (native echo + empty Perl callback):
  same native XS echo plus an empty Perl client read callback
C (normal Perl echo body):
  normal Perl echo callback

B-A estimates Perl read-callback entry cost.
C-B estimates the added cost of Perl-side echo I/O/accounting versus XS.
USAGE
}

sub run_case_isolated ($system, $count, $repeat) {
    pipe(my $read_fh, my $write_fh) or die "case pipe failed: $!";
    my $pid = fork();
    die "case fork failed: $!" unless defined $pid;

    if ($pid == 0) {
        close $read_fh;
        $SIG{PIPE} = 'IGNORE';
        my $payload;
        my $ok = eval {
            my $result = run_case($system, $count, $repeat);
            $payload = encode_json({ worker_ok => JSON::PP::true, result => $result });
            1;
        };
        if (!$ok) {
            my $err = $@ || 'unknown worker error';
            chomp $err;
            $payload = encode_json({ worker_ok => JSON::PP::false, error => $err });
        }
        print {$write_fh} $payload;
        close $write_fh;
        exit($ok ? 0 : 1);
    }

    close $write_fh;
    my $guard = $timeout + 180 + int($count / 500);
    my $select = IO::Select->new($read_fh);
    if (!$select->can_read($guard)) {
        kill 'TERM', $pid;
        usleep(100_000);
        kill 'KILL', $pid if kill 0, $pid;
        waitpid($pid, 0);
        close $read_fh;
        die "case worker exceeded external timeout (${guard}s)\n";
    }

    local $/;
    my $txt = <$read_fh>;
    close $read_fh;
    waitpid($pid, 0);

    die "case worker produced no result\n" unless defined $txt && length $txt;
    my $envelope = decode_json($txt);
    die (($envelope->{error} || 'case worker failed') . "\n") unless $envelope->{worker_ok};
    return $envelope->{result};
}

sub run_case ($system, $count, $repeat) {
    require Linux::Event::Loop;

    my $server = IO::Socket::INET->new(
        LocalAddr => $host,
        LocalPort => 0,
        Proto => 'tcp',
        Listen => 8192,
        ReuseAddr => 1,
    ) or die "listen failed: $!";
    $server->blocking(0);
    my $port = $server->sockport;

    my $tmp = tempdir(CLEANUP => 1);
    my $message_gate = "$tmp/messages-go";
    my @ready_files;
    my @client_files;
    my @pids;
    my $msg = 'x' x $bytes;

    my $workers = $client_workers > $count ? $count : $client_workers;
    my $base = int($count / $workers);
    my $extra = $count % $workers;
    for my $worker (1 .. $workers) {
        my $worker_clients = $base + ($worker <= $extra ? 1 : 0);
        my $ready = "$tmp/ready-$worker";
        my $result = "$tmp/client-$worker.json";
        push @ready_files, $ready;
        push @client_files, $result;
        my $pid = fork();
        die "client worker fork failed: $!" unless defined $pid;
        if ($pid == 0) {
            $SIG{PIPE} = 'IGNORE';
            $SIG{TERM} = sub { exit 143 };
            ceiling_client_worker($port, $worker_clients, $msg, $ready, $message_gate, $result);
            exit 0;
        }
        push @pids, $pid;
    }

    my $loop = Linux::Event::Loop->new;
    $loop->set_callback_scope_limit(128);
    my %c = (
        accepted => 0,
        closed => 0,
        error_callbacks => 0,
        read_callbacks => 0,
        sysread_calls => 0,
        syswrite_calls => 0,
        read_eagain => 0,
        write_eagain => 0,
        partial_writes => 0,
        close_reads => 0,
        bytes_read => 0,
        bytes_written => 0,
        echoed_bytes => 0,
    );

    my $empty_cb = sub { };
    my $server_w;
    $server_w = $loop->watch(
        fh => $server,
        no_args => 1,
        lean => 1,
        read => sub {
            while (my $sock = $server->accept) {
                $c{accepted}++;
                $sock->blocking(0);
                my $cw;
                my $on_error = sub {
                    $c{error_callbacks}++;
                    $c{closed}++;
                    $cw->cancel;
                    close $sock;
                };

                if ($system eq 'native') {
                    $cw = $loop->watch(
                        fh => $sock,
                        no_args => 1,
                        lean => 1,
                        _bench_native_echo => 1,
                        error => $on_error,
                    );
                }
                elsif ($system eq 'native-empty') {
                    $cw = $loop->watch(
                        fh => $sock,
                        no_args => 1,
                        lean => 1,
                        _bench_native_echo => 2,
                        read => $empty_cb,
                        error => $on_error,
                    );
                }
                else {
                    $cw = $loop->watch(
                        fh => $sock,
                        no_args => 1,
                        lean => 1,
                        read => sub {
                            echo_read($sock, \%c, sub {
                                $cw->cancel;
                                close $sock;
                            });
                        },
                        error => $on_error,
                    );
                }
            }
        },
    );

    my $setup_deadline = time + $timeout + 120;
    while ($c{accepted} < $count && time < $setup_deadline) {
        $loop->run_once(100);
    }
    die "setup accepted=$c{accepted}/$count\n" if $c{accepted} != $count;

    while (time < $setup_deadline) {
        last if !grep { !-e $_ } @ready_files;
        usleep(1000);
    }
    die "client workers did not reach ready barrier\n" if grep { !-e $_ } @ready_files;

    $loop->reset_stats;
    my $cs_before = context_switches();
    my @times_before = times();
    my $start = time;
    open my $gate, '>', $message_gate or die "open message gate: $!";
    print {$gate} "go\n";
    close $gate;

    my $deadline = $start + $timeout;
    while ($c{closed} < $count && time < $deadline) {
        $loop->run_once(1000);
    }
    my $elapsed = time - $start;
    my @times_after = times();
    my $cs_after = context_switches();

    my $st = $loop->stats;
    if ($system eq 'native' || $system eq 'native-empty') {
        $c{echoed_bytes} = $st->{bench_native_echo_bytes_written} // 0;
        $c{bytes_read} = $st->{bench_native_echo_bytes_read} // 0;
        $c{bytes_written} = $st->{bench_native_echo_bytes_written} // 0;
        $c{sysread_calls} = $st->{bench_native_echo_sysread_calls} // 0;
        $c{syswrite_calls} = $st->{bench_native_echo_syswrite_calls} // 0;
        $c{read_eagain} = $st->{bench_native_echo_read_eagain} // 0;
        $c{write_eagain} = $st->{bench_native_echo_write_eagain} // 0;
        $c{partial_writes} = $st->{bench_native_echo_partial_writes} // 0;
        $c{close_reads} = $st->{bench_native_echo_read_zero} // 0;
    }

    my @client_results;
    my $client_failures = 0;
    for my $pid (@pids) {
        my $wait_deadline = time + 30;
        while (time < $wait_deadline) {
            my $wp = waitpid($pid, WNOHANG);
            last if $wp == $pid || $wp == -1;
            usleep(10_000);
        }
        if (kill 0, $pid) {
            $client_failures++;
            kill 'TERM', $pid;
            waitpid($pid, 0);
        }
    }

    for my $file (@client_files) {
        if (!-e $file) {
            $client_failures++;
            next;
        }
        open my $fh, '<', $file or do { $client_failures++; next; };
        local $/;
        my $cr = eval { decode_json(<$fh>) };
        close $fh;
        if (!$cr || !$cr->{ok}) {
            $client_failures++;
            next;
        }
        push @client_results, $cr;
    }

    my @lat;
    my $client_measured = 0;
    for my $cr (@client_results) {
        $client_measured += $cr->{measured_messages} // 0;
        push @lat, @{ $cr->{latency_us} || [] };
    }
    @lat = sort { $a <=> $b } @lat;

    my $total_messages = $count * $messages;
    my $expected_bytes = $count * ($messages + $warmup) * $bytes;
    my $timed_out = $c{closed} < $count ? 1 : 0;
    my $ok = !$timed_out
        && !$client_failures
        && $c{accepted} == $count
        && $c{closed} == $count
        && $c{echoed_bytes} >= $expected_bytes
        && $client_measured == $total_messages;

    my $user_cpu = $times_after[0] - $times_before[0];
    my $sys_cpu = $times_after[1] - $times_before[1];
    my %result = (
        system => display_system($system),
        system_key => $system,
        clients => $count,
        messages => $total_messages,
        messages_per_client => $messages,
        warmup_messages => $count * $warmup,
        warmup_per_client => $warmup,
        bytes => $bytes,
        client_workers => $workers,
        repeat => $repeat,
        preconnected => JSON::PP::true,
        elapsed_seconds => num($elapsed),
        messages_per_second => $ok ? num($total_messages / $elapsed) : undef,
        attempt_messages_per_second => num($total_messages / $elapsed),
        mib_per_second => $ok ? num((($total_messages * $bytes) / 1048576) / $elapsed) : undef,
        ok => $ok ? JSON::PP::true : JSON::PP::false,
        rankable => $ok ? JSON::PP::true : JSON::PP::false,
        failure_reason => $ok ? undef : join('; ', grep length,
            ($timed_out ? 'server timeout' : ''),
            ($client_failures ? "client failures=$client_failures" : ''),
            ($c{closed} != $count ? "closed=$c{closed}/$count" : ''),
            ($c{echoed_bytes} < $expected_bytes ? "echoed_bytes=$c{echoed_bytes}/$expected_bytes" : ''),
            ($client_measured != $total_messages ? "client_measured=$client_measured/$total_messages" : ''),
        ),
        client_failures => $client_failures,
        client_measured_messages => $client_measured,
        lat_p50_us => pct(\@lat, 50),
        lat_p95_us => pct(\@lat, 95),
        lat_p99_us => pct(\@lat, 99),
        lat_max_us => @lat ? $lat[-1] : undef,
        perl_version => "$^V",
        linux_kernel => scalar(`uname -r`) =~ s/\s+\z//r,
        max_rss_kb => max_rss_kb(),
        server_user_cpu_seconds => num($user_cpu),
        server_system_cpu_seconds => num($sys_cpu),
        server_total_cpu_seconds => num($user_cpu + $sys_cpu),
        server_cpu_percent => $elapsed > 0 ? num((($user_cpu + $sys_cpu) / $elapsed) * 100) : 0,
        voluntary_ctxt_switches => ($cs_after->{voluntary} // 0) - ($cs_before->{voluntary} // 0),
        nonvoluntary_ctxt_switches => ($cs_after->{nonvoluntary} // 0) - ($cs_before->{nonvoluntary} // 0),
        %c,
    );

    for my $key (qw(
        event_capacity epoll_wait_calls epoll_wait_empty_calls epoll_wait_full_batches epoll_wait_max_batch
        ready_events_returned ready_read_events ready_write_events ready_error_events ready_epollerr_events
        ready_hup_events ready_rdhup_events ready_in_hup_events ready_in_rdhup_events ready_multi_events
        callback_calls read_callback_calls write_callback_calls error_callback_calls direct_watcher_events dispatch_events
        callback_noarg_calls callback_onearg_calls callback_direct_cv_calls callback_sv_calls
        callback_batch_scope_enters callback_scope_rotations callback_scope_max_callbacks callback_scope_limit
        run_once_calls run_calls run_for_calls
        bench_native_echo_read_events bench_native_echo_perl_read_callbacks bench_native_echo_sysread_calls
        bench_native_echo_syswrite_calls bench_native_echo_bytes_read bench_native_echo_bytes_written
        bench_native_echo_read_eagain bench_native_echo_write_eagain bench_native_echo_partial_writes
        bench_native_echo_read_zero bench_native_echo_errors
    )) {
        $result{$key} = $st->{$key} if exists $st->{$key};
    }

    return \%result;
}

sub ceiling_client_worker ($port, $count, $msg, $ready_file, $message_gate, $out_file) {
    my $poll = IO::Poll->new;
    my %state;
    my $connected = 0;
    my $finished = 0;
    my $failed = 0;
    my @lat;
    my $total_per_client = $warmup + $messages;

    for my $id (1 .. $count) {
        my $sock;
        for (1 .. 5000) {
            $sock = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp');
            last if $sock;
            usleep(1000);
        }
        if (!$sock) {
            $failed++;
            next;
        }
        $sock->blocking(0);
        my $fd = fileno($sock);
        $state{$fd} = {
            sock => $sock,
            sent => 0,
            recv_len => 0,
            write_off => 0,
            write_active => 0,
            awaiting_reply => 0,
            lat_start => undef,
        };
        $poll->mask($sock => POLLIN | POLLERR | POLLHUP);
        $connected++;
    }

    open my $ready, '>', $ready_file or die "write ready file: $!";
    print {$ready} "$connected\n";
    close $ready;

    until (-e $message_gate) { usleep(100); }
    my $deadline = time + $timeout + 30;

    for my $st (values %state) {
        queue_next_message($poll, $st);
    }

    while (%state && time < $deadline) {
        my $nready = $poll->poll(0.05);
        next unless $nready;
        for my $fh ($poll->handles(POLLERR | POLLHUP | POLLIN | POLLOUT)) {
            my $fd = fileno($fh);
            my $st = $state{$fd} or next;
            my $ev = $poll->events($fh);

            if (($ev & (POLLERR | POLLHUP)) && !($ev & POLLIN)) {
                $failed++;
                $poll->remove($fh);
                delete $state{$fd};
                close $fh;
                next;
            }

            if (($ev & POLLOUT) && $st->{write_active}) {
                my $remain = $bytes - $st->{write_off};
                my $wr = syswrite($fh, $msg, $remain, $st->{write_off});
                if (defined $wr && $wr > 0) {
                    $st->{write_off} += $wr;
                    if ($st->{write_off} >= $bytes) {
                        $st->{write_active} = 0;
                        $st->{awaiting_reply} = 1;
                        $st->{write_off} = 0;
                    }
                }
                elsif (!defined $wr && ($!{EAGAIN} || $!{EWOULDBLOCK})) {
                }
                else {
                    $failed++;
                    $poll->remove($fh);
                    delete $state{$fd};
                    close $fh;
                    next;
                }
            }

            if (($ev & POLLIN) && exists $state{$fd}) {
                while ($st->{recv_len} < $bytes) {
                    my $need = $bytes - $st->{recv_len};
                    my $rd = sysread($fh, my $buf, $need > 8192 ? 8192 : $need);
                    if (defined $rd && $rd > 0) {
                        $st->{recv_len} += $rd;
                        next;
                    }
                    if (!defined $rd && ($!{EAGAIN} || $!{EWOULDBLOCK})) {
                        last;
                    }
                    $failed++;
                    $poll->remove($fh);
                    delete $state{$fd};
                    close $fh;
                    last;
                }
                next unless exists $state{$fd};

                if ($st->{recv_len} >= $bytes) {
                    if ($st->{sent} > $warmup && defined $st->{lat_start}) {
                        push @lat, int((time - $st->{lat_start}) * 1_000_000 + 0.5);
                    }
                    $st->{recv_len} = 0;
                    $st->{awaiting_reply} = 0;
                    if ($st->{sent} >= $total_per_client) {
                        $finished++;
                        $poll->remove($fh);
                        delete $state{$fd};
                        close $fh;
                        next;
                    }
                    queue_next_message($poll, $st);
                }
            }

            next unless exists $state{$fd};
            my $mask = POLLIN | POLLERR | POLLHUP;
            $mask |= POLLOUT if $st->{write_active};
            $poll->mask($fh => $mask);
        }
    }

    if (%state) {
        $failed += scalar keys %state;
        close $_->{sock} for values %state;
        %state = ();
    }

    my $ok = $failed == 0 && $finished == $connected && $connected == $count;
    open my $out, '>', $out_file or die "write client result: $!";
    print {$out} encode_json({
        ok => $ok ? JSON::PP::true : JSON::PP::false,
        connected_clients => $connected,
        finished_clients => $finished,
        failed_clients => $failed,
        measured_messages => $ok ? $count * $messages : $finished * $messages,
        latency_us => \@lat,
    });
    close $out;
    exit($ok ? 0 : 1);
}

sub queue_next_message ($poll, $st) {
    $st->{sent}++;
    $st->{lat_start} = $st->{sent} > $warmup ? time : undef;
    $st->{write_active} = 1;
    $st->{write_off} = 0;
    my $fh = $st->{sock};
    $poll->mask($fh => POLLIN | POLLOUT | POLLERR | POLLHUP);
}

sub echo_read ($fh, $c, $on_close) {
    $c->{read_callbacks}++;
    while (1) {
        $c->{sysread_calls}++;
        my $n = sysread($fh, my $buf, 8192);
        if (defined $n && $n > 0) {
            $c->{bytes_read} += $n;
            $c->{echoed_bytes} += $n;
            my $off = 0;
            my $len = length($buf);
            while ($off < $len) {
                $c->{syswrite_calls}++;
                my $wr = syswrite($fh, $buf, $len - $off, $off);
                if (defined $wr && $wr > 0) {
                    $c->{bytes_written} += $wr;
                    $c->{partial_writes}++ if $wr < ($len - $off);
                    $off += $wr;
                    next;
                }
                if (!defined $wr && ($!{EAGAIN} || $!{EWOULDBLOCK})) {
                    $c->{write_eagain}++;
                    last;
                }
                last;
            }
            next;
        }
        if (defined $n && $n == 0) {
            $c->{close_reads}++;
            $c->{closed}++;
            $on_close->();
            last;
        }
        if (!defined $n && ($!{EAGAIN} || $!{EWOULDBLOCK})) {
            $c->{read_eagain}++;
            last;
        }
        $c->{error_callbacks}++;
        $c->{closed}++;
        $on_close->();
        last;
    }
}

sub display_system ($system) {
    return 'A: XS native echo, no Perl client read callback' if $system eq 'native';
    return 'B: XS native echo plus empty Perl client read callback' if $system eq 'native-empty';
    return 'C: normal Perl echo callback';
}

sub summarize ($results) {
    my @summary;
    for my $system ('native', 'native-empty', 'perl') {
        for my $count (@clients) {
            my @r = grep { $_->{system_key} eq $system && $_->{clients} == $count && $_->{ok} } @$results;
            next unless @r;
            push @summary, {
                system => display_system($system),
                system_key => $system,
                clients => $count,
                repeats => scalar @r,
                median_messages_per_second => median(map { $_->{messages_per_second} } @r),
                median_elapsed_seconds => median(map { $_->{elapsed_seconds} } @r),
                median_lat_p50_us => median(grep { defined } map { $_->{lat_p50_us} } @r),
                median_lat_p99_us => median(grep { defined } map { $_->{lat_p99_us} } @r),
                median_server_cpu_percent => median(map { $_->{server_cpu_percent} } @r),
                median_callback_calls => median(map { $_->{callback_calls} // 0 } @r),
                median_bench_perl_read_callbacks => median(map { $_->{bench_native_echo_perl_read_callbacks} // 0 } @r),
            };
        }
    }
    return @summary;
}

sub median (@values) {
    return undef unless @values;
    @values = sort { $a <=> $b } @values;
    my $n = @values;
    return $values[int($n / 2)] if $n % 2;
    return ($values[$n / 2 - 1] + $values[$n / 2]) / 2;
}

sub pct ($arr, $p) {
    return undef unless @$arr;
    my $idx = int((@$arr - 1) * ($p / 100));
    return $arr->[$idx];
}

sub num ($value) {
    return 0 + sprintf('%.6f', $value);
}

sub max_rss_kb {
    return 0 unless -r '/proc/self/status';
    open my $fh, '<', '/proc/self/status' or return 0;
    while (<$fh>) {
        return 0 + $1 if /^VmHWM:\s+(\d+)\s+kB/;
    }
    return 0;
}

sub context_switches {
    my %r = (voluntary => 0, nonvoluntary => 0);
    return \%r unless -r '/proc/self/status';
    open my $fh, '<', '/proc/self/status' or return \%r;
    while (<$fh>) {
        $r{voluntary} = 0 + $1 if /^voluntary_ctxt_switches:\s+(\d+)/;
        $r{nonvoluntary} = 0 + $1 if /^nonvoluntary_ctxt_switches:\s+(\d+)/;
    }
    return \%r;
}

sub write_json ($path, $data) {
    if ($path =~ m{^(.+)/[^/]+$}) {
        make_path($1) unless -d $1;
    }
    open my $fh, '>', $path or die "write $path: $!";
    print {$fh} JSON::PP->new->canonical(1)->pretty(1)->encode($data);
    close $fh;
}

sub write_html ($path, $results, $summary) {
    if ($path =~ m{^(.+)/[^/]+$}) {
        make_path($1) unless -d $1;
    }
    open my $fh, '>', $path or die "write $path: $!";
    print {$fh} <<'HTML';
<!doctype html>
<html><head><meta charset="utf-8"><title>Linux::Event callback/I/O ceiling diagnostic</title>
<style>
body{font-family:system-ui,sans-serif;margin:2rem;line-height:1.35}table{border-collapse:collapse;width:100%;margin:1rem 0 2rem}th,td{border:1px solid #ccc;padding:.4rem .55rem;text-align:right}th:first-child,td:first-child{text-align:left}th{background:#f2f2f2}.note{background:#f6f8fa;border:1px solid #d0d7de;border-radius:8px;padding:1rem}
</style></head><body>
<h1>Linux::Event callback/I/O ceiling diagnostic</h1>
<div class="note">All clients are connected and accepted before timing. XS stats are reset before the message gate opens. A is native XS echo without a Perl client read callback; B adds an empty Perl client read callback before the identical native echo; C is the normal Perl echo path. B-A estimates callback entry overhead; C-B estimates Perl-side echo/I/O overhead.</div>
<h2>Median summary</h2><table><thead><tr><th>System</th><th>Clients</th><th>Repeats</th><th>msg/s</th><th>p50 us</th><th>p99 us</th><th>CPU %</th><th>callbacks</th><th>empty-read callbacks</th></tr></thead><tbody>
HTML
    for my $r (@$summary) {
        printf {$fh} "<tr><td>%s</td><td>%d</td><td>%d</td><td>%.2f</td><td>%.0f</td><td>%.0f</td><td>%.2f</td><td>%.0f</td><td>%.0f</td></tr>\n",
            $r->{system}, $r->{clients}, $r->{repeats}, $r->{median_messages_per_second},
            ($r->{median_lat_p50_us} // 0), ($r->{median_lat_p99_us} // 0),
            $r->{median_server_cpu_percent}, $r->{median_callback_calls},
            $r->{median_bench_perl_read_callbacks};
    }
    print {$fh} "</tbody></table><h2>Raw repeats</h2><table><thead><tr><th>System</th><th>Clients</th><th>Repeat</th><th>OK</th><th>msg/s</th><th>elapsed s</th><th>p50 us</th><th>p99 us</th><th>CPU %</th><th>epoll waits</th><th>callbacks</th><th>empty read callbacks</th></tr></thead><tbody>\n";
    for my $r (@$results) {
        printf {$fh} "<tr><td>%s</td><td>%d</td><td>%d</td><td>%s</td><td>%s</td><td>%.6f</td><td>%s</td><td>%s</td><td>%.2f</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",
            $r->{system}, $r->{clients}, $r->{repeat}, ($r->{ok} ? 'yes' : 'no'),
            (defined $r->{messages_per_second} ? sprintf('%.2f', $r->{messages_per_second}) : ''),
            ($r->{elapsed_seconds} // 0), ($r->{lat_p50_us} // ''), ($r->{lat_p99_us} // ''),
            ($r->{server_cpu_percent} // 0), ($r->{epoll_wait_calls} // ''), ($r->{callback_calls} // ''),
            ($r->{bench_native_echo_perl_read_callbacks} // '');
    }
    print {$fh} "</tbody></table></body></html>\n";
    close $fh;
}
