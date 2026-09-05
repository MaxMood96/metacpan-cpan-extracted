use v5.36;
use strict;
use warnings;

use Test::More;
use POSIX qw(INFINITY NAN);
use Time::HiRes qw(sleep);

use Linux::Event::Loop;
use Linux::Event::Kernel::Timer;

{
    package T::Timer::Basic;
    use parent 'Linux::Event::Kernel::Timer';
    sub on_timer ($timer) { return }
}

{
    package T::Timer::Inherited;
    use parent -norequire, 'T::Timer::Basic';
}

{
    package T::Timer::Missing;
    use parent 'Linux::Event::Kernel::Timer';
}

like(exception(sub { Linux::Event::Kernel::Timer->new(after => 1) }),
    qr/abstract base class/, 'base Timer is abstract');
like(exception(sub { T::Timer::Missing->new(after => 1) }),
    qr/must define on_timer/, 'concrete Timer requires on_timer');
like(exception(sub { T::Timer::Basic->new }),
    qr/one of after, at, or every is required/, 'schedule is required');
like(exception(sub { T::Timer::Basic->new(after => 1, at => 2) }),
    qr/mutually exclusive/, 'after and at are mutually exclusive');
like(exception(sub { T::Timer::Basic->new(every => 0) }),
    qr/every must be a positive number/, 'recurring interval must be positive');
like(exception(sub { T::Timer::Basic->new(after => -1) }),
    qr/after must be a non-negative number/, 'negative delay is rejected');
like(exception(sub { T::Timer::Basic->new(after => 'later') }),
    qr/after must be a non-negative number/, 'nonnumeric delay is rejected');
like(exception(sub { T::Timer::Basic->new(after => NAN) }),
    qr/after must be a non-negative number/, 'NaN delay is rejected');
like(exception(sub { T::Timer::Basic->new(every => INFINITY) }),
    qr/every must be a positive number/, 'infinite interval is rejected');
like(exception(sub { T::Timer::Basic->new(after => 1, mystery => 1) }),
    qr/unknown options: mystery/, 'unknown construction option is rejected');
like(exception(sub { T::Timer::Basic->new(after => 1, loop => 'invalid') }),
    qr/loop must be an object implementing add/,
    'loop constructor option is validated consistently');

my $loop = Linux::Event::Loop->new;
my $data = { name => 'detached' };
my $timer = T::Timer::Basic->new(after => 2, data => $data);
isa_ok($timer, 'T::Timer::Basic');
isa_ok($timer, 'Linux::Event::Kernel::Timer');
is($timer->state, 'unattached', 'new Timer starts unattached');
ok(!$timer->is_active, 'unattached Timer is not active');
ok(!$timer->is_terminal, 'unattached Timer is not terminal');
is($timer->data, $data, 'Timer retains application data');
is($timer->interval, 0, 'one-shot interval is zero');
ok(!defined $timer->deadline,
    'detached relative Timer has no absolute deadline');
ok(!defined $timer->loop, 'detached Timer has no Loop');

is($loop->add($timer), $timer, 'Loop add returns the same Timer');
is($timer->loop, $loop, 'attachment stores the Loop');
is($timer->state, 'active', 'attached Timer is active');
ok($timer->is_active, 'active predicate is true');
ok(defined($timer->deadline) && $timer->deadline > Linux::Event::Kernel::Timer->now,
    'attachment computes a future relative deadline');
like(exception(sub { $loop->add($timer) }), qr/not unattached/,
    'Timer cannot be attached twice');

is($timer->cancel, $timer, 'cancel returns the Timer');
is($timer->state, 'cancelled', 'cancel makes Timer terminal');
ok($timer->is_terminal, 'cancelled Timer is terminal');
ok(!defined $timer->data, 'cancel releases application data');
ok(!defined $timer->loop, 'cancel releases Loop reference');
is($timer->cancel, $timer, 'cancel is idempotent');
like(exception(sub { $timer->reschedule(after => 1) }),
    qr/not active/, 'cancelled Timer cannot be rescheduled');
like(exception(sub { $timer->data({}) }), qr/terminal/,
    'terminal Timer cannot retain new data');

my $now = Linux::Event::Kernel::Timer->now;
sleep 0.002;
cmp_ok(Linux::Event::Kernel::Timer->now, '>', $now,
    'Timer now uses an advancing monotonic clock');

my $absolute = Linux::Event::Kernel::Timer->now + 5;
my $at = T::Timer::Inherited->new(at => $absolute, every => 2);
cmp_ok(abs($at->deadline - $absolute), '<', 0.000_001,
    'detached absolute Timer exposes its deadline');
cmp_ok(abs($at->interval - 2), '<', 0.000_001,
    'recurring interval is exposed');
$at->cancel;

my $immediate_loop = Linux::Event::Loop->new;
my $immediate = T::Timer::Basic->new(
    loop => $immediate_loop,
    after => 10,
);
is($immediate->loop, $immediate_loop,
    'loop constructor option attaches immediately');
$immediate->cancel;

ok(!$loop->can('timer'), 'Loop has no timer factory method');
ok(!$loop->can('after'), 'Loop has no after method');
ok(!$loop->can('at'), 'Loop has no at method');
ok(!$loop->can('every'), 'Loop has no every method');
ok(!$loop->can('now'), 'Loop has no Timer clock method');

done_testing;

sub exception ($code) {
    local $@;
    eval { $code->(); 1 };
    return $@;
}
