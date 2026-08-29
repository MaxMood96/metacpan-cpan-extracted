use v5.36;
use Test::More;
use Linux::Event::Loop;

my $loop = Linux::Event::Loop->new;
my $stats = $loop->stats;

for my $key (qw(
    epoll_wait_calls ready_events_returned callback_calls
    epoll_ctl_add_calls epoll_ctl_mod_calls epoll_ctl_del_calls
    watcher_lookup_calls dispatch_events profile_enabled
    epoll_wait_ns epoll_ctl_add_ns epoll_ctl_mod_ns epoll_ctl_del_ns
    watcher_lookup_ns dispatch_ns
)) {
    ok(exists $stats->{$key}, "stats includes $key");
}

is($stats->{profile_enabled}, 0, 'profile disabled by default');
ok(!exists $stats->{callback_ns}, 'first profiling API omits callback timing');

$loop->profile(1);
is($loop->stats->{profile_enabled}, 1, 'profile can be enabled');

$loop->reset_stats;
$stats = $loop->stats;
is($stats->{epoll_wait_calls}, 0, 'reset clears counters');
is($stats->{callback_calls}, 0, 'reset clears callback count');
is($stats->{epoll_wait_ns}, 0, 'reset clears profile time');
is($stats->{profile_enabled}, 1, 'reset keeps profile flag');

$loop->profile(0);
is($loop->stats->{profile_enabled}, 0, 'profile can be disabled');

done_testing;
