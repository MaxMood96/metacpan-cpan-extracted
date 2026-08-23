#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;
use Time::HiRes qw(time);
use Linux::Event::Loop;
use IO::Handle;
use Getopt::Long qw(GetOptions);

# Phase18 does not implement native EPOLLONESHOT yet.
# This benchmark approximates rearm cost using a single fd: read callback disables
# read readiness, consumes one byte, replenishes one byte, then re-enables read.
# It avoids unbounded fd creation and produces one callback per event.
my $events = 100_000;
my $out;
GetOptions('events=i' => \$events, 'out=s' => \$out) or die "bad options\n";

pipe(my $r, my $w) or die $!;
$r->blocking(0);
$w->blocking(0);

my $loop = Linux::Event::Loop->new;
my $count = 0;

my $watcher = $loop->watch_fd(fileno($r), fh => $r, read => sub ($watcher) {
    $watcher->disable_read;
    my $n = sysread($watcher->fh, my $buf, 1);
    return unless defined $n && $n > 0;
    $count += $n;

    if ($count >= $events) {
        $watcher->cancel;
        $loop->stop;
        return;
    }

    syswrite($w, 'x') // die $!;
    $watcher->enable_read;
});

syswrite($w, 'x') // die $!;

my $start = time;
$loop->run;
my $elapsed = time - $start;
my $rate = $count / $elapsed;
my $stats = $loop->stats;
my $json = sprintf qq({"bench":"phase18_dispatch_oneshot_rearm","events":%d,"elapsed":%.9f,"rate":%.2f,"epoll_wait_calls":%d,"ready_events_returned":%d,"callback_calls":%d}\n),
    $count, $elapsed, $rate, $stats->{epoll_wait_calls}, $stats->{ready_events_returned}, $stats->{callback_calls};
if ($out) { open my $fh, '>', $out or die $!; print $fh $json } else { print $json }
