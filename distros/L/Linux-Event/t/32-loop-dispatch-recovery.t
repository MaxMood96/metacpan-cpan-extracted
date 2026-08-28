use v5.36;
use strict;
use warnings;
use Test::More;

use Linux::Event::Loop;
use Linux::Event::Timer;

{
    package T::DispatchErrorTimer;
    use parent 'Linux::Event::Timer';
    sub on_timer ($timer) {
        $timer->data->{registration}->cancel;
        die "timer dispatch failure\n";
    }
}

{
    package T::RecoveryPayload;
    our $destroyed = 0;
    sub new ($class) { bless {}, $class }
    sub DESTROY ($self) { $destroyed++ }
}

subtest 'raw callback exception still completes dispatch cleanup' => sub {
    pipe(my $reader, my $writer) or die "pipe: $!";
    my $loop = Linux::Event::Loop->new;
    $loop->enable_watcher_reclaim(1);

    $T::RecoveryPayload::destroyed = 0;
    my $payload = T::RecoveryPayload->new;
    my $registration;
    $registration = $loop->watch(
        fd   => fileno($reader),
        data => $payload,
        read => sub ($watcher) {
            sysread($reader, my $buffer, 16);
            $watcher->cancel;
            die "raw dispatch failure\n";
        },
    );
    undef $payload;

    syswrite($writer, 'x');
    like(exception(sub { $loop->run_once(100) }),
        qr/raw dispatch failure/, 'raw callback exception propagates');
    undef $registration;
    is($T::RecoveryPayload::destroyed, 1,
        'raw exception does not strand deferred registration references');

    close $reader;
    close $writer;
};

subtest 'Timer exception still completes outer Loop cleanup' => sub {
    pipe(my $reader, my $writer) or die "pipe: $!";
    my $loop = Linux::Event::Loop->new;
    $loop->enable_watcher_reclaim(1);

    $T::RecoveryPayload::destroyed = 0;
    my $payload = T::RecoveryPayload->new;
    my $registration = $loop->watch(
        fd   => fileno($reader),
        data => $payload,
        read => sub ($watcher) { return },
    );
    undef $payload;

    T::DispatchErrorTimer->new(
        loop => $loop, after => 0,
        data => { registration => $registration },
    );
    like(exception(sub { $loop->run_once(100) }),
        qr/timer dispatch failure/, 'Timer callback exception propagates');
    undef $registration;
    is($T::RecoveryPayload::destroyed, 1,
        'Timer exception does not strand deferred registration references');

    close $reader;
    close $writer;
};

done_testing;

sub exception ($code) {
    my $error = '';
    eval { $code->(); 1 } or $error = $@;
    return $error;
}
