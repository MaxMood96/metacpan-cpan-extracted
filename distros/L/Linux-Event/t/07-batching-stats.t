use v5.36;
use strict;
use warnings;
use Test::More;
use Linux::Event::Loop;

my $loop = Linux::Event::Loop->new;
ok($loop->event_capacity >= 1, 'default event capacity is positive');
$loop->set_event_capacity(64);
is($loop->event_capacity, 64, 'event capacity can be set');

pipe(my $r, my $w) or die "pipe: $!";
$r->blocking(0);
$w->blocking(0);
my $called = 0;
my $watcher;
$watcher = $loop->watch_fd(fileno($r), fh => $r, no_args => 1, read => sub {
    $called++;
    sysread($r, my $buf, 16);
    $watcher->cancel;
});
syswrite($w, "x");
$loop->run_once(1000);
ok($called >= 1, 'read callback fired');
my $st = $loop->stats;
is($st->{event_capacity}, 64, 'stats expose event capacity');
ok(exists $st->{epoll_wait_max_batch}, 'stats expose max batch');
ok(exists $st->{ready_read_events}, 'stats expose read-ready count');
ok(exists $st->{read_callback_calls}, 'stats expose typed callback count');
ok($st->{watcher_lookup_calls} == 0, 'direct watcher path avoids registry lookup');
ok($st->{direct_watcher_events} >= 1, 'direct watcher events counted');
ok($st->{ready_read_events} >= 1, 'read-ready event counted');
ok($st->{read_callback_calls} >= 1, 'read callback counted');

done_testing;
