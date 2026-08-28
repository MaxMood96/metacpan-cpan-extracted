use v5.36;
use strict;
use warnings;
use Test::More;

use Linux::Event::Loop;
use Linux::Event::Timer;

{
    package T::StopRunOnceTimer;
    use parent 'Linux::Event::Timer';
    our $calls = 0;
    sub on_timer ($timer) {
        $calls++;
        $timer->loop->stop if $calls == 1;
    }
}

{
    package T::NestedRunStopTimer;
    use parent 'Linux::Event::Timer';
    sub on_timer ($timer) { $timer->loop->stop }
}

subtest 'same-Loop driving and event-array mutation are rejected' => sub {
    pipe(my $reader, my $writer) or die "pipe: $!";
    my $loop = Linux::Event::Loop->new;
    my $other = Linux::Event::Loop->new;
    my %error;
    my $nested_timer;
    my $registration = $loop->watch(
        fd   => fileno($reader),
        read => sub ($watcher) {
            sysread($reader, my $buffer, 16);
            $error{run_once} = exception(sub { $loop->run_once(0) });
            $error{run_for} = exception(sub { $loop->run_for(0) });
            $error{other_loop} = exception(sub { $other->run_for(0) });
            $nested_timer = T::NestedRunStopTimer->new(
                loop => $loop, after => 0,
            );
            $error{run} = exception(sub { $loop->run });
            $nested_timer->cancel if $nested_timer->is_active;
            $error{capacity} = exception(sub {
                $loop->set_event_capacity(64);
            });
        },
    );
    syswrite($writer, 'x');
    $loop->run_once(100);

    like($error{run_once}, qr/(?:already running|reentrant|dispatch)/i,
        'nested run_once is rejected');
    like($error{run_for}, qr/(?:already running|reentrant|dispatch)/i,
        'nested run_for is rejected');
    like($error{run}, qr/(?:already running|reentrant|dispatch)/i,
        'nested run is rejected');
    like($error{capacity}, qr/(?:running|dispatch)/i,
        'event capacity cannot change during dispatch');

    is($error{other_loop}, '',
        'a different Loop may be driven from inside a callback');

    $registration->cancel;
    close $reader;
    close $writer;
};

subtest 'run_once consumes prior stop state' => sub {
    my $loop = Linux::Event::Loop->new;
    $T::StopRunOnceTimer::calls = 0;
    T::StopRunOnceTimer->new(loop => $loop, after => 0);
    is($loop->run_once(100), 1, 'first immediate Timer is dispatched');

    T::StopRunOnceTimer->new(loop => $loop, after => 0);
    is($loop->run_once(100), 1,
        'later run_once is not poisoned by stop in prior callback');
    is($T::StopRunOnceTimer::calls, 2, 'both Timers run');
};

subtest 'idle run_for records its epoll wait' => sub {
    my $loop = Linux::Event::Loop->new;
    $loop->reset_stats;
    $loop->run_for(0.005);
    my $stats = $loop->stats;
    cmp_ok($stats->{epoll_wait_calls}, '>=', 1,
        'idle run_for counts epoll_wait');
    cmp_ok($stats->{epoll_wait_empty_calls}, '>=', 1,
        'idle run_for counts empty epoll result');
};

done_testing;

sub exception ($code) {
    my $error = '';
    eval { $code->(); 1 } or $error = $@;
    return $error;
}
