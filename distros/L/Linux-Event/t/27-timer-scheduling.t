use v5.36;
use strict;
use warnings;

use Test::More;
use Time::HiRes qw(sleep);

use Linux::Event::Loop;
use Linux::Event::Kernel::Timer;

our @ORDER;

{
    package T::Timer::Ordered;
    use parent 'Linux::Event::Kernel::Timer';
    sub on_timer ($timer) {
        push @main::ORDER, $timer->data->{number};
        $timer->loop->stop if @main::ORDER == $timer->data->{total};
    }
}

{
    package T::Timer::Recurring;
    use parent 'Linux::Event::Kernel::Timer';
    sub on_timer ($timer) {
        my $state = $timer->data;
        push @{ $state->{expirations} }, $timer->expirations;
        if (@{ $state->{expirations} } == 1) {
            Time::HiRes::sleep(0.035);
        }
        else {
            $timer->cancel;
            $state->{loop}->stop;
        }
    }
}

{
    package T::Timer::Reschedule;
    use parent 'Linux::Event::Kernel::Timer';
    sub on_timer ($timer) {
        my $state = $timer->data;
        $state->{calls}++;
        if ($state->{calls} == 1) {
            $timer->reschedule(after => 0.002);
            $state->{active_during_callback} = $timer->is_active;
        }
        else {
            $state->{loop}->stop;
        }
    }
}

{
    package T::Timer::Spawn;
    use parent 'Linux::Event::Kernel::Timer';
    sub on_timer ($timer) {
        my $state = $timer->data;
        push @{ $state->{events} }, $state->{name};
        if ($state->{name} eq 'first') {
            $state->{loop}->add(T::Timer::Spawn->new(
                after => 0,
                data => {
                    loop => $state->{loop},
                    events => $state->{events},
                    name => 'second',
                },
            ));
        }
        else {
            $state->{loop}->stop;
        }
    }
}

{
    package T::Timer::Batch;
    use parent 'Linux::Event::Kernel::Timer';
    sub on_timer ($timer) { return }
}

my $order_loop = Linux::Event::Loop->new;
my $deadline = Linux::Event::Kernel::Timer->now + 0.01;
for my $number (1 .. 8) {
    $order_loop->add(T::Timer::Ordered->new(
        at => $deadline,
        data => { number => $number, total => 8 },
    ));
}
$order_loop->run;
is_deeply(\@ORDER, [1 .. 8],
    'equal deadlines fire in schedule order');
my $order_stats = $order_loop->stats;
is($order_stats->{timerfd_create_calls}, 1,
    'one Loop creates one shared timerfd');
is($order_stats->{timer_callback_calls}, 8,
    'Timer callbacks are counted');
is($order_stats->{active_timers}, 0,
    'one-shot cohort leaves no active Timers');

my $recurring_loop = Linux::Event::Loop->new;
my $recurring_state = {
    loop => $recurring_loop,
    expirations => [],
};
my $recurring = $recurring_loop->add(T::Timer::Recurring->new(
    every => 0.01,
    data => $recurring_state,
));
$recurring_loop->run;
is($recurring_state->{expirations}[0], 1,
    'first recurring callback represents one tick');
cmp_ok($recurring_state->{expirations}[1], '>=', 3,
    'missed recurring ticks are coalesced');
is(scalar @{ $recurring_state->{expirations} }, 2,
    'missed ticks do not create a catch-up callback storm');
is($recurring->state, 'cancelled',
    'recurring Timer may cancel itself');
cmp_ok($recurring_loop->stats->{timer_coalesced_expirations}, '>=', 2,
    'coalesced expirations are observable');

my $reschedule_loop = Linux::Event::Loop->new;
my $reschedule_state = { loop => $reschedule_loop, calls => 0 };
my $rescheduled = $reschedule_loop->add(T::Timer::Reschedule->new(
    after => 0,
    data => $reschedule_state,
));
$reschedule_loop->run;
is($reschedule_state->{calls}, 2,
    'one-shot can reschedule itself from on_timer');
ok($reschedule_state->{active_during_callback},
    'rescheduled one-shot remains active in its callback');
is($rescheduled->state, 'expired',
    'rescheduled one-shot expires after its final callback');
ok(!defined $rescheduled->data,
    'final one-shot expiration releases data');
is($reschedule_loop->stats->{timer_reschedule_calls}, 1,
    'rescheduling is counted');

my $outside_loop = Linux::Event::Loop->new;
my $outside_state = { loop => $outside_loop, calls => 0 };
my $outside = $outside_loop->add(T::Timer::Reschedule->new(
    after => 60,
    data => $outside_state,
));
is($outside->reschedule(after => 0), $outside,
    'external reschedule returns the same Timer');
$outside_loop->run;
is($outside_state->{calls}, 2,
    'external schedule and in-callback schedule both take effect');

my $spawn_loop = Linux::Event::Loop->new;
my @events;
$spawn_loop->add(T::Timer::Spawn->new(
    after => 0,
    data => {
        loop => $spawn_loop,
        events => \@events,
        name => 'first',
    },
));
$spawn_loop->run;
is_deeply(\@events, [qw(first second)],
    'zero Timer created by callback runs on a later Loop turn');
cmp_ok($spawn_loop->stats->{epoll_wait_calls}, '>=', 2,
    'nested immediate Timer requires a later epoll turn');

my $batch_loop = Linux::Event::Loop->new;
$batch_loop->add(T::Timer::Batch->new(after => 0)) for 1 .. 1_050;
$batch_loop->run_once(100);
is($batch_loop->stats->{timer_callback_calls}, 1_024,
    'one Timer source turn is capped at the fairness batch size');
is($batch_loop->stats->{active_timers}, 26,
    'remaining due Timers stay scheduled after the bounded batch');
$batch_loop->run_once(100);
is($batch_loop->stats->{timer_callback_calls}, 1_050,
    'next Loop turn drains the remaining due Timers');
is($batch_loop->stats->{active_timers}, 0,
    'bounded cohort finishes without losing Timers');

done_testing;
