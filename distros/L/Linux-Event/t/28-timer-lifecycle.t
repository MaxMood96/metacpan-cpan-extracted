use v5.36;
use strict;
use warnings;

use Test::More;

use Linux::Event::Loop;
use Linux::Event::Timer;

our $DESTROYED = 0;
our $FIRED = 0;

{
    package T::Timer::Tracked;
    sub new ($class, $value) { bless { value => $value }, $class }
    sub DESTROY ($self) { $main::DESTROYED++ }
}

{
    package T::Timer::CancelSelf;
    use parent 'Linux::Event::Timer';
    sub on_timer ($timer) {
        my $data = $timer->data;
        $timer->cancel;
        $data->{visible_after_cancel} = defined $timer->data;
        $data->{state_during_callback} = $timer->state;
        $data->{loop}->stop;
    }
}

{
    package T::Timer::Victim;
    use parent 'Linux::Event::Timer';
    sub on_timer ($timer) { $main::FIRED++ }
}

{
    package T::Timer::Canceller;
    use parent 'Linux::Event::Timer';
    sub on_timer ($timer) {
        $timer->data->{victim}->cancel;
    }
}

{
    package T::Timer::Stop;
    use parent 'Linux::Event::Timer';
    sub on_timer ($timer) { $timer->loop->stop }
}

{
    package T::Timer::Dies;
    use parent 'Linux::Event::Timer';
    sub on_timer ($timer) { die "Timer callback failure\n" }
}

{
    package T::Timer::Retained;
    use parent 'Linux::Event::Timer';
    sub on_timer ($timer) {
        $main::FIRED++;
        $timer->loop->stop;
    }
}

my $cancel_loop = Linux::Event::Loop->new;
my $cancel_state = { loop => $cancel_loop };
my $cancel_self = $cancel_loop->add(T::Timer::CancelSelf->new(
    after => 0,
    data => $cancel_state,
));
$cancel_loop->run;
ok($cancel_state->{visible_after_cancel},
    'cancelled Timer data remains visible until callback returns');
is($cancel_state->{state_during_callback}, 'cancelled',
    'cancel state is visible during callback');
ok(!defined $cancel_self->data,
    'cancelled Timer releases data after callback');

$FIRED = 0;
my $cross_loop = Linux::Event::Loop->new;
my $same_deadline = Linux::Event::Timer->now + 0.005;
my $victim = T::Timer::Victim->new(at => $same_deadline);
$cross_loop->add(T::Timer::Canceller->new(
    at => $same_deadline,
    data => { victim => $victim },
));
$cross_loop->add($victim);
$cross_loop->add(T::Timer::Stop->new(after => 0.02));
$cross_loop->run;
is($FIRED, 0, 'earlier callback can cancel another due Timer');
is($victim->state, 'cancelled', 'cancelled due Timer is terminal');

$DESTROYED = 0;
my $cleanup_loop = Linux::Event::Loop->new;
my $tracked = T::Timer::Tracked->new('cancel');
my $cleanup_timer = $cleanup_loop->add(T::Timer::Victim->new(
    after => 60,
    data => $tracked,
));
undef $tracked;
is($DESTROYED, 0, 'active Timer retains its data');
$cleanup_timer->cancel;
is($DESTROYED, 1, 'cancel immediately releases retained data');

$DESTROYED = 0;
my $destroy_loop = Linux::Event::Loop->new;
my $destroy_data = T::Timer::Tracked->new('loop');
my $destroy_timer = $destroy_loop->add(T::Timer::Victim->new(
    after => 60,
    data => $destroy_data,
));
undef $destroy_data;
undef $destroy_loop;
is($DESTROYED, 1, 'Loop destruction releases Timer data');
is($destroy_timer->state, 'cancelled',
    'Loop destruction cancels active Timer');
ok(!defined $destroy_timer->loop,
    'Timer does not retain a destroyed Loop');

my $error_loop = Linux::Event::Loop->new;
my $error_data = { retained => 1 };
my $one_shot_error = $error_loop->add(T::Timer::Dies->new(
    after => 0,
    data => $error_data,
));
my $error = exception(sub { $error_loop->run });
like($error, qr/Timer callback failure/,
    'Timer callback exception propagates from Loop');
is($one_shot_error->state, 'expired',
    'throwing one-shot still reaches expired state');
ok(!defined $one_shot_error->data,
    'throwing one-shot still releases data');

my $recurring_error_loop = Linux::Event::Loop->new;
my $recurring_error = $recurring_error_loop->add(T::Timer::Dies->new(
    every => 0.001,
    data => { retained => 1 },
));
like(exception(sub { $recurring_error_loop->run }),
    qr/Timer callback failure/,
    'recurring callback exception propagates');
is($recurring_error->state, 'active',
    'recurring Timer remains scheduled after callback exception');
ok(defined $recurring_error->data,
    'recurring Timer retains data after callback exception');
$recurring_error->cancel;
ok(!defined $recurring_error->data,
    'later cancellation releases recurring data');

$FIRED = 0;
my $retention_loop = Linux::Event::Loop->new;
$retention_loop->add(T::Timer::Retained->new(after => 0));
$retention_loop->run;
is($FIRED, 1,
    'Loop retains active Timer when caller drops external reference');

done_testing;

sub exception ($code) {
    local $@;
    eval { $code->(); 1 };
    return $@;
}
