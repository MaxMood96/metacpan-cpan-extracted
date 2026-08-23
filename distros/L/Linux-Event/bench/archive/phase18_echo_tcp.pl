#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;
use IO::Socket::INET;
use IO::Handle;
use Time::HiRes qw(time usleep);
use Getopt::Long qw(GetOptions);
use POSIX qw(:sys_wait_h);
use Linux::Event::Loop;

my $clients = 1;
my $messages = 1000;
my $bytes = 64;
my $host = '127.0.0.1';
my $out;
my $timeout = 15;
GetOptions(
    'clients=i'  => \$clients,
    'messages=i' => \$messages,
    'bytes=i'    => \$bytes,
    'host=s'     => \$host,
    'timeout=f'  => \$timeout,
    'out=s'      => \$out,
) or die "bad options\n";

my $server = IO::Socket::INET->new(
    LocalAddr => $host,
    LocalPort => 0,
    Proto     => 'tcp',
    Listen    => 512,
    ReuseAddr => 1,
) or die $!;
$server->blocking(0);
my $port = $server->sockport;

my $loop = Linux::Event::Loop->new;
my $accepted = 0;
my $closed = 0;
my $expected = $clients * $messages * $bytes;
my $echoed = 0;
my $read_callbacks = 0;
my $error_callbacks = 0;
my $server_watcher;

$server_watcher = $loop->watch_fd(fileno($server), fh => $server, read => sub ($w) {
    my $srv = $w->fh;
    while (1) {
        my $c = $srv->accept;
        last unless $c;
        $accepted++;
        $c->blocking(0);
        $loop->watch_fd(fileno($c), fh => $c, read => sub ($cw) {
            $read_callbacks++;
            my $fh = $cw->fh;
            while (1) {
                my $n = sysread($fh, my $buf, 8192);
                if (defined $n && $n > 0) {
                    $echoed += $n;
                    my $off = 0;
                    my $len = length($buf);
                    while ($off < $len) {
                        my $wr = syswrite($fh, $buf, $len - $off, $off);
                        last unless defined $wr && $wr > 0;
                        $off += $wr;
                    }
                    next;
                }
                if (defined $n && $n == 0) {
                    $closed++;
                    $cw->cancel;
                    last;
                }
                last;
            }
        }, error => sub ($cw) {
            $error_callbacks++;
            $closed++;
            $cw->cancel;
        });
    }
});

my @pids;
for (1 .. $clients) {
    my $pid = fork();
    die "fork failed: $!" unless defined $pid;
    if ($pid == 0) {
        my $sock;
        for (1 .. 1000) {
            $sock = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp');
            last if $sock;
            usleep(1000);
        }
        die "client connect failed\n" unless $sock;
        my $msg = 'x' x $bytes;
        for (1 .. $messages) {
            syswrite($sock, $msg) == $bytes or die "client write failed: $!";
            my $got = '';
            while (length($got) < $bytes) {
                my $n = sysread($sock, my $buf, $bytes - length($got));
                die "client read failed: $!" unless defined $n;
                die "server closed\n" if $n == 0;
                $got .= $buf;
            }
        }
        close $sock;
        exit 0;
    }
    push @pids, $pid;
}

my $start = time;
my $deadline = $start + $timeout;
my %reaped;
while ($closed < $clients && time < $deadline) {
    $loop->run_once(1000);
    for my $pid (@pids) {
        next if $reaped{$pid};
        my $r = waitpid($pid, WNOHANG);
        $reaped{$pid} = 1 if $r == $pid;
    }
}

# Reap anything still outstanding. If the benchmark timed out, terminate stragglers
# so a bad run does not leave children behind.
my $timed_out = $closed < $clients ? 1 : 0;
if ($timed_out) {
    for my $pid (@pids) { kill 'TERM', $pid unless $reaped{$pid}; }
}
for my $pid (@pids) {
    waitpid($pid, 0) unless $reaped{$pid};
}

my $elapsed = time - $start;
my $rate = ($clients * $messages) / $elapsed;
my $stats = $loop->stats;
my $ok = (!$timed_out && $accepted == $clients && $closed == $clients && $echoed == $expected) ? 1 : 0;
my $json = sprintf qq({"bench":"phase18_echo_tcp","clients":%d,"messages_per_client":%d,"bytes":%d,"elapsed":%.9f,"rate":%.2f,"accepted":%d,"closed":%d,"echoed_bytes":%d,"expected_bytes":%d,"ok":%s,"timed_out":%s,"read_callbacks":%d,"error_callbacks":%d,"epoll_wait_calls":%d,"ready_events_returned":%d,"callback_calls":%d}\n),
    $clients, $messages, $bytes, $elapsed, $rate, $accepted, $closed, $echoed, $expected,
    ($ok ? 'true' : 'false'), ($timed_out ? 'true' : 'false'), $read_callbacks, $error_callbacks,
    $stats->{epoll_wait_calls}, $stats->{ready_events_returned}, $stats->{callback_calls};
if ($out) { open my $fh, '>', $out or die $!; print $fh $json } else { print $json }
exit($ok ? 0 : 1);
