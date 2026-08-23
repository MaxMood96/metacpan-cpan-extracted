#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;
use Time::HiRes qw(time);
use Linux::Event::Loop;
use IO::Handle;
use Getopt::Long qw(GetOptions);

# Read-only readiness benchmark.
# Keep one pipe readable, consume one byte per callback, and replenish one byte
# after each read so the benchmark produces one readable dispatch per unit.
my $events = 100_000;
my $prefill = 4096;
my $out;
GetOptions('events=i' => \$events, 'prefill=i' => \$prefill, 'out=s' => \$out) or die "bad options\n";
$prefill = 1 if $prefill < 1;
$prefill = $events if $prefill > $events;

pipe(my $r, my $w) or die $!;
$r->blocking(0);
$w->blocking(0);

my $seed = 'x' x $prefill;
my $off = 0;
while ($off < length($seed)) {
    my $n = syswrite($w, $seed, length($seed) - $off, $off);
    die "prefill write failed: $!" unless defined $n;
    $off += $n;
}

my $loop = Linux::Event::Loop->new;
my ($read, $written) = (0, $prefill);

my $watcher = $loop->watch_fd(fileno($r), fh => $r, read => sub ($watcher) {
    my $fh = $watcher->fh;
    my $n = sysread($fh, my $buf, 1);
    return unless defined $n && $n > 0;
    $read += $n;

    if ($read >= $events) {
        $watcher->cancel;
        $watcher->loop->stop;
        return;
    }

    if ($written < $events) {
        my $m = syswrite($w, 'x');
        die "replenish write failed: $!" unless defined $m;
        $written += $m;
    }
});

my $start = time;
$loop->run;
my $elapsed = time - $start;
my $rate = $read / $elapsed;
my $stats = $loop->stats;
my $json = sprintf qq({"bench":"phase18_dispatch_read_only","events":%d,"elapsed":%.9f,"rate":%.2f,"epoll_wait_calls":%d,"ready_events_returned":%d,"callback_calls":%d}\n),
    $read, $elapsed, $rate, $stats->{epoll_wait_calls}, $stats->{ready_events_returned}, $stats->{callback_calls};
if ($out) { open my $fh, '>', $out or die $!; print $fh $json } else { print $json }
