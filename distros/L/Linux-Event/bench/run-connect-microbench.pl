#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use File::Basename qw(dirname);
use File::Path qw(make_path);
use FindBin qw($Bin);
use Getopt::Long qw(GetOptions);
use JSON::PP qw();
use POSIX qw(strftime uname);
use Socket qw(
    AF_INET INADDR_LOOPBACK
    SOCK_STREAM SOCK_NONBLOCK SOCK_CLOEXEC
    SOL_SOCKET SO_ERROR SO_LINGER SO_REUSEADDR SOMAXCONN
    pack_sockaddr_in unpack_sockaddr_in
);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

use Linux::Event::Stream;
use Linux::Event::Loop;

my @modes = qw(manual add loop);
my @clients = (1, 10, 100);
my $connections = 10_000;
my $repeats = 6;
my $timeout = 30;
my $json_path;
my $help = 0;

GetOptions(
    'modes=s'       => sub { @modes = split /,/, $_[1] },
    'clients=s'     => sub { @clients = map { 0 + $_ } split /,/, $_[1] },
    'connections=i' => \$connections,
    'repeats=i'     => \$repeats,
    'timeout=f'     => \$timeout,
    'json=s'        => \$json_path,
    'help'          => \$help,
) or usage(1);
usage(0) if $help;

die "connections must be positive\n" if $connections < 1;
die "repeats must be positive\n" if $repeats < 1;
die "timeout must be positive\n" if $timeout <= 0;
die "clients must be positive\n" if grep { $_ < 1 } @clients;
my %valid_mode = map { $_ => 1 } qw(manual add loop);
die "modes must contain only manual, add, or loop\n"
    if grep { !$valid_mode{$_} } @modes;
my %seen_mode;
die "modes must not contain duplicates\n"
    if grep { $seen_mode{$_}++ } @modes;

{
    package BenchConnectStream;
    use parent 'Linux::Event::Stream';

    sub on_data ($stream, $bytes) { }

    sub on_ready ($stream) {
        main::enable_abortive_close($stream->fh);
        $stream->close;
        main::complete_request($stream->data);
    }

    sub on_error ($stream, $error) {
        die "benchmark connection failed: $error\n";
    }
}

sub complete_request ($run) {
    $run->{active}--;
    $run->{completed}++;
    launch_requests($run);
    finish_if_done($run);
    return;
}

sub manual_connected ($registration) {
    my $run = $registration->data;
    my $fh = $registration->fh;
    my $packed = getsockopt($fh, SOL_SOCKET, SO_ERROR);
    my $errno = defined($packed) ? unpack('i', $packed) : 0 + $!;
    if ($errno) {
        local $! = $errno;
        die "manual benchmark connection failed: $!\n";
    }
    $registration->cancel;
    enable_abortive_close($fh);
    close $fh;
    complete_request($run);
    return;
}

sub launch_manual ($run) {
    socket(my $fh, AF_INET,
        SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0)
        or die "manual client socket: $!\n";
    my $connected = connect(
        $fh, pack_sockaddr_in($run->{port}, INADDR_LOOPBACK),
    );
    die "manual client connect: $!\n" if !$connected && !$!{EINPROGRESS};
    $run->{loop}->watch(
        fh    => $fh,
        data  => $run,
        write => \&manual_connected,
        error => \&manual_connected,
    );
    return;
}

sub enable_abortive_close ($fh) {
    setsockopt($fh, SOL_SOCKET, SO_LINGER, pack('ii', 1, 0))
        or die "client SO_LINGER: $!\n";
    return;
}

sub finish_if_done ($run) {
    $run->{loop}->stop
        if $run->{completed} == $run->{connections}
            && $run->{accepted} == $run->{connections};
    return;
}

sub accept_ready ($watcher) {
    my $run = $watcher->data;
    while (accept(my $peer, $run->{listener})) {
        close $peer;
        $run->{accepted}++;
    }
    finish_if_done($run);
    return;
}

sub launch_requests ($run) {
    while ($run->{active} < $run->{clients}
        && $run->{started} < $run->{connections}) {
        $run->{started}++;
        $run->{active}++;
        if ($run->{mode} eq 'manual') {
            launch_manual($run);
        } elsif ($run->{mode} eq 'loop') {
            BenchConnectStream->connect(
                loop    => $run->{loop},
                host    => '127.0.0.1',
                port    => $run->{port},
                timeout => $timeout,
                data    => $run,
            );
        } else {
            my $stream = BenchConnectStream->connect(
                host    => '127.0.0.1',
                port    => $run->{port},
                timeout => $timeout,
                data    => $run,
            );
            $run->{loop}->add($stream);
        }
    }
    return;
}

sub one_run ($mode, $client_count) {
    socket(my $listener, AF_INET,
        SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0)
        or die "listener socket: $!\n";
    setsockopt($listener, SOL_SOCKET, SO_REUSEADDR, pack('i', 1))
        or die "setsockopt SO_REUSEADDR: $!\n";
    bind($listener, pack_sockaddr_in(0, INADDR_LOOPBACK))
        or die "listener bind: $!\n";
    listen($listener, SOMAXCONN) or die "listener listen: $!\n";
    my ($port) = unpack_sockaddr_in(getsockname($listener));

    my $loop = Linux::Event::Loop->new;
    $loop->enable_watcher_reclaim(1);
    my $run = {
        mode        => $mode,
        clients     => $client_count,
        connections => $connections,
        loop        => $loop,
        listener    => $listener,
        port        => $port,
        started     => 0,
        active      => 0,
        completed   => 0,
        accepted    => 0,
    };
    my $accept_watcher = $loop->watch(
        fh   => $listener,
        data => $run,
        read => \&accept_ready,
    );

    my $wall_start = clock_gettime(CLOCK_MONOTONIC);
    my ($user_start, $system_start) = (times)[0, 1];
    launch_requests($run);
    $loop->run;
    my ($user_end, $system_end) = (times)[0, 1];
    my $elapsed = clock_gettime(CLOCK_MONOTONIC) - $wall_start;
    my $cpu = ($user_end - $user_start) + ($system_end - $system_start);

    $accept_watcher->cancel;
    close $listener;
    die "benchmark completed $run->{completed} of $connections connections\n"
        if $run->{completed} != $connections;
    die "benchmark accepted $run->{accepted} of $connections connections\n"
        if $run->{accepted} != $connections;
    return {
        rate      => $connections / $elapsed,
        cpu_us    => $cpu * 1_000_000 / $connections,
        accepted  => $run->{accepted},
        completed => $run->{completed},
    };
}

sub median (@values) {
    @values = sort { $a <=> $b } @values;
    my $middle = int(@values / 2);
    return @values % 2
        ? $values[$middle]
        : ($values[$middle - 1] + $values[$middle]) / 2;
}

say 'Median loopback TCP Stream connection lifecycle benchmark';
say "Linux::Event version $Linux::Event::Stream::VERSION";
printf "%-8s %8s %14s %14s\n",
    qw(mode clients connects/s cpu_us/connect);
my @records;
my @summary;
for my $client_count (@clients) {
    my %result;
    for my $repeat (0 .. $repeats - 1) {
        my $offset = $repeat % @modes;
        my @order = (@modes[$offset .. $#modes], @modes[0 .. $offset - 1]);
        for my $position (0 .. $#order) {
            my $mode = $order[$position];
            my $row = one_run($mode, $client_count);
            $row->{mode} = $mode;
            $row->{clients} = $client_count;
            $row->{repeat} = $repeat + 1;
            $row->{order_position} = $position + 1;
            push @{ $result{$mode} }, $row;
            push @records, $row;
        }
    }
    for my $mode (@modes) {
        my $row = {
            mode => $mode,
            clients => $client_count,
            connects_per_second => median(
                map { $_->{rate} } @{ $result{$mode} }
            ),
            cpu_us_per_connect => median(
                map { $_->{cpu_us} } @{ $result{$mode} }
            ),
        };
        push @summary, $row;
        printf "%-8s %8d %14.1f %14.3f\n",
            $mode,
            $client_count,
            $row->{connects_per_second},
            $row->{cpu_us_per_connect};
    }
}

if (defined $json_path) {
    my @uname = uname();
    my $report = {
        benchmark => 'linux-event-connect-lifecycle',
        benchmark_contract_version => 1,
        generated_at => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime),
        environment => {
            linux_event_version => $Linux::Event::Stream::VERSION,
            perl => "$^V",
            uname => \@uname,
            git_commit => git_commit(),
        },
        configuration => {
            modes => \@modes,
            clients => \@clients,
            connections => $connections,
            repeats => $repeats,
            timeout => $timeout,
            execution_order => 'balanced cyclic rotation',
            teardown => 'abortive connected-client close',
        },
        records => \@records,
        summary => \@summary,
        notes => [
            'Every row performs nonblocking TCP connection setup and teardown.',
            'Manual is a raw nonblocking socket and Loop registration baseline.',
            'Add uses detached MyStream->connect followed by Loop->add.',
            'Loop supplies loop => directly to MyStream->connect.',
            'The timeout is a per-request catastrophic deadline, not the measured row duration.',
            'Compare only results with the same benchmark contract and configuration.',
        ],
    };
    my $dir = dirname($json_path);
    make_path($dir) if $dir ne '.' && !-d $dir;
    open my $out, '>', $json_path or die "open $json_path: $!\n";
    print {$out} JSON::PP->new->canonical->pretty->encode($report);
    close $out or die "close $json_path: $!\n";
    say "Wrote $json_path";
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

sub usage ($exit) {
    print <<'USAGE';
Usage: perl -Mblib bench/run-connect-microbench.pl [options]

  --modes=LIST          manual,add,loop (default: all three)
  --clients=LIST        concurrent requests (default: 1,10,100)
  --connections=N       completed connections per row (default: 10000)
  --repeats=N           median repetitions (default: 6)
  --timeout=SECONDS     catastrophic connection deadline (default: 30)
  --json=PATH           write raw records and summaries as JSON
  --help

Manual uses a raw nonblocking socket plus an opaque Loop registration. Add uses
detached MyStream->connect followed by Loop->add. Loop passes loop => directly
to MyStream->connect. Both public Stream rows preserve one object across
connection acquisition, readiness, and close. Every successfully connected
client uses equal abortive teardown so repeated rows do not exhaust
the host with client-side TIME_WAIT sockets. Repeat execution order rotates to
reduce bias; use a repeat count divisible by three for balanced execution.
USAGE
    exit $exit;
}
