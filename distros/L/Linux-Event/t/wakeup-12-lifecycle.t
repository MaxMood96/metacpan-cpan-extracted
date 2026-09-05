use v5.36;
use strict;
use warnings;
use Test::More;
use Scalar::Util qw(weaken);

use Linux::Event::Loop;
use Linux::Event::Kernel::Event;

our ($VICTIM, $OWNER_STATE_DESTROYED);

{
    package Linux::Event::Kernel::Event::_OwnerState;
    sub DESTROY ($self) { $main::OWNER_STATE_DESTROYED++ }
}

{
    package T::WakeupRecoveryPayload;
    our $destroyed = 0;
    sub new ($class) { bless {}, $class }
    sub DESTROY ($self) { $destroyed++ }
}

{
    package T::ErrorWakeup;
    use parent 'Linux::Event::Kernel::Event';
    sub on_event ($wakeup, $count) {
        $main::VICTIM->cancel;
        die "Wakeup callback failed\n";
    }
}

{
    package T::ReleaseWakeup;
    use parent 'Linux::Event::Kernel::Event';
    sub on_event ($wakeup, $count) { return }
}

subtest 'Wakeup exception completes outer Loop cleanup' => sub {
    pipe(my $reader, my $writer) or die "pipe: $!";
    my $loop = Linux::Event::Loop->new;
    $loop->enable_watcher_reclaim(1);
    $T::WakeupRecoveryPayload::destroyed = 0;
    my $payload = T::WakeupRecoveryPayload->new;
    $VICTIM = $loop->watch(
        fd => fileno($reader), data => $payload,
        read => sub ($watcher) { return },
    );
    undef $payload;

    my $wakeup = T::ErrorWakeup->new(loop => $loop);
    $wakeup->signal;
    like(exception(sub { $loop->run_once(100) }),
        qr/Wakeup callback failed/, 'Wakeup callback exception propagates');
    undef $VICTIM;
    is($T::WakeupRecoveryPayload::destroyed, 1,
        'Wakeup exception does not strand registration references');
    ok($wakeup->is_active,
        'Wakeup remains active after application callback exception');
    $wakeup->cancel;

    close $reader;
    close $writer;
};

subtest 'cancelled Wakeup is not retained by its Loop registration' => sub {
    my $loop = Linux::Event::Loop->new;
    my $wakeup = T::ReleaseWakeup->new(loop => $loop);
    my $weak = $wakeup;
    weaken($weak);
    $wakeup->cancel;
    undef $wakeup;
    ok(!defined($weak),
        'cancel releases the callback closure retaining the Wakeup');
};

subtest 'cancel releases private Wakeup owner state' => sub {
    my $loop = Linux::Event::Loop->new;
    $OWNER_STATE_DESTROYED = 0;
    my $wakeup = T::ReleaseWakeup->new(loop => $loop);
    $wakeup->cancel;
    is($OWNER_STATE_DESTROYED, 1,
        'cancel removes the inert owner-state registry entry');
};

done_testing;

sub exception ($code) {
    my $error = '';
    eval { $code->(); 1 } or $error = $@;
    return $error;
}
