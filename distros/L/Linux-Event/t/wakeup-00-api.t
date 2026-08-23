use v5.36;
use strict;
use warnings;

use Test::More;
use Config ();
use lib 't/lib';

use Linux::Event::Loop;
use Linux::Event::Wakeup;

sub exception ($code) {
    local $@;
    return eval { $code->(); 1 } ? '' : "$@";
}

my $interpreter_id = Linux::Event::Wakeup::_interpreter_id();
like("$interpreter_id", qr/\A\d+\z/,
    'interpreter identity is an unsigned integer');
is($interpreter_id, 0,
    'non-multiplicity Perl uses the sole interpreter identity')
    if !$Config::Config{usemultiplicity};

{
    package T::Wakeup;
    use parent 'Linux::Event::Wakeup';
    sub on_wakeup ($self, $count) { push @{ $self->data }, $count }
}

like(exception(sub { Linux::Event::Wakeup->new }), qr/abstract base class/,
    'base class is abstract');

{
    package T::Wakeup::Missing;
    use parent 'Linux::Event::Wakeup';
}
like(exception(sub { T::Wakeup::Missing->new }), qr/must define on_wakeup/,
    'subclass callback is required');

my $loop = Linux::Event::Loop->new;
my $seen = [];
my $wakeup = T::Wakeup->new(data => $seen);
is($wakeup->state, 'unattached', 'starts unattached');
is($loop->add($wakeup), $wakeup, 'Loop add returns exact Wakeup');
is($wakeup->loop, $loop, 'Loop is retained while active');
ok($wakeup->is_active, 'active after attachment');

like(exception(sub { $wakeup->signal(0) }), qr/positive integer/,
    'zero increment is rejected');
like(exception(sub { $wakeup->signal(1.5) }), qr/positive integer/,
    'fractional increment is rejected');
like(exception(sub { $wakeup->signal('18446744073709551615') }),
    qr/supported eventfd range/,
    'eventfd reserved maximum cannot wrap during native conversion');

$wakeup->signal(2)->signal(3);
$loop->run_once(1000);
is_deeply($seen, [5], 'eventfd signals coalesce into one count');

is($wakeup->cancel, $wakeup, 'cancel returns Wakeup');
is($wakeup->cancel, $wakeup, 'cancel is idempotent');
is($wakeup->state, 'cancelled', 'cancel is terminal');
ok($wakeup->is_terminal, 'terminal predicate is true');
is($wakeup->loop, undef, 'cancel releases Loop');
like(exception(sub { $wakeup->signal }), qr/cancelled/,
    'cancelled Wakeup cannot signal');
like(exception(sub { $loop->add($wakeup) }), qr/not unattached/,
    'cancelled Wakeup cannot reattach');

{
    package T::Wakeup::BrokenLoop;
    sub new ($class) { bless {}, $class }
    sub add ($self, $object) { $object->_attach_to_loop($self) }
    sub watch ($self, @option) { die "synthetic registration failure\n" }
}

my $retry = T::Wakeup->new(data => []);
my $broken = T::Wakeup::BrokenLoop->new;
like(exception(sub { $broken->add($retry) }),
    qr/synthetic registration failure/,
    'registration failure propagates');
is($retry->state, 'unattached',
    'registration failure leaves Wakeup attachable');
is($loop->add($retry), $retry,
    'Wakeup can attach after a failed registration attempt');
$retry->cancel;

done_testing;
