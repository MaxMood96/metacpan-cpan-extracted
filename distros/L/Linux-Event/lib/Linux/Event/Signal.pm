package Linux::Event::Signal;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.105';

use Carp qw(croak);
use Hash::Util::FieldHash qw(fieldhash);
use POSIX qw(SIGKILL SIGRTMAX SIGSTOP);
use Scalar::Util qw(weaken);

require Linux::Event::Loop;
require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

my %CLASS_DESCRIPTOR;
fieldhash my %ENGINE_FOR_LOOP;

sub _descriptor_for ($class) {
    return $CLASS_DESCRIPTOR{$class} if exists $CLASS_DESCRIPTOR{$class};
    croak 'Linux::Event::Signal is an abstract base class'
        if $class eq __PACKAGE__;
    croak "$class is not a Linux::Event::Signal subclass"
        if !$class->isa(__PACKAGE__);
    my $callback = $class->can('on_signal')
        // croak "$class must define on_signal()";
    return $CLASS_DESCRIPTOR{$class}
        = Linux::Event::Signal::_Descriptor->new($callback);
}

sub _numbers ($value) {
    my @number = ref($value) eq 'ARRAY' ? @$value : ($value);
    croak 'new(): signals must contain at least one signal number' if !@number;
    my (%seen, @unique);
    for my $number (@number) {
        croak 'new(): every signal must be a positive integer'
            if !defined($number) || ref($number) || $number !~ /\A\d+\z/
            || $number == 0;
        my $digits = "$number";
        $digits =~ s/\A0+//;
        my $maximum = '' . SIGRTMAX;
        croak "signal number $number cannot be used with signalfd"
            if length($digits) > length($maximum)
            || (length($digits) == length($maximum)
                && $digits gt $maximum)
            || $number == SIGKILL || $number == SIGSTOP;
        $number = 0 + $number;
        push @unique, $number if !$seen{$number}++;
    }
    return \@unique;
}

sub new ($class, %option) {
    croak 'new(): must be called as a class method' if ref $class;
    my $loop = delete $option{loop};
    croak 'new(): loop must be an object implementing add() and watch()'
        if defined($loop) && (!ref($loop) || !$loop->can('add')
            || !$loop->can('watch'));
    my $data = delete $option{data};
    croak 'new(): signals is required' if !exists $option{signals};
    my $numbers = _numbers(delete $option{signals});
    croak 'new(): unknown options: ' . join(', ', sort keys %option) if %option;
    my $signal = $class->_new_native(
        _descriptor_for($class), $numbers, $data,
    );
    $loop->add($signal) if defined $loop;
    return $signal;
}

sub _attach_to_loop ($self, $loop) {
    my $engine = $ENGINE_FOR_LOOP{$loop}
        //= Linux::Event::Signal::_Engine->_new($loop);
    return $self->_attach_native($loop, $engine->{native});
}

sub _objects_for_loop ($class, $loop) {
    my $engine = $ENGINE_FOR_LOOP{$loop};
    return $engine ? $engine->{native}->objects : [];
}

sub CLONE ($class) {
    %CLASS_DESCRIPTOR = ();
    %ENGINE_FOR_LOOP = ();
    return;
}

sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Signal::_Descriptor;
sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Signal::_Service;
sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Signal::_Engine;
use v5.36;
use strict;
use warnings;

sub CLONE_SKIP ($class) { 1 }

sub _new ($class, $loop) {
    my $self = bless {
        loop   => $loop,
        native => Linux::Event::Signal::_Service->new,
    }, $class;
    Scalar::Util::weaken($self->{loop});
    my $ready = sub { $self->{native}->dispatch };
    my $failed = sub { die "Linux::Event Signal event source failed\n" };
    $loop->watch(
        fd      => $self->{native}->fd,
        _internal => 1,
        read    => $ready,
        error   => $failed,
        no_args => 1,
        lean    => 1,
    );
    return $self;
}

1;

__END__

=head1 NAME

Linux::Event::Signal - subclass-defined Linux signalfd subscriptions

=head1 SYNOPSIS

  package LE::Shutdown;
  use parent 'Linux::Event::Signal';
  use POSIX qw(SIGINT SIGTERM);

  sub on_signal ($signal, $number, $count) {
      $signal->data->{server}->close;
      $signal->loop->stop;
  }

  package main;
  my $shutdown = $loop->add(LE::Shutdown->new(
      signals => [SIGINT, SIGTERM],  # required
      data    => { server => $server }, # optional
  ));

=head1 DESCRIPTION

Linux::Event::Signal is the public subclassing boundary for synchronous Linux
signal delivery. Concrete subclasses define one named C<on_signal> method.
Instances attach through C<< $loop->add($signal) >> or C<loop =E<gt> $loop>,
matching Stream, Listener, and Timer.

Each Loop lazily owns one private C<signalfd>. An object may subscribe to
several signal numbers, and several objects on that Loop may subscribe to the
same number. Every matching object receives the complete count observed in one
drain; counts are broadcast, never divided among subscribers.

=head1 DEFINING A SIGNAL TYPE

  sub on_signal ($signal, $number, $count) {
      $signal->data->{received}{$number} += $count;
      $signal->loop->stop;
  }

The resolved callback is cached once per subclass. C<$number> is the numeric
signal and C<$count> is the number of signalfd records aggregated for it in the
current drain. Standard non-real-time signals may coalesce in the kernel before
signalfd observes them. Real-time signals remain queued individually.

=head1 CONSTRUCTION

=head2 new(signals => $number | \@numbers, data => $value)

Creates a detached subscription for one or more positive numeric signals.
Duplicates are removed while preserving their first occurrence. C<SIGKILL>
and C<SIGSTOP> are rejected because Linux cannot block or deliver them through
signalfd.

C<loop> optionally attaches the object before C<new> returns. C<data> retains
an arbitrary application value while the object is active or unattached.

=head1 METHODS

=head2 cancel

Idempotently removes every subscription, releases retained data, and makes the
object terminal. Cancellation during C<on_signal> is safe. The native mask
retains a signal until the last object on that Loop cancels it.

=head2 signals

Returns a new array reference containing the subscribed numeric signals.

=head2 data([$value])

Gets or replaces application data while the object is nonterminal.

=head2 loop

Returns the owning Loop while active, otherwise undef.

=head2 state

Returns C<unattached>, C<active>, or C<cancelled>.

=head2 is_active / is_terminal

Report the current lifecycle category.

=head1 MASK OWNERSHIP AND THREADS

On first subscription, Linux::Event blocks that signal in the thread attaching
the object and records whether it was already blocked. On last cancellation it
restores only mask entries that Linux::Event changed; signals blocked by the
application remain blocked. A signal number may belong to only one Loop in a
process, because reading one signalfd consumes its notification.

Linux::Event changes the thread mask but does not replace the signal
disposition. Do not combine a Signal subscription with a Perl C<%SIG> handler
for the same number; signalfd consumes the blocked notification.

Signal masks are per-thread. Attach Signal objects before starting application
threads so those threads inherit the blocked mask, or explicitly block the
same signals in every application thread. Linux::Event's private resolver
workers block signals themselves and cannot consume application signals. This
feature uses native pthread APIs and does not require a Perl built with
ithreads.

Fork before attaching Signal objects. Signal services are intentionally not
reused across C<fork>.

=cut
