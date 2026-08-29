#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use IO::Poll qw(POLLIN POLLOUT POLLERR POLLHUP);
use Time::HiRes qw(time usleep);
use POSIX qw(:sys_wait_h);
use Getopt::Long qw(GetOptions);
use JSON::PP qw(encode_json decode_json);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Config;
use FindBin qw($Bin);
use lib "$Bin/../../blib/lib", "$Bin/../../blib/arch", "$Bin/../../lib";

my $systems  = 'phase35-xs,phase35-empty,phase35-perl';
my $clients  = '1,10,50,100';
my $messages = 1000;
my $warmup   = 100;
my $bytes    = '64';
my $host     = '127.0.0.1';
my $timeout  = 60;
my $out      = 'bench/results/comparison.html';
my $json_out = 'bench/results/comparison.json';
my $repeats  = 3;
my $no_latency = 0;
my $build = 0;
my $pause_between_systems = 0;
my $merge_json = '';
my $client_driver = 'fork';
my $client_workers = 1;
my $xsloop_profile = 0;
my $xsloop_event_cap = 0;
my $check_deps = 0;

our @LIVE_CHILDREN;
our $ACTIVE_SYSTEM = q{};
our $PHASE34B_TIMEOUT_R;
our $PHASE34B_WATCHDOG_PID;
my $PHASE35_EMPTY_CB = sub { };
my $CLEANING_UP = 0;
$SIG{INT}  = sub { cleanup_children('INT');  exit 130; };
$SIG{TERM} = sub { cleanup_children('TERM'); exit 143; };
$SIG{PIPE} = 'IGNORE';
END { cleanup_children('END') if @LIVE_CHILDREN; }

GetOptions(
    'systems=s'    => \$systems,
    'clients=s'    => \$clients,
    'messages=i'   => \$messages,
    'warmup=i'     => \$warmup,
    'bytes=s'      => \$bytes,
    'host=s'       => \$host,
    'timeout=f'    => \$timeout,
    'out=s'        => \$out,
    'json=s'       => \$json_out,
    'repeats=i'    => \$repeats,
    'no-latency!'  => \$no_latency,
    'build!'       => \$build,
    'pause-between-systems=f' => \$pause_between_systems,
    'merge-json=s'  => \$merge_json,
    'client-driver=s' => \$client_driver,
    'client-workers=i' => \$client_workers,
    'xsloop-profile!' => \$xsloop_profile,
    'xsloop-event-cap=i' => \$xsloop_event_cap,
    'check-deps!' => \$check_deps,
) or die usage();

if ($build) { build_local_xsloop(); }

my @systems = grep length, split /,/, $systems;
my @clients = map { int($_) } grep length, split /,/, $clients;
my @byte_sizes = map { int($_) } grep length, split /,/, $bytes;
die "messages must be > 0\n" unless $messages > 0;
die "warmup must be >= 0\n" unless $warmup >= 0;
die "all byte sizes must be > 0\n" unless @byte_sizes && !grep { $_ <= 0 } @byte_sizes;
die "repeats must be > 0\n" unless $repeats > 0;
die "--client-driver must be fork or async\n" unless $client_driver eq 'fork' || $client_driver eq 'async';
die "--client-workers must be >= 1\n" unless $client_workers >= 1;
die "--client-workers is only valid with --client-driver async\n" if $client_driver ne 'async' && $client_workers != 1;

if ($check_deps) {
    check_dependencies(\@systems);
    exit 0;
}

if (length $merge_json) {
    my @inputs = grep length, split /,/, $merge_json;
    die "--merge-json needs at least one input JSON file\n" unless @inputs;
    my @merged_results;
    for my $file (@inputs) {
        open my $in, '<', $file or die "read $file: $!\n";
        local $/;
        my $data = decode_json(<$in>);
        close $in;
        push @merged_results, @{ $data->{results} || [] };
    }
    my @merged_summary = summarize_results(\@merged_results);
    write_json($json_out, { results => \@merged_results, summary => \@merged_summary });
    write_html($out, \@merged_results, \@merged_summary);
    print "merged " . scalar(@inputs) . " JSON files\n";
    print "wrote $json_out\n";
    print "wrote $out\n";
    exit 0;
}

my @results;
for my $system_index (0 .. $#systems) {
    my $system = $systems[$system_index];
    for my $bytes_one (@byte_sizes) {
        for my $c (@clients) {
            for my $rep (1 .. $repeats) {
                warn "== $system bytes=$bytes_one clients=$c repeat=$rep ==\n";
                my $r = eval { run_case_isolated($system, $c, $messages, $warmup, $bytes_one, $rep) };
                if (!$r) {
                    my $err = $@ || 'unknown error';
                    chomp $err;
                    $r = {
                        system => display_system($system), backend => backend_name($system), clients => $c, client_driver => $client_driver, client_workers => ($client_driver eq 'async' ? $client_workers : $c),
                        messages => $c * $messages, warmup_messages => $c * $warmup,
                        messages_per_client => $messages, warmup_per_client => $warmup, bytes => $bytes_one,
                        repeat => $rep, ok => JSON::PP::false, rankable => JSON::PP::false,
                        failure_reason => $err, messages_per_second => undef, mib_per_second => undef, error => $err,
                    };
                    warn "FAILED $system bytes=$bytes_one clients=$c: $err\n";
                }
                push @results, $r;
            }
        }
    }
    if ($pause_between_systems > 0 && $system_index < $#systems) {
        warn sprintf "== pausing %.3fs before next system ==\n", $pause_between_systems;
        usleep(int($pause_between_systems * 1_000_000));
    }
}

my @summary = summarize_results(\@results);
write_json($json_out, { results => \@results, summary => \@summary });
write_html($out, \@results, \@summary);
print "wrote $json_out\n";
print "wrote $out\n";
exit 0;


sub cleanup_children ($why = 'cleanup') {
    return if $CLEANING_UP++;
    my @pids = grep { defined && $_ > 0 } @LIVE_CHILDREN;
    return unless @pids;
    warn "== cleaning up " . scalar(@pids) . " child process(es) after $why ==\n";

    kill 'TERM', @pids;
    my $deadline = time + 2.0;
    while (@pids && time < $deadline) {
        for my $pid (@pids) {
            my $wp = waitpid($pid, WNOHANG);
            remove_live_child($pid) if $wp == $pid || $wp == -1;
        }
        @pids = grep { is_live_child($_) } @pids;
        usleep(20_000) if @pids;
    }

    @pids = grep { is_live_child($_) } @pids;
    if (@pids) {
        warn "== force killing " . scalar(@pids) . " child process(es) ==\n";
        kill 'KILL', @pids;
        for my $pid (@pids) { waitpid($pid, 0); remove_live_child($pid); }
    }
    @LIVE_CHILDREN = ();
    $CLEANING_UP = 0;
}

sub is_live_child ($pid) {
    return grep { $_ == $pid } @LIVE_CHILDREN;
}

sub remove_live_child ($pid) {
    @LIVE_CHILDREN = grep { $_ != $pid } @LIVE_CHILDREN;
}

sub usage {
    return <<'USAGE';
Usage:
  perl bench/run-async-comparison.pl --build --systems phase35-xs,phase35-empty,phase35-perl --clients 1000,2500,5000,10000 --warmup 1 --messages 10 --bytes 64 --client-driver async --out bench/results/phase35-ceiling.html --json bench/results/phase35-ceiling.json

Options:
  --build       run perl Makefile.PL && make before benchmarking Linux::Event::Loop
  --bytes       comma-separated message sizes, e.g. 64 or 64,512,4096,16384
  --repeats N   repeat each case; default 3; summaries use successful repeats only
  --timeout N   server timeout in seconds; default 60 (use 90+ for stressed 20k runs)
  --pause-between-systems N  sleep N seconds after each backend/system
  --merge-json a.json,b.json  merge previous result JSON files into one HTML/JSON report
  --client-driver fork|async  fork = one process per client; async = poll-based client driver process(es)
  --client-workers N          async only; split clients across N independent load-generator processes
  --xsloop-profile           enable XSLoop nanosecond profiling counters for XSLoop phases
  --xsloop-event-cap N       set XSLoop epoll event buffer capacity for batching experiments
  Phase35 ceiling systems:
    phase35-xs    native XS read/write echo, no Perl read callback
    phase35-empty same native XS echo plus one empty Perl read callback per readable dispatch
    phase35-perl  current Phase33C Perl echo callback path
  B-A isolates Perl read-callback entry cost; C-B isolates Perl-side echo/I/O work.
  Phase33C tuning systems: phase33c-1, phase33c-8, phase33c-16, phase33c-32, phase33c-64, phase33c-128, phase33c-batch
  phase33c defaults to 128 callbacks per Perl scope; phase33c-batch reproduces Phase33B whole-batch scoping.
  phase34c uses pure persistent XS run() with timeout enforced by the parent case supervisor.
  phase34b is the older pure-run experiment with an in-worker forked watchdog (kept only for A/B diagnosis).
  phase34 uses persistent XS run_for(seconds) for comparison.
  --check-deps               print dependency status for selected systems and exit
  Each benchmark case runs in a fresh worker process to isolate loop globals and RSS HWM.
  Failed correctness/timeout runs retain attempt metrics but are not assigned ranked msg/s/MiB/s.
  Ctrl-C/SIGTERM cleanup: case workers and client children are killed/reaped before exit
USAGE
}


sub build_local_xsloop {
    return unless -e 'Makefile.PL';
    warn "== building local Linux::Event::Loop module ==\n";
    system($^X, 'Makefile.PL') == 0 or die "Makefile.PL failed\n";
    system('make') == 0 or die "make failed\n";
}

sub check_dependencies ($systems_ref) {
    my %need = (
        ev       => [qw(EV)],
        anyevent => [qw(AnyEvent EV)],
        ioasync  => [qw(IO::Async::Loop::Epoll)],
        mojo     => [qw(Mojo::IOLoop Mojo::Reactor::EV EV)],
    );
    my %seen;
    my @mods;
    for my $system (@$systems_ref) {
        push @mods, @{ $need{$system} || [] };
    }
    @mods = grep { !$seen{$_}++ } @mods;

    print "Perl $^V ($^X)\n";
    print "Core harness modules: IO::Socket::INET IO::Poll Time::HiRes POSIX Getopt::Long JSON::PP File::Path File::Temp Config FindBin\n";
    my $missing = 0;
    for my $mod (@mods) {
        (my $file = "$mod.pm") =~ s{::}{/}g;
        my $ok = eval { require $file; 1 };
        if ($ok) {
            no strict 'refs';
            my $version = ${"${mod}::VERSION"};
            use strict 'refs';
            $version = 'installed' unless defined $version && length $version;
            printf "  %-28s OK (%s)\n", $mod, $version;
        } else {
            printf "  %-28s MISSING\n", $mod;
            $missing++;
        }
    }
    if (grep { $_ =~ /^(?:phase|xsloop)/ } @$systems_ref) {
        my $ok = eval { require Linux::Event::Loop; 1 };
        printf "  %-28s %s\n", 'Linux::Event::Loop', ($ok ? 'OK (local build/load)' : 'MISSING/NOT BUILT (use --build)');
        $missing++ unless $ok;
    }
    print $missing ? "Dependency check: $missing missing item(s)\n" : "Dependency check: OK\n";
    return !$missing;
}

sub run_case_isolated ($system, $clients, $messages, $warmup, $bytes, $repeat) {
    pipe(my $read_fh, my $write_fh) or die "pipe failed: $!";
    my $pid = fork();
    die "fork failed: $!" unless defined $pid;

    if ($pid == 0) {
        close $read_fh;
        @LIVE_CHILDREN = ();
        $CLEANING_UP = 0;
        $SIG{PIPE} = 'IGNORE';
        my $payload;
        my $ok = eval {
            my $result = run_case($system, $clients, $messages, $warmup, $bytes, $repeat);
            $payload = encode_json({ worker_ok => JSON::PP::true, result => $result });
            1;
        };
        if (!$ok) {
            my $err = $@ || 'unknown case-worker error';
            chomp $err;
            $payload = encode_json({ worker_ok => JSON::PP::false, error => $err });
        }
        print {$write_fh} $payload;
        close $write_fh;
        exit($ok ? 0 : 1);
    }

    close $write_fh;
    push @LIVE_CHILDREN, $pid;

    # The parent owns the catastrophic timeout for pure persistent run().
    # This keeps all watchdog setup out of the measured case worker, avoiding
    # both an extra epoll fd and fork/COW effects in the server process.
    if ($system eq 'phase34c') {
        my $guard_seconds = $timeout + 30 + int($clients / 1000);
        my $sel = IO::Select->new($read_fh);
        if (!$sel->can_read($guard_seconds)) {
            kill 'TERM', $pid;
            usleep(100_000);
            kill 'KILL', $pid if kill 0, $pid;
            waitpid($pid, 0);
            remove_live_child($pid);
            close $read_fh;
            die "phase34c case worker exceeded external timeout (${guard_seconds}s)\n";
        }
    }

    local $/;
    my $txt = <$read_fh>;
    close $read_fh;
    waitpid($pid, 0);
    my $status = $?;
    remove_live_child($pid);

    die "case worker produced no result\n" unless defined $txt && length $txt;
    my $envelope = eval { decode_json($txt) };
    die "case worker returned invalid JSON: $@\n" unless $envelope;
    die (($envelope->{error} || "case worker failed (status=$status)") . "\n") unless $envelope->{worker_ok};
    return $envelope->{result};
}

sub run_case ($system, $clients, $messages, $warmup, $bytes, $repeat) {
    my $server = IO::Socket::INET->new(
        LocalAddr => $host,
        LocalPort => 0,
        Proto     => 'tcp',
        Listen    => 512,
        ReuseAddr => 1,
    ) or die "listen failed: $!";
    $server->blocking(0);
    my $port = $server->sockport;

    my $tmp = tempdir(CLEANUP => 1);
    @LIVE_CHILDREN = ();
    my @pids;
    my @async_client_files;
    my $start_gate = "$tmp/start";
    my $msg = 'x' x $bytes;

    if ($client_driver eq 'async') {
        my $base = int($clients / $client_workers);
        my $extra = $clients % $client_workers;
        for my $worker (1 .. $client_workers) {
            my $worker_clients = $base + ($worker <= $extra ? 1 : 0);
            next if $worker_clients <= 0;
            my $file = "$tmp/async-client-$worker.json";
            push @async_client_files, $file;
            my $pid = fork();
            die "fork failed: $!" unless defined $pid;
            if ($pid == 0) {
                @LIVE_CHILDREN = ();
                $SIG{INT}  = sub { exit 130 };
                $SIG{TERM} = sub { exit 143 };
                $SIG{PIPE} = 'IGNORE';
                async_client_driver($host, $port, $worker_clients, $messages, $warmup, $bytes, $msg, $file, $start_gate, $no_latency, $timeout);
                exit 0;
            }
            push @pids, $pid;
            push @LIVE_CHILDREN, $pid;
        }
    } else {
        for my $i (1 .. $clients) {
            my $pid = fork();
            die "fork failed: $!" unless defined $pid;
            if ($pid == 0) {
                @LIVE_CHILDREN = ();
                $SIG{INT}  = sub { exit 130 };
                $SIG{TERM} = sub { exit 143 };
                $SIG{PIPE} = 'IGNORE';
                client_process($host, $port, $i, $messages, $warmup, $bytes, $msg, "$tmp/client-$i.json", $start_gate, $no_latency);
                exit 0;
            }
            push @pids, $pid;
            push @LIVE_CHILDREN, $pid;
        }
    }

    # Let client workers start together rather than letting early clients complete
    # before later clients exist.
    open my $gate, '>', $start_gate or die "open start gate: $!";
    print {$gate} "go\n";
    close $gate;

    my $runner = server_runner($system);
    local $ACTIVE_SYSTEM = $system;

    # Phase34B uses pure XS run(). Prepare the dormant timeout watchdog before
    # the measured server interval so process setup/teardown is not benchmarked.
    if ($system eq 'phase34b') {
        pipe(my $timeout_r, my $timeout_w) or die "timeout pipe failed: $!";
        my $watchdog_pid = fork();
        die "watchdog fork failed: $!" unless defined $watchdog_pid;
        if ($watchdog_pid == 0) {
            @LIVE_CHILDREN = ();
            close $timeout_r;
            $SIG{INT} = 'DEFAULT';
            $SIG{TERM} = sub { exit 0 };
            usleep(int($timeout * 1_000_000));
            syswrite($timeout_w, "T");
            close $timeout_w;
            exit 0;
        }
        close $timeout_w;
        $PHASE34B_TIMEOUT_R = $timeout_r;
        $PHASE34B_WATCHDOG_PID = $watchdog_pid;
        push @LIVE_CHILDREN, $watchdog_pid;
    }

    my $cs_before = context_switches();
    my @times_before = times();
    my $start = time;
    my $s = $runner->($server, $clients, $messages, $warmup, $bytes, $timeout);
    my $elapsed = time - $start;
    my @times_after = times();
    my $cs_after = context_switches();

    if ($system eq 'phase34b' && $PHASE34B_WATCHDOG_PID) {
        kill 'TERM', $PHASE34B_WATCHDOG_PID;
        waitpid($PHASE34B_WATCHDOG_PID, 0);
        remove_live_child($PHASE34B_WATCHDOG_PID);
        close $PHASE34B_TIMEOUT_R if $PHASE34B_TIMEOUT_R;
        undef $PHASE34B_TIMEOUT_R;
        undef $PHASE34B_WATCHDOG_PID;
    }
    my $server_user_cpu = $times_after[0] - $times_before[0];
    my $server_system_cpu = $times_after[1] - $times_before[1];

    my @client_results;
    my $client_failures = 0;
    my $client_deadline = time + $timeout;
    for my $pid (@pids) {
        while (1) {
            my $wp = waitpid($pid, WNOHANG);
            if ($wp == $pid) {
                remove_live_child($pid);
                if ($? != 0) { $client_failures++; }
                last;
            }
            if ($wp == -1) {
                remove_live_child($pid);
                last;
            }
            if (time >= $client_deadline) {
                $client_failures++;
                cleanup_children('client-timeout');
                last;
            }
            usleep(10_000);
        }
    }
    if ($client_driver eq 'async') {
        for my $file (@async_client_files) {
            if (!-e $file) {
                $client_failures++;
                next;
            }
            open my $fh, '<', $file or do { $client_failures++; next; };
            local $/;
            my $txt = <$fh>;
            close $fh;
            my $cr = eval { decode_json($txt) };
            if (!$cr || !$cr->{ok}) { $client_failures++; }
            push @client_results, $cr if $cr;
        }
    } else {
        for my $i (1 .. $clients) {
            my $file = "$tmp/client-$i.json";
            if (!-e $file) { $client_failures++; next; }
            open my $fh, '<', $file or do { $client_failures++; next; };
            local $/;
            my $txt = <$fh>;
            close $fh;
            my $cr = eval { decode_json($txt) };
            if (!$cr || !$cr->{ok}) { $client_failures++; }
            push @client_results, $cr if $cr;
        }
    }

    my @lat;
    my $client_measured = 0;
    for my $cr (@client_results) {
        $client_measured += $cr->{measured_messages} || 0;
        push @lat, @{ $cr->{latency_us} || [] } unless $no_latency;
    }
    @lat = sort { $a <=> $b } @lat;

    my $total_messages = $clients * $messages;
    my $total_bytes = $total_messages * $bytes;
    my $attempt_rate = $elapsed > 0 ? $total_messages / $elapsed : 0;
    my $attempt_mib = $elapsed > 0 ? ($total_bytes / 1048576) / $elapsed : 0;
    my $expected_all_bytes = $clients * ($messages + $warmup) * $bytes;
    my $ok = (!$s->{timed_out} && !$client_failures && ($s->{accepted}||0) == $clients && ($s->{closed}||0) == $clients && ($s->{echoed_bytes}||0) >= $expected_all_bytes && $client_measured == $total_messages);

    my @failure_reason;
    push @failure_reason, 'server timeout' if $s->{timed_out};
    push @failure_reason, "client failures=$client_failures" if $client_failures;
    push @failure_reason, "accepted=" . ($s->{accepted}||0) . "/$clients" if ($s->{accepted}||0) != $clients;
    push @failure_reason, "closed=" . ($s->{closed}||0) . "/$clients" if ($s->{closed}||0) != $clients;
    push @failure_reason, "echoed_bytes=" . ($s->{echoed_bytes}||0) . "/$expected_all_bytes" if ($s->{echoed_bytes}||0) < $expected_all_bytes;
    push @failure_reason, "client_measured=$client_measured/$total_messages" if $client_measured != $total_messages;

    my $rss = max_rss_kb();
    return {
        system => display_system($system), system_key => $system, backend => backend_name($system), client_driver => $client_driver, client_workers => ($client_driver eq 'async' ? $client_workers : $clients),
        clients => $clients, messages => $total_messages, messages_per_client => $messages,
        warmup_messages => $clients * $warmup, warmup_per_client => $warmup, bytes => $bytes,
        repeat => $repeat, elapsed_seconds => num($elapsed),
        messages_per_second => $ok ? num($attempt_rate) : undef,
        mib_per_second => $ok ? num($attempt_mib) : undef,
        attempt_messages_per_second => num($attempt_rate),
        attempt_mib_per_second => num($attempt_mib),
        rankable => $ok ? JSON::PP::true : JSON::PP::false,
        failure_reason => @failure_reason ? join('; ', @failure_reason) : undef,
        ok => $ok ? JSON::PP::true : JSON::PP::false,
        client_failures => $client_failures, client_measured_messages => $client_measured,
        lat_p50_us => pct(\@lat, 50), lat_p95_us => pct(\@lat, 95), lat_p99_us => pct(\@lat, 99), lat_max_us => (@lat ? $lat[-1] : undef),
        perl_version => "$^V", linux_kernel => scalar(`uname -r`) =~ s/\s+\z//r,
        max_rss_kb => $rss,
        server_user_cpu_seconds => num($server_user_cpu),
        server_system_cpu_seconds => num($server_system_cpu),
        server_total_cpu_seconds => num($server_user_cpu + $server_system_cpu),
        server_cpu_percent => $elapsed > 0 ? num((($server_user_cpu + $server_system_cpu) / $elapsed) * 100) : 0,
        voluntary_ctxt_switches => ($cs_after->{voluntary} // 0) - ($cs_before->{voluntary} // 0),
        nonvoluntary_ctxt_switches => ($cs_after->{nonvoluntary} // 0) - ($cs_before->{nonvoluntary} // 0),
        %$s,
    };
}


sub async_client_driver ($host, $port, $clients, $messages, $warmup, $bytes, $msg, $out, $gate, $no_latency, $server_timeout) {
    until (-e $gate) { usleep(1000); }

    my $total_per_client = $warmup + $messages;
    my $deadline = time + $server_timeout + int(10 + $clients / 1000);
    my $poll = IO::Poll->new;
    my %state;
    my $connected = 0;
    my $finished = 0;
    my $failed = 0;
    my @lat;
    my $err;

    # Blocking connect setup is intentionally outside the measured server elapsed
    # path. This is an async *load driver* replacement for thousands of forked
    # processes, not the event loop being benchmarked.
    for my $id (1 .. $clients) {
        my $sock;
        for (1 .. 2000) {
            $sock = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp');
            last if $sock;
            usleep(1000);
        }
        if (!$sock) { $failed++; next; }
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
        $poll->mask($sock => POLLIN | POLLOUT | POLLERR | POLLHUP);
        $connected++;
    }

    while (%state && time < $deadline) {
        my $nready = $poll->poll(0.05);
        next unless $nready;
        for my $fh ($poll->handles(POLLERR | POLLHUP | POLLIN | POLLOUT)) {
            my $fd = fileno($fh);
            my $st = $state{$fd} or next;
            my $ev = $poll->events($fh);

            if ($ev & (POLLERR | POLLHUP)) {
                # Still give readable sockets a chance to drain before failing.
                if (!($ev & POLLIN)) {
                    $failed++;
                    $poll->remove($fh);
                    delete $state{$fd};
                    close $fh;
                    next;
                }
            }

            if (($ev & POLLOUT) && $st->{write_active}) {
                my $off = $st->{write_off};
                my $wr = syswrite($fh, $msg, $bytes - $off, $off);
                if (defined $wr && $wr > 0) {
                    $st->{write_off} += $wr;
                    if ($st->{write_off} >= $bytes) {
                        $st->{write_active} = 0;
                        $st->{awaiting_reply} = 1;
                        $st->{write_off} = 0;
                    }
                } elsif (!defined $wr && ($!{EAGAIN} || $!{EWOULDBLOCK})) {
                    # keep POLLOUT
                } else {
                    $failed++;
                    $poll->remove($fh);
                    delete $state{$fd};
                    close $fh;
                    next;
                }
            }

            if ($ev & POLLIN) {
                while ($st->{recv_len} < $bytes) {
                    my $need = $bytes - $st->{recv_len};
                    my $rd = sysread($fh, my $buf, $need > 8192 ? 8192 : $need);
                    if (defined $rd && $rd > 0) {
                        $st->{recv_len} += $rd;
                        next;
                    }
                    if (defined $rd && $rd == 0) {
                        $failed++;
                        $poll->remove($fh);
                        delete $state{$fd};
                        close $fh;
                        next;
                    }
                    if (!defined $rd && ($!{EAGAIN} || $!{EWOULDBLOCK})) { last; }
                    $failed++;
                    $poll->remove($fh);
                    delete $state{$fd};
                    close $fh;
                    next;
                }
                next unless exists $state{$fd};

                if ($st->{recv_len} >= $bytes) {
                    my $completed_index = $st->{sent};
                    if ($completed_index > $warmup && !$no_latency && defined $st->{lat_start}) {
                        push @lat, int((time - $st->{lat_start}) * 1_000_000 + 0.5);
                    }
                    if ($st->{sent} >= $total_per_client) {
                        $finished++;
                        $poll->remove($fh);
                        delete $state{$fd};
                        close $fh;
                        next;
                    }
                    $st->{recv_len} = 0;
                    $st->{awaiting_reply} = 0;
                    $st->{write_active} = 0;
                    $st->{write_off} = 0;
                }
            }

            next unless exists $state{$fd};
            if (!$st->{write_active} && $st->{recv_len} == 0 && $st->{sent} < $total_per_client) {
                # handled after echo completion above only
            }
            if ($st->{write_active}) {
                # existing write is pending
            } elsif ($st->{recv_len} == 0 && $st->{sent} < $total_per_client) {
                # no-op
            }

            # Kick the first/next message when no write is active and we are not waiting for a reply.
            if (!$st->{write_active} && $st->{recv_len} == 0 && $st->{sent} < $total_per_client) {
                # This state is reached only after a completed reply; queue next send.
            }

            my $mask = POLLIN | POLLERR | POLLHUP;
            $mask |= POLLOUT if $st->{write_active};
            $poll->mask($fh => $mask);
        }

        # Initial/next message queueing pass. This keeps the event handlers small.
        for my $fd (keys %state) {
            my $st = $state{$fd};
            next if $st->{write_active};
            next if $st->{recv_len} != 0;
            next if $st->{awaiting_reply};
            next if $st->{sent} >= $total_per_client;
            $st->{sent}++;
            $st->{lat_start} = ($st->{sent} > $warmup && !$no_latency) ? time : undef;
            $st->{write_active} = 1;
            $st->{write_off} = 0;
            $poll->mask($st->{sock} => POLLIN | POLLOUT | POLLERR | POLLHUP);
        }
    }

    if (%state) {
        $failed += scalar keys %state;
        for my $st (values %state) { close $st->{sock}; }
        %state = ();
        $err = 'async client timeout';
    }

    my $ok = ($failed == 0 && $finished == $connected && $connected == $clients);
    open my $fh, '>', $out or die "write async client result: $!";
    print {$fh} encode_json({
        ok => $ok ? JSON::PP::true : JSON::PP::false,
        error => $err,
        connected_clients => $connected,
        finished_clients => $finished,
        failed_clients => $failed,
        measured_messages => $ok ? $clients * $messages : ($finished * $messages),
        latency_us => \@lat,
    });
    close $fh;
    exit($ok ? 0 : 1);
}

sub client_process ($host, $port, $id, $messages, $warmup, $bytes, $msg, $out, $gate, $no_latency) {
    $SIG{INT}  = sub { exit 130 };
    $SIG{TERM} = sub { exit 143 };
    until (-e $gate) { usleep(1000); }
    my $sock;
    for (1 .. 2000) {
        $sock = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp');
        last if $sock;
        usleep(1000);
    }
    my @lat;
    my $ok = $sock ? 1 : 0;
    my $err = undef;
    if ($sock) {
        my $client_timeout = int(15 + (($warmup + $messages) * 0.2));
        local $SIG{ALRM} = sub { die "client timeout\n" };
        alarm($client_timeout);
        eval {
            for my $i (1 .. ($warmup + $messages)) {
                my $t0 = time if $i > $warmup && !$no_latency;
                full_write($sock, $msg, $bytes);
                my $got = '';
                while (length($got) < $bytes) {
                    my $n = sysread($sock, my $buf, $bytes - length($got));
                    die "client read failed: $!" unless defined $n;
                    die "server closed" if $n == 0;
                    $got .= $buf;
                }
                if ($i > $warmup && !$no_latency) { push @lat, int((time - $t0) * 1_000_000 + 0.5); }
            }
            1;
        } or do { $ok = 0; $err = $@ || 'client error'; chomp $err; };
        close $sock;
    } else {
        $err = 'connect failed';
    }
    open my $fh, '>', $out or die "write client result: $!";
    print {$fh} encode_json({ ok => $ok ? JSON::PP::true : JSON::PP::false, error => $err, measured_messages => $ok ? $messages : 0, latency_us => \@lat });
    close $fh;
    exit($ok ? 0 : 1);
}

sub full_write ($fh, $buf, $len) {
    my $off = 0;
    while ($off < $len) {
        my $n = syswrite($fh, $buf, $len - $off, $off);
        die "client write failed: $!" unless defined $n;
        die "client write returned 0" if $n == 0;
        $off += $n;
    }
}

sub is_phase35_system ($system) {
    return $system eq 'phase35-xs' || $system eq 'phase35-empty' || $system eq 'phase35-perl';
}

sub is_phase33c_system ($system) {
    return $system =~ /^phase33c(?:-(?:1|8|16|32|64|128|batch))?$/ ? 1 : 0;
}

sub phase33c_scope_limit ($system) {
    return 128 if $system eq 'phase33c';
    return 0 if $system eq 'phase33c-batch';
    return 0 + $1 if $system =~ /^phase33c-(1|8|16|32|64|128)$/;
    return undef;
}

sub is_xsloop_system ($system) {
    return 1 if is_phase35_system($system);
    return 1 if $system eq 'phase34c';
    return 1 if $system eq 'phase34b';
    return 1 if $system eq 'phase34';
    return 1 if is_phase33c_system($system);
    return $system eq 'phase33b' || $system eq 'phase33a' || $system eq 'phase32' || $system eq 'phase31' || $system eq 'phase30' || $system eq 'phase29' || $system eq 'phase26' || $system eq 'phase25' || $system eq 'phase24' || $system eq 'phase23' || $system eq 'phase22' || $system eq 'phase21' || $system eq 'phase20' || $system eq 'phase19b' || $system eq 'xsloop' || $system eq 'phase18';
}

sub is_lean_xsloop_system ($system) {
    return 1 if is_phase35_system($system);
    return 1 if $system eq 'phase34c';
    return 1 if $system eq 'phase34b';
    return 1 if $system eq 'phase34';
    return 1 if is_phase33c_system($system);
    return $system eq 'phase33b' || $system eq 'phase33a' || $system eq 'phase32' || $system eq 'phase29' || $system eq 'phase30' || $system eq 'phase31';
}

sub server_runner ($system) {
    return \&run_xsloop  if is_xsloop_system($system);
    return \&run_ev       if $system eq 'ev';
    return \&run_anyevent if $system eq 'anyevent';
    return \&run_ioasync  if $system eq 'ioasync';
    return \&run_mojo    if $system eq 'mojo';
    die "unknown system '$system'";
}

sub run_xsloop ($server, $clients, $messages, $warmup, $bytes, $timeout) {
    require Linux::Event::Loop;
    my $loop = Linux::Event::Loop->new;
    $loop->set_event_capacity($xsloop_event_cap) if $xsloop_event_cap;
    $loop->set_callback_scope_limit(128) if is_phase35_system($ACTIVE_SYSTEM) || $ACTIVE_SYSTEM eq 'phase34' || $ACTIVE_SYSTEM eq 'phase34b' || $ACTIVE_SYSTEM eq 'phase34c';
    $loop->set_callback_scope_limit(phase33c_scope_limit($ACTIVE_SYSTEM)) if is_phase33c_system($ACTIVE_SYSTEM);
    $loop->profile(1) if $xsloop_profile;
    $loop->enable_watcher_reclaim(1) if $ACTIVE_SYSTEM eq 'phase31' || $ACTIVE_SYSTEM eq 'phase30';
    my %c = base_counters($clients, $messages, $warmup, $bytes);
    my $server_w;
    if (is_xsloop_system($ACTIVE_SYSTEM) && $ACTIVE_SYSTEM ne 'phase20' && $ACTIVE_SYSTEM ne 'phase19b' && $ACTIVE_SYSTEM ne 'xsloop' && $ACTIVE_SYSTEM ne 'phase18') {
        $server_w = $loop->watch_fd(fileno($server), fh => $server, no_args => 1, lean => (is_lean_xsloop_system($ACTIVE_SYSTEM) ? 1 : 0), read => sub {
            while (my $sock = $server->accept) {
                $c{accepted}++; $sock->blocking(0); my $fd = fileno($sock);
                my $cw;
                my $on_error = sub {
                    $c{error_callbacks}++;
                    $c{closed}++;
                    $cw->cancel;
                    close $sock;
                    $loop->stop if ($ACTIVE_SYSTEM eq 'phase34' || $ACTIVE_SYSTEM eq 'phase34b' || $ACTIVE_SYSTEM eq 'phase34c') && $c{closed} >= $clients;
                };
                if ($ACTIVE_SYSTEM eq 'phase35-xs') {
                    $cw = $loop->watch_fd(
                        $fd, fh => $sock, no_args => 1, lean => 1,
                        _bench_native_echo => 1,
                        error => $on_error,
                    );
                }
                elsif ($ACTIVE_SYSTEM eq 'phase35-empty') {
                    $cw = $loop->watch_fd(
                        $fd, fh => $sock, no_args => 1, lean => 1,
                        _bench_native_echo => 2,
                        read => $PHASE35_EMPTY_CB,
                        error => $on_error,
                    );
                }
                else {
                    $cw = $loop->watch_fd(
                        $fd, fh => $sock, no_args => 1, lean => (is_lean_xsloop_system($ACTIVE_SYSTEM) ? 1 : 0),
                        read => sub { echo_read($sock, \%c, sub { $cw->cancel; close $sock; $loop->stop if ($ACTIVE_SYSTEM eq 'phase34' || $ACTIVE_SYSTEM eq 'phase34b' || $ACTIVE_SYSTEM eq 'phase34c') && $c{closed} >= $clients; }); },
                        error => $on_error,
                    );
                }
            }
        });
    }
    else {
        $server_w = $loop->watch_fd(fileno($server), fh => $server, read => sub ($w) {
            while (my $sock = $server->accept) {
                $c{accepted}++; $sock->blocking(0); my $fd = fileno($sock);
                $loop->watch_fd($fd, fh => $sock, read => sub ($cw) { echo_read($cw->fh, \%c, sub { $cw->cancel; close $sock; $loop->stop if ($ACTIVE_SYSTEM eq 'phase34' || $ACTIVE_SYSTEM eq 'phase34b' || $ACTIVE_SYSTEM eq 'phase34c') && $c{closed} >= $clients; }); }, error => sub ($cw) { $c{error_callbacks}++; $c{closed}++; $cw->cancel; close $sock; $loop->stop if ($ACTIVE_SYSTEM eq 'phase34' || $ACTIVE_SYSTEM eq 'phase34b' || $ACTIVE_SYSTEM eq 'phase34c') && $c{closed} >= $clients; });
            }
        });
    }
    if ($ACTIVE_SYSTEM eq 'phase34c') {
        # Clean pure persistent XS run(). Catastrophic timeout is enforced by
        # the parent case supervisor, entirely outside this measured worker.
        $loop->run;
    } elsif ($ACTIVE_SYSTEM eq 'phase34b') {
        # Pure persistent XS run(). The timeout fd/watchdog is prepared outside
        # the measured interval so this path measures only the server loop.
        die "phase34b timeout watchdog not prepared" unless $PHASE34B_TIMEOUT_R;
        my $timeout_watcher;
        my $stop_for_timeout = sub {
            $c{timed_out} = JSON::PP::true;
            $timeout_watcher->cancel if $timeout_watcher;
            $loop->stop;
        };
        $timeout_watcher = $loop->watch_fd(
            fileno($PHASE34B_TIMEOUT_R),
            fh => $PHASE34B_TIMEOUT_R, no_args => 1, lean => 1,
            read => $stop_for_timeout, error => $stop_for_timeout,
        );
        $loop->run;
    } elsif ($ACTIVE_SYSTEM eq 'phase34') {
        $loop->run_for($timeout);
    } else {
        my $deadline = time + $timeout;
        while ($c{closed} < $clients && time < $deadline) { $loop->run_once(1000); }
    }
    $c{timed_out} = $c{closed} < $clients ? JSON::PP::true : JSON::PP::false;
    my $st = $loop->stats;
    for my $key (qw(
        event_capacity epoll_wait_calls epoll_wait_empty_calls epoll_wait_full_batches epoll_wait_max_batch
        ready_events_returned ready_read_events ready_write_events ready_error_events ready_epollerr_events ready_hup_events ready_rdhup_events ready_in_hup_events ready_in_rdhup_events ready_multi_events callback_calls
        read_callback_calls write_callback_calls error_callback_calls
        epoll_ctl_add_calls epoll_ctl_mod_calls epoll_ctl_del_calls
        watcher_lookup_calls direct_watcher_events dispatch_events profile_enabled
        epoll_wait_ns epoll_ctl_add_ns epoll_ctl_mod_ns epoll_ctl_del_ns
        watcher_lookup_ns dispatch_ns callback_noarg_calls callback_onearg_calls callback_direct_cv_calls callback_sv_calls callback_batch_scope_enters callback_scope_rotations callback_scope_max_callbacks callback_scope_limit run_once_calls run_calls run_for_calls
        bench_native_echo_read_events bench_native_echo_perl_read_callbacks bench_native_echo_sysread_calls bench_native_echo_syswrite_calls bench_native_echo_bytes_read bench_native_echo_bytes_written bench_native_echo_read_eagain bench_native_echo_write_eagain bench_native_echo_partial_writes bench_native_echo_read_zero bench_native_echo_errors
        lean_watchers watcher_alloc_calls watcher_reuse_calls watcher_recycle_calls watcher_destroy_calls watcher_freelist_depth watcher_freelist_max_depth watcher_reclaim_enabled
    )) {
        $c{$key} = $st->{$key} if exists $st->{$key};
    }
    if ($ACTIVE_SYSTEM eq 'phase35-xs' || $ACTIVE_SYSTEM eq 'phase35-empty') {
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
    return \%c;
}

sub run_ev ($server, $clients, $messages, $warmup, $bytes, $timeout) {
    require EV;
    my %c = base_counters($clients, $messages, $warmup, $bytes);
    my %watch;
    my $timer = EV::timer($timeout, 0, sub { $c{timed_out} = JSON::PP::true; EV::break(2); });
    $watch{server} = EV::io($server, EV::READ(), sub {
        while (my $sock = $server->accept) {
            $c{accepted}++; $sock->blocking(0); my $fd = fileno($sock);
            $watch{$fd} = EV::io($sock, EV::READ(), sub { echo_read($sock, \%c, sub { delete $watch{$fd}; close $sock; EV::break(2) if $c{closed} >= $clients; }); });
        }
    });
    EV::run();
    $c{timed_out} //= JSON::PP::false;
    return \%c;
}

sub run_anyevent ($server, $clients, $messages, $warmup, $bytes, $timeout) {
    $ENV{PERL_ANYEVENT_MODEL} ||= 'EV';
    require AnyEvent;
    my %c = base_counters($clients, $messages, $warmup, $bytes);
    my $cv = AnyEvent->condvar;
    my %watch;
    my $timer = AnyEvent->timer(after => $timeout, cb => sub { $c{timed_out} = JSON::PP::true; $cv->send; });
    $watch{server} = AnyEvent->io(fh => $server, poll => 'r', cb => sub {
        while (my $sock = $server->accept) {
            $c{accepted}++; $sock->blocking(0); my $fd = fileno($sock);
            $watch{$fd} = AnyEvent->io(fh => $sock, poll => 'r', cb => sub { echo_read($sock, \%c, sub { delete $watch{$fd}; close $sock; $cv->send if $c{closed} >= $clients; }); });
        }
    });
    $cv->recv;
    $c{timed_out} //= JSON::PP::false;
    return \%c;
}

sub run_ioasync ($server, $clients, $messages, $warmup, $bytes, $timeout) {
    require IO::Async::Loop::Epoll;
    my %c = base_counters($clients, $messages, $warmup, $bytes);
    my $loop = IO::Async::Loop::Epoll->new;
    my $done = 0;
    $loop->watch_io(handle => $server, on_read_ready => sub {
        while (my $sock = $server->accept) {
            $c{accepted}++; $sock->blocking(0); my $fd = fileno($sock);
            $loop->watch_io(handle => $sock, on_read_ready => sub { echo_read($sock, \%c, sub { $loop->unwatch_io(handle => $sock, on_read_ready => 1); close $sock; $done = 1 if $c{closed} >= $clients; }); });
        }
    });
    my $deadline = time + $timeout;
    while (!$done && time < $deadline) { $loop->loop_once(0.001); }
    $c{timed_out} = $done ? JSON::PP::false : JSON::PP::true;
    return \%c;
}


sub run_mojo ($server, $clients, $messages, $warmup, $bytes, $timeout) {
    # Use Mojo::IOLoop's reactor directly so the echo body remains as close as
    # possible to the other low-level event-loop comparisons. Prefer the EV
    # reactor when EV and Mojo::Reactor::EV are available; otherwise Mojo falls
    # back to its default reactor.
    local $ENV{MOJO_REACTOR} = $ENV{MOJO_REACTOR} || 'Mojo::Reactor::EV';
    require Mojo::IOLoop;
    my %c = base_counters($clients, $messages, $warmup, $bytes);
    my $loop = Mojo::IOLoop->singleton;
    my $reactor = $loop->reactor;
    my $reactor_class = ref($reactor) || 'unknown';
    $c{backend_runtime} = $reactor_class;
    $c{backend} = "Mojo::IOLoop ($reactor_class)";

    my $stop = sub { $reactor->stop if $reactor->is_running };
    my $timer = $reactor->timer($timeout => sub { $c{timed_out} = JSON::PP::true; $stop->(); });

    $reactor->io($server => sub ($reactor, $writable) {
        while (my $sock = $server->accept) {
            $c{accepted}++;
            $sock->blocking(0);
            $reactor->io($sock => sub ($reactor, $writable) {
                echo_read($sock, \%c, sub {
                    $reactor->remove($sock);
                    close $sock;
                    $stop->() if $c{closed} >= $clients;
                });
            });
            $reactor->watch($sock, 1, 0);
        }
    });
    $reactor->watch($server, 1, 0);
    $reactor->start unless $c{closed} >= $clients;
    $reactor->remove($server);
    $reactor->remove($timer) if defined $timer;
    $c{timed_out} //= JSON::PP::false;
    return \%c;
}

sub base_counters ($clients, $messages, $warmup, $bytes) {
    return (
        accepted => 0, closed => 0, echoed_bytes => 0,
        expected_bytes => $clients * ($messages + $warmup) * $bytes,
        read_callbacks => 0, error_callbacks => 0, sysread_calls => 0,
        syswrite_calls => 0, read_eagain => 0, write_eagain => 0,
        bytes_read => 0, bytes_written => 0, close_reads => 0,
        partial_writes => 0, timed_out => JSON::PP::false,
    );
}

sub echo_read ($fh, $c, $on_close) {
    $c->{read_callbacks}++;
    while (1) {
        $c->{sysread_calls}++;
        my $n = sysread($fh, my $buf, 8192);
        if (defined $n && $n > 0) {
            $c->{bytes_read} += $n;
            $c->{echoed_bytes} += $n;
            my $off = 0; my $len = length($buf);
            while ($off < $len) {
                $c->{syswrite_calls}++;
                my $wr = syswrite($fh, $buf, $len - $off, $off);
                if (defined $wr && $wr > 0) {
                    $c->{bytes_written} += $wr;
                    $c->{partial_writes}++ if $wr < ($len - $off);
                    $off += $wr;
                    next;
                }
                if (!defined $wr && ($!{EAGAIN} || $!{EWOULDBLOCK})) { $c->{write_eagain}++; last; }
                last;
            }
            next;
        }
        if (defined $n && $n == 0) { $c->{close_reads}++; $c->{closed}++; $on_close->(); last; }
        if (!defined $n && ($!{EAGAIN} || $!{EWOULDBLOCK})) { $c->{read_eagain}++; last; }
        $c->{error_callbacks}++; $c->{closed}++; $on_close->(); last;
    }
}

sub pct ($arr, $p) {
    return undef unless @$arr;
    my $idx = int((@$arr - 1) * ($p / 100));
    return $arr->[$idx];
}
sub num ($v) { return 0 + sprintf('%.6f', $v); }
sub max_rss_kb { return 0 unless -r '/proc/self/status'; open my $fh, '<', '/proc/self/status' or return 0; while (<$fh>) { return 0 + $1 if /^VmHWM:\s+(\d+)\s+kB/; } return 0; }
sub context_switches { my %r = (voluntary => 0, nonvoluntary => 0); return \%r unless -r '/proc/self/status'; open my $fh, '<', '/proc/self/status' or return \%r; while (<$fh>) { $r{voluntary} = 0 + $1 if /^voluntary_ctxt_switches:\s+(\d+)/; $r{nonvoluntary} = 0 + $1 if /^nonvoluntary_ctxt_switches:\s+(\d+)/; } return \%r; }
sub display_system ($s) {
    return 'Linux::Event Phase35 A: XS native echo, no Perl read callback' if $s eq 'phase35-xs';
    return 'Linux::Event Phase35 B: XS native echo plus empty Perl read callback' if $s eq 'phase35-empty';
    return 'Linux::Event Phase35 C: current Perl echo callback' if $s eq 'phase35-perl';
    return 'Linux::Event Phase34C XSLoop pure persistent run (external timeout)' if $s eq 'phase34c';
    return 'Linux::Event Phase34B XSLoop pure persistent run' if $s eq 'phase34b';
    return 'Linux::Event Phase34 XSLoop persistent run_for' if $s eq 'phase34';
    if (is_phase33c_system($s)) {
        my $limit = phase33c_scope_limit($s);
        my $suffix = $limit == 0 ? 'whole batch' : "$limit callbacks/scope";
        return "Linux::Event Phase33C XSLoop ($suffix)";
    }
    return $s eq 'phase33b' ? 'Linux::Event Phase33B XSLoop' : $s eq 'phase33a' ? 'Linux::Event Phase33A XSLoop' : $s eq 'phase32' ? 'Linux::Event Phase32 XSLoop' : $s eq 'phase31' ? 'Linux::Event Phase31 XSLoop' : $s eq 'phase30' ? 'Linux::Event Phase30 XSLoop' : $s eq 'phase29' ? 'Linux::Event Phase29 XSLoop' : $s eq 'phase26' ? 'Linux::Event Phase26 XSLoop' : $s eq 'phase25' ? 'Linux::Event Phase25 XSLoop' : $s eq 'phase24' ? 'Linux::Event Phase24 XSLoop' : $s eq 'phase23' ? 'Linux::Event Phase23 XSLoop' : $s eq 'phase22' ? 'Linux::Event Phase22 XSLoop' : $s eq 'phase21' ? 'Linux::Event Phase21 XSLoop' : $s eq 'phase20' ? 'Linux::Event Phase20 XSLoop' : ($s eq 'phase19b' || $s eq 'xsloop') ? 'Linux::Event Phase19B XSLoop' : $s eq 'phase18' ? 'Linux::Event XSLoop' : $s eq 'anyevent' ? 'AnyEvent' : $s eq 'ev' ? 'EV' : $s eq 'ioasync' ? 'IO::Async' : $s eq 'mojo' ? 'Mojo::IOLoop' : $s;
}

sub backend_name ($s) {
    return 'XS-first epoll (Linux::Event::Loop)' if is_xsloop_system($s);
    return $s eq 'anyevent' ? 'EV/libev epoll on Linux' : $s eq 'ev' ? 'EV/libev epoll on Linux' : $s eq 'ioasync' ? 'IO::Async::Loop::Epoll' : $s eq 'mojo' ? 'Mojo::IOLoop reactor, prefers Mojo::Reactor::EV' : 'unknown';
}


sub summarize_results ($results) {
    my %g;
    for my $r (@$results) {
        my $key = join "\0", map { $r->{$_} // '' } qw(system_key system backend client_driver client_workers bytes clients messages_per_client warmup_per_client);
        push @{ $g{$key} }, $r;
    }
    my @out;
    for my $key (sort keys %g) {
        my @rows = @{ $g{$key} };
        my @ok = grep { $_->{ok} } @rows;
        my $base = { %{ $rows[0] } };
        for my $k (qw(repeat elapsed_seconds messages_per_second mib_per_second lat_p50_us lat_p95_us lat_p99_us lat_max_us server_user_cpu_seconds server_system_cpu_seconds server_total_cpu_seconds server_cpu_percent voluntary_ctxt_switches nonvoluntary_ctxt_switches)) { delete $base->{$k}; }
        $base->{repeats} = scalar @rows;
        $base->{ok_repeats} = scalar @ok;
        $base->{ok} = (@ok == @rows) ? JSON::PP::true : JSON::PP::false;
        $base->{rankable} = @ok ? JSON::PP::true : JSON::PP::false;
        $base->{summary} = JSON::PP::true;
        for my $field (qw(elapsed_seconds messages_per_second mib_per_second lat_p50_us lat_p95_us lat_p99_us lat_max_us server_user_cpu_seconds server_system_cpu_seconds server_total_cpu_seconds server_cpu_percent voluntary_ctxt_switches nonvoluntary_ctxt_switches max_rss_kb)) {
            my @vals = grep { defined } map { $_->{$field} } @ok;
            next unless @vals;
            my $sum = 0; $sum += $_ for @vals;
            my @sorted = sort { $a <=> $b } @vals;
            $base->{"avg_$field"} = num($sum / @vals);
            $base->{"best_$field"} = ($field =~ /elapsed|lat_|rss|cpu|ctxt/) ? $sorted[0] : $sorted[-1];
        }
        push @out, $base;
    }
    return @out;
}

sub write_json ($path, $data) { my ($dir) = $path =~ m{^(.*)/[^/]+$}; make_path($dir) if $dir; open my $fh, '>', $path or die "write $path: $!"; print {$fh} JSON::PP->new->canonical->pretty->encode($data); close $fh; }
sub html_escape ($s) { return '' unless defined $s; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/"/&quot;/g; return $s; }
sub fmt ($v, $d=2) { return '' unless defined $v; return sprintf("%.${d}f", $v); }

sub client_driver_label () {
    return $client_driver eq 'async' ? 'one poll-based async client driver process' : 'blocking forked clients';
}
sub client_driver_fairness_note () {
    return $client_driver eq 'async'
        ? 'Same poll-based async client driver implementation for every server backend.'
        : 'Same blocking forked client implementation for every server backend.';
}

sub write_html ($path, $results, $summary) {
    my ($dir) = $path =~ m{^(.*)/[^/]+$}; make_path($dir) if $dir;
    open my $fh, '>', $path or die "write $path: $!";
    my $stamp = scalar localtime;
    print {$fh} <<HTML;
<!doctype html>
<html><head><meta charset="utf-8"><title>Async Perl epoll comparison</title>
<style>
body{font-family:system-ui,sans-serif;margin:2rem;line-height:1.35}h1,h2{margin-bottom:.4rem}.note{background:#f6f8fa;border:1px solid #d0d7de;border-radius:8px;padding:1rem;margin:1rem 0 1.5rem}table{border-collapse:collapse;width:100%;margin:1rem 0 2rem}th,td{border:1px solid #c9d1d9;padding:.45rem .6rem;text-align:right}th:first-child,td:first-child,th:nth-child(2),td:nth-child(2){text-align:left}th{background:#f0f3f6;cursor:pointer;user-select:none;position:sticky;top:0;z-index:1}th:hover{background:#dbeafe}th::after{content:" <=>";font-size:.75em;color:#6b7280}th.sort-asc::after{content:" ^";font-size:.8em;color:#0969da}th.sort-desc::after{content:" v";font-size:.8em;color:#0969da}code{background:#f6f8fa;padding:.1rem .25rem;border-radius:4px}.small{color:#57606a;font-size:.92rem}.bad{color:#b42318;font-weight:600}.good{color:#067647;font-weight:600}.toolbar{display:flex;gap:1rem;align-items:center;flex-wrap:wrap;margin:.5rem 0 1rem}.toolbar input{padding:.35rem .5rem;border:1px solid #d0d7de;border-radius:6px}.hint{color:#57606a;font-size:.9rem}.legend{display:flex;gap:.75rem;flex-wrap:wrap;margin:.5rem 0 1rem}.row-phase35-xs,.row-phase35-empty,.row-phase35-perl,.row-phase34c,.row-phase34b,.row-phase34,.row-phase33c,.row-phase33c-1,.row-phase33c-8,.row-phase33c-16,.row-phase33c-32,.row-phase33c-64,.row-phase33c-128,.row-phase33c-batch{background:#043f1f;border-left:6px solid #011d0e}.row-phase33b{background:#064e24;border-left:6px solid #022c15}.row-phase33a{background:#0b6b2b;border-left:6px solid #043d17}.row-phase32{background:#16833a;border-left:6px solid #063d1a}.row-phase31{background:#20883a;border-left:6px solid #0a4f22}.row-phase30{background:#2fb344;border-left:6px solid #0f6b2f}.row-phase29{background:#57d982;border-left:6px solid #16833a}.row-phase26{background:#7ee787;border-left:6px solid #16833a}.row-phase25{background:#9be9b0;border-left:6px solid #16833a}.chip{border:1px solid #9ca3af;border-radius:999px;padding:.18rem .55rem;font-size:.9rem;font-weight:600}.row-phase24{background:#b0eec0;border-left:6px solid #16833a}.row-phase23{background:#bff0ca;border-left:6px solid #16833a}.row-phase22{background:#cff7d6;border-left:6px solid #16833a}.row-phase21{background:#dff7e5;border-left:6px solid #16833a}.row-phase20{background:#e9faee;border-left:6px solid #16833a}.row-phase19b{background:#e9faee;border-left:6px solid #16833a}.row-xsloop{background:#dff7e5;border-left:6px solid #16833a}.row-phase18{background:#e9faee;border-left:6px solid #16833a}.row-anyevent{background:#fff0bd;border-left:6px solid #b77900}.row-ev{background:#d9ecff;border-left:6px solid #0969da}.row-ioasync{background:#f0dcff;border-left:6px solid #8250df}.row-mojo{background:#ffe4d6;border-left:6px solid #c2410c}.row-unknown{background:#fff;border-left:6px solid #8c959f}tbody tr:hover{filter:brightness(.92)}
</style>
<script>
function trimString(s) {
  s = String(s == null ? '' : s);
  while (s.length && (s.charCodeAt(0) <= 32)) s = s.slice(1);
  while (s.length && (s.charCodeAt(s.length - 1) <= 32)) s = s.slice(0, -1);
  return s;
}
function cellText(el) {
  return trimString(el ? (el.textContent || el.innerText || '') : '');
}
function removeSortClasses(el) {
  var parts = String(el.className || '').split(' ');
  var kept = [];
  for (var i = 0; i < parts.length; i++) {
    if (parts[i] && parts[i] !== 'sort-asc' && parts[i] !== 'sort-desc') kept.push(parts[i]);
  }
  el.className = kept.join(' ');
}
function sortValue(row, idx) {
  var cell = row.cells[idx];
  if (!cell) return '';
  var raw = trimString(cell.getAttribute('data-sort') || cellText(cell));
  if (raw === '') return '';
  var lowered = raw.toLowerCase();
  if (lowered === 'yes' || lowered === 'true' || lowered === 'ok') return 1;
  if (lowered === 'no' || lowered === 'false' || lowered === 'fail') return 0;
  var numeric = raw.split(',').join('');
  if (numeric !== '' && !isNaN(Number(numeric))) return Number(numeric);
  return lowered;
}
function sortTableByHeader(th) {
  var table = th;
  while (table && table.tagName !== 'TABLE') table = table.parentNode;
  if (!table || !table.tBodies || !table.tBodies.length) return false;

  var headers = th.parentNode.cells;
  var idx = -1;
  for (var i = 0; i < headers.length; i++) {
    if (headers[i] === th) idx = i;
    removeSortClasses(headers[i]);
  }
  if (idx < 0) return false;

  var desc = table.getAttribute('data-sort-col') !== String(idx) || table.getAttribute('data-sort-dir') !== 'desc';
  table.setAttribute('data-sort-col', String(idx));
  table.setAttribute('data-sort-dir', desc ? 'desc' : 'asc');
  th.className = trimString((th.className || '') + ' ' + (desc ? 'sort-desc' : 'sort-asc'));

  var tbody = table.tBodies[0];
  var rows = [];
  for (var r = 0; r < tbody.rows.length; r++) rows.push(tbody.rows[r]);
  rows.sort(function(a, b) {
    var av = sortValue(a, idx);
    var bv = sortValue(b, idx);
    var cmp;
    if (typeof av === 'number' && typeof bv === 'number') cmp = av - bv;
    else cmp = String(av).localeCompare(String(bv));
    return desc ? -cmp : cmp;
  });
  for (var k = 0; k < rows.length; k++) tbody.appendChild(rows[k]);
  return false;
}
function filterTables(q) {
  q = String(q || '').toLowerCase();
  var rows = document.getElementsByTagName('tr');
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].parentNode && rows[i].parentNode.tagName === 'TBODY') {
      rows[i].style.display = cellText(rows[i]).toLowerCase().indexOf(q) >= 0 ? '' : 'none';
    }
  }
}
window.onload = function() {
  var ths = document.getElementsByTagName('th');
  for (var i = 0; i < ths.length; i++) {
    ths[i].title = 'Click to sort by ' + cellText(ths[i]);
    ths[i].onclick = function() { return sortTableByHeader(this); };
  }
};
</script>
</head><body>
<h1>Async Perl epoll comparison</h1>
<p class="small">Generated @{[html_escape($stamp)]}. Workload: TCP echo, @{[html_escape(client_driver_label())]}, $messages measured messages/client, $warmup warmup messages/client, byte sizes: @{[html_escape(join(',', @byte_sizes))]}.</p>
<div class="note"><h2>Notes: fairness rules</h2><ul>
<li>@{[html_escape(client_driver_fairness_note())]}</li>
<li>Only the server-side async loop changes.</li>
<li>Phase35 A/B/C uses the same TCP client workload and the same XS watcher/epoll dispatch. A performs echo reads/writes in XS without a Perl read callback; B adds an empty Perl read callback before the same XS echo; C uses the current Perl echo callback.</li>
<li>Use multiple async client workers for ceiling tests so the load generator does not become the bottleneck; this does not change the per-connection request/reply protocol.</li>
<li>For Phase35, B minus A estimates Perl read-callback entry overhead; C minus B estimates the additional cost of doing echo I/O and accounting in Perl rather than XS.</li>
<li>Each case runs in a fresh worker process so backend globals and process high-water RSS cannot leak across systems or repeats.</li>
<li>Failed or timed-out cases are correctness failures: their attempted rate is retained in JSON for diagnostics, but ranked msg/s and MiB/s are left blank and summaries use successful repeats only.</li>
<li>Warmup messages are excluded from throughput and latency, but included in correctness byte counters.</li>
<li>AnyEvent is forced through <code>PERL_ANYEVENT_MODEL=EV</code> where possible.</li>
<li>Mojo::IOLoop is run through its reactor layer and prefers <code>MOJO_REACTOR=Mojo::Reactor::EV</code> when that reactor is available; otherwise it falls back to Mojo's default reactor.</li>
<li>Metrics include throughput, MiB/s, latency percentiles/max, correctness, RSS, server CPU, context switches, callback/syscall counters, EAGAINs, and per-message ratios.</li>
<li>The default is <code>--repeats 3</code>; use a larger value for publication-quality runs. Use <code>--bytes 64,512,4096,16384</code> for multiple payload sizes.</li>
<li>Click any table header to sort. Use the filter box to narrow rows by system, backend, or client count.</li>
<li>The harness automatically adds local <code>blib/lib</code>, <code>blib/arch</code>, and <code>lib</code> to <code>\@INC</code> for Phase18 when run from the distribution root.</li>
</ul></div>
<div class="toolbar"><label>Filter rows: <input type="search" oninput="filterTables(this.value)" placeholder="phase19b, EV, Mojo, clients, backend..."></label><span class="hint">Sortable columns work fully offline in the browser. Click a header once for descending, again for ascending.</span></div>
<div class="legend"><span class="chip row-phase35-xs">Phase35 A: XS native echo</span><span class="chip row-phase35-empty">Phase35 B: native echo + empty Perl callback</span><span class="chip row-phase35-perl">Phase35 C: Perl echo</span><span class="chip row-phase34c">Linux::Event Phase34C pure run</span><span class="chip row-phase34b">Linux::Event Phase34B pure run + fork watchdog</span><span class="chip row-phase34">Linux::Event Phase34 XSLoop</span><span class="chip row-phase33c">Linux::Event Phase33C XSLoop</span><span class="chip row-phase33b">Linux::Event Phase33B XSLoop</span><span class="chip row-phase33a">Linux::Event Phase33A XSLoop</span><span class="chip row-phase32">Linux::Event Phase32 XSLoop</span><span class="chip row-phase31">Linux::Event Phase31 XSLoop</span><span class="chip row-phase30">Linux::Event Phase30 XSLoop</span><span class="chip row-phase29">Linux::Event Phase29 XSLoop</span><span class="chip row-phase26">Linux::Event Phase26 XSLoop</span><span class="chip row-phase25">Linux::Event Phase25 XSLoop</span><span class="chip row-phase24">Linux::Event Phase24 XSLoop</span><span class="chip row-phase23">Linux::Event Phase23 XSLoop</span><span class="chip row-phase22">Linux::Event Phase22 XSLoop</span><span class="chip row-phase21">Linux::Event Phase21 XSLoop</span><span class="chip row-phase20">Linux::Event Phase20 XSLoop</span><span class="chip row-phase19b">Linux::Event Phase19B XSLoop alias</span><span class="chip row-phase18">Linux::Event XSLoop alias</span><span class="chip row-ev">EV</span><span class="chip row-anyevent">AnyEvent</span><span class="chip row-ioasync">IO::Async</span><span class="chip row-mojo">Mojo::IOLoop</span></div>
<h2>Column key</h2>
<table class="sortable"><thead><tr><th>Column</th><th>Meaning</th></tr></thead><tbody>
<tr><td>System</td><td>Perl event-loop library or framework being tested.</td></tr>
<tr><td>Backend</td><td>Actual backend/reactor used where known, such as epoll, EV/libev, IO::Async::Loop::Epoll, or Mojo reactor.</td></tr>
<tr><td>Bytes</td><td>Payload size in bytes for each echo message.</td></tr>
<tr><td>Clients</td><td>Concurrent client connections driven by the selected client driver.</td></tr>
<tr><td>Repeat</td><td>Repeat number for this exact system/client/byte workload.</td></tr>
<tr><td>Messages</td><td>Measured messages only; warmup messages are excluded.</td></tr>
<tr><td>Elapsed s</td><td>Measured server benchmark duration in seconds.</td></tr>
<tr><td>msg/s</td><td>Measured echo messages per second. Higher is better.</td></tr>
<tr><td>MiB/s</td><td>Measured payload throughput in mebibytes per second. Higher is better.</td></tr>
<tr><td>lat p50/p95/p99/max us</td><td>Client-observed round-trip latency percentiles and maximum in microseconds. Lower is better.</td></tr>
<tr><td>CPU %, User CPU, Sys CPU</td><td>Server process CPU use during the measured run. CPU % is total CPU seconds divided by elapsed time.</td></tr>
<tr><td>Vol CS / Nonvol CS</td><td>Voluntary and non-voluntary context switches for the server process during the measured run.</td></tr>
<tr><td>RSS KiB</td><td>Peak resident set size for the isolated case worker in KiB; fresh process per case prevents cumulative VmHWM contamination.</td></tr>
<tr><td>OK</td><td>Correctness check: expected accepts, closes, echoed bytes, client completions, and no timeout.</td></tr>
<tr><td>read cb / sysread / syswrite</td><td>Server-side echo-path counters when visible to the harness. Framework buffering may make some counters less directly comparable.</td></tr>
<tr><td>EAGAIN</td><td>Nonblocking read/write calls that would have blocked.</td></tr>
<tr><td>epoll_wait / ready events / callback calls</td><td>Linux::Event XS backend counters; blank for frameworks that do not expose equivalent counters.</td></tr>
</tbody></table>

<h2>Results: individual runs</h2><table class="sortable"><thead><tr><th>System</th><th>Backend</th><th>Bytes</th><th>Clients</th><th>Repeat</th><th>Messages</th><th>Elapsed s</th><th>msg/s</th><th>MiB/s</th><th>lat p50 us</th><th>lat p95 us</th><th>lat p99 us</th><th>lat max us</th><th>CPU %</th><th>User CPU</th><th>Sys CPU</th><th>Vol CS</th><th>Nonvol CS</th><th>RSS KiB</th><th>OK</th></tr></thead><tbody>
HTML
    for my $r (@$results) {
        print {$fh} '<tr class="'.row_class($r).'">' . join('',
            td($r->{system}), td($r->{backend}), td($r->{bytes}), td($r->{clients}), td($r->{repeat}), td($r->{messages}), td(fmt($r->{elapsed_seconds},4)), td(fmt($r->{messages_per_second},2)), td(fmt($r->{mib_per_second},2)),
            td($r->{lat_p50_us}), td($r->{lat_p95_us}), td($r->{lat_p99_us}), td($r->{lat_max_us}), td(fmt($r->{server_cpu_percent},1)), td(fmt($r->{server_user_cpu_seconds},3)), td(fmt($r->{server_system_cpu_seconds},3)), td($r->{voluntary_ctxt_switches}), td($r->{nonvoluntary_ctxt_switches}), td($r->{max_rss_kb}), td($r->{ok} ? 'yes' : 'NO', $r->{ok} ? 'good' : 'bad', $r->{ok} ? 1 : 0)
        ) . "</tr>\n";
    }

    print {$fh} "</tbody></table>\n<h2>Summary: averages and best-of repeats</h2><table class=\"sortable\"><thead><tr><th>System</th><th>Backend</th><th>Bytes</th><th>Clients</th><th>Repeats OK/Total</th><th>avg msg/s</th><th>best msg/s</th><th>avg MiB/s</th><th>best MiB/s</th><th>avg p50</th><th>avg p95</th><th>avg p99</th><th>avg max</th><th>avg CPU %</th><th>best CPU %</th><th>avg RSS KiB</th></tr></thead><tbody>\n";
    for my $r (@$summary) {
        print {$fh} '<tr class="'.row_class($r).'">' . join('',
            td($r->{system}), td($r->{backend}), td($r->{bytes}), td($r->{clients}), td(($r->{ok_repeats}//0).'/'.($r->{repeats}//0)),
            td(fmt($r->{avg_messages_per_second},2)), td(fmt($r->{best_messages_per_second},2)), td(fmt($r->{avg_mib_per_second},2)), td(fmt($r->{best_mib_per_second},2)),
            td(fmt($r->{avg_lat_p50_us},1)), td(fmt($r->{avg_lat_p95_us},1)), td(fmt($r->{avg_lat_p99_us},1)), td(fmt($r->{avg_lat_max_us},1)),
            td(fmt($r->{avg_server_cpu_percent},1)), td(fmt($r->{best_server_cpu_percent},1)), td(fmt($r->{avg_max_rss_kb},0))
        ) . "</tr>\n";
    }
    print {$fh} "</tbody></table>\n<h2>Echo-path counters</h2><table class=\"sortable\"><thead><tr><th>System</th><th>Bytes</th><th>Clients</th><th>read cb</th><th>sysread</th><th>syswrite</th><th>bytes read</th><th>bytes written</th><th>read EAGAIN</th><th>write EAGAIN</th><th>close reads</th><th>read cb/msg</th><th>sysread/msg</th><th>syswrite/msg</th><th>epoll_wait</th><th>ready events</th><th>callback calls</th></tr></thead><tbody>\n";
    for my $r (@$results) {
        my $msgs_total = ($r->{clients} || 0) * (($r->{messages_per_client} || 0) + ($r->{warmup_per_client} || 0));
        print {$fh} '<tr class="'.row_class($r).'">' . join('',
            td($r->{system}), td($r->{bytes}), td($r->{clients}), td($r->{read_callbacks}), td($r->{sysread_calls}), td($r->{syswrite_calls}), td($r->{bytes_read}), td($r->{bytes_written}), td($r->{read_eagain}), td($r->{write_eagain}), td($r->{close_reads}),
            td($msgs_total ? fmt(($r->{read_callbacks}||0)/$msgs_total,3) : ''), td($msgs_total ? fmt(($r->{sysread_calls}||0)/$msgs_total,3) : ''), td($msgs_total ? fmt(($r->{syswrite_calls}||0)/$msgs_total,3) : ''),
            td($r->{epoll_wait_calls}), td($r->{ready_events_returned}), td($r->{callback_calls})
        ) . "</tr>\n";
    }
    print {$fh} "</tbody></table>\n<h2>XSLoop batching counters</h2><table class=\"sortable\"><thead><tr><th>System</th><th>Clients</th><th>event cap</th><th>epoll_wait</th><th>empty</th><th>full batches</th><th>max batch</th><th>ready/wait</th><th>callbacks/wait</th><th>read ready</th><th>write ready</th><th>error ready</th><th>multi-ready</th></tr></thead><tbody>\n";
    for my $r (@$results) {
        next unless exists $r->{event_capacity};
        my $waits = $r->{epoll_wait_calls} || 0;
        print {$fh} '<tr class="'.row_class($r).'">' . join('',
            td($r->{system}), td($r->{clients}), td($r->{event_capacity}), td($r->{epoll_wait_calls}), td($r->{epoll_wait_empty_calls}), td($r->{epoll_wait_full_batches}), td($r->{epoll_wait_max_batch}),
            td($waits ? fmt(($r->{ready_events_returned}||0)/$waits,2) : ''), td($waits ? fmt(($r->{callback_calls}||0)/$waits,2) : ''),
            td($r->{ready_read_events}), td($r->{ready_write_events}), td($r->{ready_error_events}), td($r->{ready_multi_events})
        ) . "</tr>\n";
    }
    print {$fh} "</tbody></table>\n<h2>XSLoop watcher reclaim counters</h2><table class=\"sortable\"><thead><tr><th>System</th><th>Clients</th><th>reclaim</th><th>alloc</th><th>reuse</th><th>recycle</th><th>destroy</th><th>free depth</th><th>max free depth</th><th>lean watchers</th></tr></thead><tbody>\n";
    for my $r (@$results) {
        next unless exists $r->{watcher_reclaim_enabled};
        print {$fh} '<tr class="'.row_class($r).'">' . join('',
            td($r->{system}), td($r->{clients}), td($r->{watcher_reclaim_enabled}),
            td($r->{watcher_alloc_calls}), td($r->{watcher_reuse_calls}), td($r->{watcher_recycle_calls}), td($r->{watcher_destroy_calls}),
            td($r->{watcher_freelist_depth}), td($r->{watcher_freelist_max_depth}), td($r->{lean_watchers})
        ) . "</tr>\n";
    }
    print {$fh} "</tbody></table><h2>How to read this</h2><p>The benchmark is designed for public comparison: identical client workload, correctness checks, latency distribution, resource usage, server CPU, context switches, callback/syscall counters, EAGAINs, batching counters, and watcher lifecycle counters. Higher msg/s and MiB/s are better; lower latency and fewer callbacks/syscalls per message are better.</p></body></html>\n";
    close $fh;
}
sub row_class ($r) {
    my $k = lc($r->{system_key} // 'unknown');
    $k =~ s/[^a-z0-9_-]+/-/g;
    return "row-$k";
}
sub td ($v, $class='', $sort=undef) { my $c = $class ? qq{ class="$class"} : ''; my $ds = defined $sort ? qq{ data-sort="}.html_escape($sort).qq{"} : ''; return '<td'.$c.$ds.'>'.html_escape(defined $v ? $v : '').'</td>'; }
