use v5.36;
use strict;
use warnings;
use Test::More;
use IO::Handle;
use Linux::Event::Loop;

pipe(my $r, my $w) or die "pipe: $!";
$r->blocking(0);
$w->blocking(0);

my $loop = Linux::Event::Loop->new;
my $reads = 0;
my $watcher = $loop->watch_fd(
    fileno($r),
    fh => $r,
    oneshot => 1,
    edge_triggered => 1,
    read => sub ($watcher) {
        $reads++;
        sysread($r, my $buf, 1024);
    },
);

ok($watcher, 'created watcher with oneshot and edge_triggered options');

syswrite($w, "a");
my $n1 = $loop->run_once(100);
ok($n1 >= 1, 'first event delivered');
is($reads, 1, 'oneshot watcher fired once');

syswrite($w, "b");
$loop->run_once(20);
is($reads, 1, 'oneshot watcher did not fire again before rearm');

$watcher->enable_read;
$loop->run_once(100);
is($reads, 2, 'enable_read rearms oneshot watcher');

$watcher->cancel;
done_testing;
