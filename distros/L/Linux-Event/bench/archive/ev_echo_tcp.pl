#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;
use IO::Socket::INET;
use IO::Handle;
use Time::HiRes qw(time usleep);
use Getopt::Long qw(GetOptions);
use POSIX qw(:sys_wait_h);
use EV;

my $clients = 1; my $messages = 1000; my $bytes = 64; my $host = '127.0.0.1'; my $timeout = 15;
GetOptions('clients=i'=>\$clients,'messages=i'=>\$messages,'bytes=i'=>\$bytes,'host=s'=>\$host,'timeout=f'=>\$timeout) or die "bad options\n";
my $server = IO::Socket::INET->new(LocalAddr=>$host, LocalPort=>0, Proto=>'tcp', Listen=>512, ReuseAddr=>1) or die $!;
$server->blocking(0); my $port = $server->sockport;
my ($accepted,$closed,$echoed,$read_callbacks,$error_callbacks)=(0,0,0,0,0);
my $expected = $clients*$messages*$bytes;
my %watch; my $timed_out=0;
my $timer = EV::timer($timeout, 0, sub { $timed_out=1; EV::break(EV::BREAK_ALL); });
$watch{server} = EV::io($server, EV::READ, sub {
    while (my $c = $server->accept) {
        $accepted++; $c->blocking(0); my $fd = fileno($c);
        $watch{$fd} = EV::io($c, EV::READ, sub {
            $read_callbacks++;
            while (1) {
                my $n = sysread($c, my $buf, 8192);
                if (defined $n && $n > 0) {
                    $echoed += $n; my $off=0; my $len=length($buf);
                    while ($off < $len) { my $wr=syswrite($c,$buf,$len-$off,$off); last unless defined $wr && $wr>0; $off += $wr; }
                    next;
                }
                if (defined $n && $n == 0) { $closed++; delete $watch{$fd}; close $c; EV::break(EV::BREAK_ALL) if $closed >= $clients; last; }
                last;
            }
        });
    }
});
my @pids;
for (1..$clients) { my $pid=fork(); die "fork failed: $!" unless defined $pid; if (!$pid) {
    my $sock; for (1..1000) { $sock=IO::Socket::INET->new(PeerAddr=>$host,PeerPort=>$port,Proto=>'tcp'); last if $sock; usleep(1000); }
    die "client connect failed\n" unless $sock; my $msg='x'x$bytes;
    for (1..$messages) { syswrite($sock,$msg)==$bytes or die "client write failed: $!"; my $got=''; while (length($got)<$bytes) { my $n=sysread($sock,my $buf,$bytes-length($got)); die "client read failed: $!" unless defined $n; die "server closed\n" if $n==0; $got.=$buf; } }
    close $sock; exit 0;
} push @pids,$pid; }
my $start=time; EV::run; my $elapsed=time-$start;
if ($timed_out) { kill 'TERM', @pids; }
waitpid($_,0) for @pids;
my $rate=($clients*$messages)/$elapsed; my $ok=(!$timed_out && $accepted==$clients && $closed==$clients && $echoed==$expected)?1:0;
printf qq({"bench":"ev_echo_tcp","backend":"EV","clients":%d,"messages_per_client":%d,"bytes":%d,"elapsed":%.9f,"rate":%.2f,"accepted":%d,"closed":%d,"echoed_bytes":%d,"expected_bytes":%d,"ok":%s,"timed_out":%s,"read_callbacks":%d,"error_callbacks":%d}\n), $clients,$messages,$bytes,$elapsed,$rate,$accepted,$closed,$echoed,$expected,($ok?'true':'false'),($timed_out?'true':'false'),$read_callbacks,$error_callbacks;
exit($ok?0:1);
