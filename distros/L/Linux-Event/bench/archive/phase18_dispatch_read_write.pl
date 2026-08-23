#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;
use Time::HiRes qw(time);
use Linux::Event::Loop;
use IO::Handle;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);
use Getopt::Long qw(GetOptions);

# Controlled read/write callback benchmark.
# One socket endpoint is watched for write readiness and the other for read readiness.
# The write callback sends exactly one byte, disables write, and the read callback
# consumes exactly one byte and re-enables write. This avoids kernel coalescing hiding
# callback cost behind large sysread/syswrite batches.
my $messages = 100_000;
my $out;
GetOptions('messages=i' => \$messages, 'out=s' => \$out) or die "bad options\n";

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die $!;
$a->blocking(0);
$b->blocking(0);

my $loop = Linux::Event::Loop->new;
my ($sent, $recv) = (0, 0);
my ($wa, $wb);

$wa = $loop->watch_fd(fileno($a), fh => $a,
    write => sub ($w) {
        return if $sent >= $messages;
        my $n = syswrite($w->fh, 'x');
        return unless defined $n && $n > 0;
        $sent += $n;
        $w->disable_write;
    },
);

$wb = $loop->watch_fd(fileno($b), fh => $b,
    read => sub ($w) {
        my $n = sysread($w->fh, my $buf, 1);
        return unless defined $n && $n > 0;
        $recv += $n;
        if ($recv >= $messages) {
            $wa->cancel;
            $w->cancel;
            $loop->stop;
        } else {
            $wa->enable_write;
        }
    },
);

my $start = time;
$loop->run;
my $elapsed = time - $start;
my $rate = $recv / $elapsed;
my $stats = $loop->stats;
my $json = sprintf qq({"bench":"phase18_dispatch_read_write_controlled","messages":%d,"elapsed":%.9f,"rate":%.2f,"epoll_wait_calls":%d,"ready_events_returned":%d,"callback_calls":%d}\n),
    $recv, $elapsed, $rate, $stats->{epoll_wait_calls}, $stats->{ready_events_returned}, $stats->{callback_calls};
if ($out) { open my $fh, '>', $out or die $!; print $fh $json } else { print $json }
