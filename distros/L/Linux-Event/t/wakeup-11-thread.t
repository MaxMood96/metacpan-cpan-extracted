use v5.36;
use strict;
use warnings;

use Config;
use Test::More;

plan skip_all => 'Perl was built without ithreads'
    if !$Config{useithreads};

require threads;
require Thread::Queue;
use Linux::Event::Loop;
use Linux::Event::Kernel::Event;

{
    package T::ThreadWakeup;
    use parent 'Linux::Event::Kernel::Event';
    sub on_event ($self, $count) {
        ${ $self->data } = $count;
        $self->loop->stop;
    }
}

my $loop = Linux::Event::Loop->new;
my $count = 0;
my $wakeup = $loop->add(T::ThreadWakeup->new(data => \$count));

my $worker = threads->create(sub {
    $wakeup->signal(9);
    return 1;
});
is($worker->join, 1, 'worker interpreter completed');
$loop->run;
is($count, 9, 'cloned Wakeup signals original Loop eventfd');
ok($wakeup->is_active, 'worker clone destruction does not close owner eventfd');
$wakeup->cancel;

my $held = T::ThreadWakeup->new;
my $ready = Thread::Queue->new;
my $continue = Thread::Queue->new;
my $holder = threads->create(sub {
    $ready->enqueue(1);
    $continue->dequeue;
    return eval { $held->signal; 1 } ? 1 : 0;
});
$ready->dequeue;
$held->cancel;
$continue->enqueue(1);
is($holder->join, 1,
    'thread clone retains a safe eventfd duplicate after owner cancellation');

my $roundtrip_loop = Linux::Event::Loop->new;
my $roundtrip_count = 0;
my $roundtrip = $roundtrip_loop->add(
    T::ThreadWakeup->new(data => \$roundtrip_count),
);
my $returned = threads->create(sub {
    $roundtrip->signal(4);
    return $roundtrip;
})->join;
$roundtrip_loop->run;
is($roundtrip_count, 4, 'worker signal arrives before object round trip');
like(eval { $returned->cancel; '' } // $@,
    qr/managed only by its creating interpreter/,
    'round-tripped clone cannot manage the owner Wakeup');
like(eval { $returned->signal; '' } // $@,
    qr/belongs to another interpreter/,
    'round-tripped clone cannot use the worker descriptor number');
undef $returned;
ok($roundtrip->is_active,
    'round-tripped clone destruction preserves owner state');

is(threads->create(sub {
    $roundtrip->signal(6);
    return 1;
})->join, 1, 'a later worker receives its own safe descriptor duplicate');
$roundtrip_loop->run;
is($roundtrip_count, 6,
    'owner Wakeup remains usable after clone round-trip destruction');
$roundtrip->cancel;

done_testing;
