use v5.36;
use strict;
use warnings;
use Test::More;
use POSIX qw(SIGUSR1);

use Linux::Event::Loop;
use Linux::Event::Signal;

our ($VICTIM, $SECOND_CALLS);

{
    package T::SignalRecoveryPayload;
    our $destroyed = 0;
    sub new ($class) { bless {}, $class }
    sub DESTROY ($self) { $destroyed++ }
}

{
    package T::SignalFirstError;
    use parent 'Linux::Event::Signal';
    sub on_signal ($signal, $number, $count) {
        $main::VICTIM->cancel;
        die "first Signal callback failed\n";
    }
}

{
    package T::SignalSecondSubscriber;
    use parent 'Linux::Event::Signal';
    sub on_signal ($signal, $number, $count) {
        $main::SECOND_CALLS++;
    }
}

pipe(my $reader, my $writer) or die "pipe: $!";
my $loop = Linux::Event::Loop->new;
$loop->enable_watcher_reclaim(1);
$T::SignalRecoveryPayload::destroyed = 0;
$SECOND_CALLS = 0;
my $payload = T::SignalRecoveryPayload->new;
$VICTIM = $loop->watch(
    fd => fileno($reader), data => $payload,
    read => sub ($watcher) { return },
);
undef $payload;

my $first = T::SignalFirstError->new(loop => $loop, signals => SIGUSR1);
my $second = T::SignalSecondSubscriber->new(
    loop => $loop, signals => SIGUSR1,
);
kill SIGUSR1, $$ or die "kill SIGUSR1: $!";
like(exception(sub { $loop->run }), qr/first Signal callback failed/,
    'first Signal callback exception propagates after fan-out');
is($SECOND_CALLS, 1,
    'later Signal subscriber still receives the snapshotted event');
undef $VICTIM;
is($T::SignalRecoveryPayload::destroyed, 1,
    'Signal exception does not strand Loop registration cleanup');
ok($first->is_active && $second->is_active,
    'Signal subscriptions remain active after application exception');

$first->cancel;
$second->cancel;
close $reader;
close $writer;
done_testing;

sub exception ($code) {
    my $error = '';
    eval { $code->(); 1 } or $error = $@;
    return $error;
}
