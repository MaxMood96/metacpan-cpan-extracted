use v5.36;
use strict;
use warnings;

use Test::More;
use POSIX qw(SIGKILL SIGSTOP SIGUSR1 SIGUSR2);

use Linux::Event::Loop;
use Linux::Event::Kernel::Signal;

{
    package T::Signal::Basic;
    use parent 'Linux::Event::Kernel::Signal';
    sub on_signal ($signal, $number, $count) { return }
}

{
    package T::Signal::Inherited;
    use parent -norequire, 'T::Signal::Basic';
}

{
    package T::Signal::Missing;
    use parent 'Linux::Event::Kernel::Signal';
}

like(exception(sub { Linux::Event::Kernel::Signal->new(signals => SIGUSR1) }),
    qr/abstract base class/, 'base Signal is abstract');
like(exception(sub { T::Signal::Missing->new(signals => SIGUSR1) }),
    qr/must define on_signal/, 'concrete Signal requires on_signal');
like(exception(sub { T::Signal::Basic->new }),
    qr/signals is required/, 'signals option is required');
like(exception(sub { T::Signal::Basic->new(signals => []) }),
    qr/at least one/, 'empty signal list is rejected');
like(exception(sub { T::Signal::Basic->new(signals => 0) }),
    qr/positive integer/, 'signal zero is rejected');
like(exception(sub { T::Signal::Basic->new(signals => 'TERM') }),
    qr/positive integer/, 'signal names are not guessed');
like(exception(sub { T::Signal::Basic->new(signals => SIGKILL) }),
    qr/cannot be used with signalfd/, 'SIGKILL is rejected');
like(exception(sub { T::Signal::Basic->new(signals => SIGSTOP) }),
    qr/cannot be used with signalfd/, 'SIGSTOP is rejected');
like(exception(sub { T::Signal::Basic->new(
    signals => '18446744073709551631',
) }), qr/cannot be used with signalfd/,
    'oversized signal number cannot wrap during native conversion');
like(exception(sub {
    T::Signal::Basic->new(signals => SIGUSR1, surprise => 1)
}), qr/unknown options: surprise/, 'unknown option is rejected');
like(exception(sub {
    T::Signal::Basic->new(signals => SIGUSR1, loop => 'invalid')
}), qr/loop must be an object implementing add\(\) and watch\(\)/,
    'loop constructor option is validated consistently');

my $data = { name => 'signal-data' };
my $signal = T::Signal::Inherited->new(
    signals => [SIGUSR1, SIGUSR2, SIGUSR1], data => $data,
);
isa_ok($signal, 'T::Signal::Inherited');
isa_ok($signal, 'Linux::Event::Kernel::Signal');
is_deeply($signal->signals, [SIGUSR1, SIGUSR2],
    'duplicates are removed in first-occurrence order');
is($signal->state, 'unattached', 'new Signal starts unattached');
ok(!$signal->is_active, 'unattached Signal is not active');
ok(!$signal->is_terminal, 'unattached Signal is not terminal');
is($signal->data, $data, 'unattached Signal retains data');
ok(!defined $signal->loop, 'unattached Signal has no Loop');

my $replacement = { name => 'replacement' };
is($signal->data($replacement), $replacement, 'data can be replaced');
is($signal->cancel, $signal, 'detached cancellation returns Signal');
is($signal->state, 'cancelled', 'cancellation is terminal');
ok($signal->is_terminal, 'cancelled predicate is true');
ok(!defined $signal->data, 'cancellation releases data');
is($signal->cancel, $signal, 'cancellation is idempotent');
like(exception(sub { $signal->data({}) }), qr/terminal/,
    'terminal Signal cannot retain new data');

my $loop = Linux::Event::Loop->new;
my $active = T::Signal::Basic->new(signals => SIGUSR1);
is($loop->add($active), $active, 'Loop add returns exact Signal');
is($active->loop, $loop, 'attachment stores Loop');
is($active->state, 'active', 'attached Signal is active');
like(exception(sub { $loop->add($active) }), qr/not unattached/,
    'Signal cannot be attached twice');
$active->cancel;

my $immediate_loop = Linux::Event::Loop->new;
my $immediate = T::Signal::Basic->new(
    loop => $immediate_loop, signals => SIGUSR2,
);
is($immediate->loop, $immediate_loop,
    'loop constructor option attaches immediately');
$immediate->cancel;

ok(!$loop->can('signal'), 'Loop has no Signal factory method');

done_testing;

sub exception ($code) {
    local $@;
    eval { $code->(); 1 };
    return $@;
}
