use v5.36;
use Test::More;
use Linux::Event::Loop;

my $loop = Linux::Event::Loop->new;
$loop->enable_watcher_reclaim(1);

pipe(my $r, my $w) or die $!;
$r->blocking(0);
$w->blocking(0);

my $got = 0;
my $watcher;
$watcher = $loop->watch_fd(fileno($r), fh => $r, no_args => 1, lean => 1, read => sub {
    sysread($r, my $buf, 16);
    $got++ if $buf eq 'x';
    $watcher->cancel;
});

syswrite($w, 'x');
$loop->run_once(1000);

my $st = $loop->stats;
is($got, 1, 'lean no-arg callback fired');
is($st->{watcher_reclaim_enabled}, 1, 'watcher reclaim enabled');
is($st->{watcher_recycle_calls}, 1, 'cancelled watcher recycled');
is($st->{watcher_freelist_depth}, 1, 'recycled watcher is on free list after dispatch');

my $watcher2 = $loop->watch_fd(fileno($r), fh => $r, no_args => 1, lean => 1, read => sub {});
$st = $loop->stats;
is($st->{watcher_reuse_calls}, 1, 'next watcher reused recycled storage');
$watcher2->cancel;

done_testing;
