use v5.36;
use strict;
use warnings;

use Test::More;
use POSIX qw(SIG_BLOCK SIG_UNBLOCK SIGUSR1 SIGUSR2);

use Linux::Event::Loop;
use Linux::Event::Kernel::Signal;

our ($CALLS, $LOOP, $VICTIM, $VISIBLE_AFTER_CANCEL, $DESTROYED);

{
    package T::Signal::CancelOthers;
    use parent 'Linux::Event::Kernel::Signal';
    sub on_signal ($signal, $number, $count) {
        $main::CALLS++;
        $main::VICTIM->cancel;
        $signal->cancel;
        $main::VISIBLE_AFTER_CANCEL = defined $signal->data;
        $main::LOOP->stop;
    }
}

{
    package T::Signal::Victim;
    use parent 'Linux::Event::Kernel::Signal';
    sub on_signal ($signal, $number, $count) { $main::CALLS += 100 }
}

{
    package T::Signal::Tracked;
    sub new ($class) { bless {}, $class }
    sub DESTROY ($self) { $main::DESTROYED++ }
}

{
    package T::Signal::Dies;
    use parent 'Linux::Event::Kernel::Signal';
    sub on_signal ($signal, $number, $count) { die "Signal callback failure\n" }
}

sub mask_contains ($number) {
    my $empty = POSIX::SigSet->new;
    my $current = POSIX::SigSet->new;
    POSIX::sigprocmask(SIG_BLOCK, $empty, $current) == 0
        or die "sigprocmask query: $!";
    return $current->ismember($number);
}

my $usr1_was_blocked = mask_contains(SIGUSR1);
$LOOP = Linux::Event::Loop->new;
$CALLS = 0;
my $owner = $LOOP->add(T::Signal::CancelOthers->new(
    signals => SIGUSR1, data => { retained => 1 },
));
$VICTIM = $LOOP->add(T::Signal::Victim->new(signals => SIGUSR1));
ok(mask_contains(SIGUSR1), 'attachment blocks subscribed signal');
kill SIGUSR1, $$ or die "kill SIGUSR1: $!";
$LOOP->run;
is($CALLS, 1, 'earlier callback can cancel a later fan-out subscriber');
ok($VISIBLE_AFTER_CANCEL,
    'self-cancellation retains callback-visible data until return');
is($owner->state, 'cancelled', 'self-cancelled Signal is terminal');
is($VICTIM->state, 'cancelled', 'cross-cancelled Signal is terminal');
is(mask_contains(SIGUSR1), $usr1_was_blocked,
    'last cancellation restores the original mask state');

my $usr2_was_blocked = mask_contains(SIGUSR2);
my $usr2 = POSIX::SigSet->new(SIGUSR2);
POSIX::sigprocmask(SIG_BLOCK, $usr2) == 0 or die "block SIGUSR2: $!";
my $preblocked_loop = Linux::Event::Loop->new;
my $preblocked = $preblocked_loop->add(
    T::Signal::Victim->new(signals => SIGUSR2),
);
$preblocked->cancel;
ok(mask_contains(SIGUSR2),
    'cancellation preserves a signal blocked before Linux::Event');
POSIX::sigprocmask(SIG_UNBLOCK, $usr2) == 0 or die "unblock SIGUSR2: $!"
    if !$usr2_was_blocked;

my $first_loop = Linux::Event::Loop->new;
my $first_owner = $first_loop->add(
    T::Signal::Victim->new(signals => SIGUSR1),
);
my $second_loop = Linux::Event::Loop->new;
my $second_owner = T::Signal::Victim->new(signals => SIGUSR1);
like(exception(sub { $second_loop->add($second_owner) }),
    qr/already owned by another Loop/,
    'one signal number cannot be consumed by two Loops');
$first_owner->cancel;
is($second_loop->add($second_owner), $second_owner,
    'ownership can transfer after the previous last cancellation');
$second_owner->cancel;

$DESTROYED = 0;
my $destroy_loop = Linux::Event::Loop->new;
my $tracked = T::Signal::Tracked->new;
my $destroy_signal = $destroy_loop->add(
    T::Signal::Victim->new(signals => SIGUSR1, data => $tracked),
);
undef $tracked;
is($DESTROYED, 0, 'active Signal retains application data');
undef $destroy_loop;
is($DESTROYED, 1, 'Loop destruction releases Signal data');
is($destroy_signal->state, 'cancelled',
    'Loop destruction cancels active Signal');
ok(!defined $destroy_signal->loop,
    'Loop destruction clears Signal ownership');

my $error_loop = Linux::Event::Loop->new;
my $error_signal = $error_loop->add(
    T::Signal::Dies->new(signals => SIGUSR1),
);
kill SIGUSR1, $$ or die "kill SIGUSR1: $!";
like(exception(sub { $error_loop->run }), qr/Signal callback failure/,
    'callback exception propagates from Loop');
is($error_signal->state, 'active',
    'throwing callback leaves Signal subscribed');
$error_signal->cancel;

done_testing;

sub exception ($code) {
    local $@;
    eval { $code->(); 1 };
    return $@;
}
