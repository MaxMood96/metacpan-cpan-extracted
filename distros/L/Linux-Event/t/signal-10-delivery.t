use v5.36;
use strict;
use warnings;

use Test::More;
use POSIX qw(SIGUSR1 SIGUSR2);

use Linux::Event::Loop;
use Linux::Event::Kernel::Signal;

our (@EVENTS, $EXPECTED, $LOOP);

{
    package T::Signal::Collect;
    use parent 'Linux::Event::Kernel::Signal';
    sub on_signal ($signal, $number, $count) {
        push @main::EVENTS, [$signal->data, $number, $count];
        $main::LOOP->stop if @main::EVENTS >= $main::EXPECTED;
    }
}

$LOOP = Linux::Event::Loop->new;
@EVENTS = ();
$EXPECTED = 2;
my $multi = $LOOP->add(T::Signal::Collect->new(
    signals => [SIGUSR1, SIGUSR2], data => 'multi',
));
kill SIGUSR2, $$ or die "kill SIGUSR2: $!";
kill SIGUSR1, $$ or die "kill SIGUSR1: $!";
$LOOP->run;
is_deeply([map { $_->[1] } @EVENTS], [SIGUSR1, SIGUSR2],
    'one object receives each subscribed signal in numeric order');
is_deeply([map { $_->[2] } @EVENTS], [1, 1],
    'separate standard signals each report one observed record');
$multi->cancel;

my $realtime = POSIX::SIGRTMIN();
$LOOP = Linux::Event::Loop->new;
@EVENTS = ();
$EXPECTED = 2;
my $first = $LOOP->add(T::Signal::Collect->new(
    signals => $realtime, data => 'first',
));
my $second = $LOOP->add(T::Signal::Collect->new(
    signals => $realtime, data => 'second',
));
kill $realtime, $$ or die "kill realtime: $!" for 1 .. 5;
$LOOP->run;
is_deeply([map { $_->[0] } @EVENTS], [qw(first second)],
    'same-signal subscribers run in attachment order');
is_deeply([map { $_->[2] } @EVENTS], [5, 5],
    'every subscriber receives the complete real-time aggregate count');
$first->cancel;
$second->cancel;

done_testing;
