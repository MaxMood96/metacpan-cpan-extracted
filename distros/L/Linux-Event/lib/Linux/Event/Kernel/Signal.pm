package Linux::Event::Kernel::Signal;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.111';

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
    croak 'Linux::Event::Kernel::Signal is an abstract base class'
        if $class eq __PACKAGE__;
    croak "$class is not a Linux::Event::Kernel::Signal subclass"
        if !$class->isa(__PACKAGE__);
    my $callback = $class->can('on_signal')
        // croak "$class must define on_signal()";
    return $CLASS_DESCRIPTOR{$class}
        = Linux::Event::Kernel::Signal::_Descriptor->new($callback);
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
        //= Linux::Event::Kernel::Signal::_Engine->_new($loop);
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

package Linux::Event::Kernel::Signal::_Descriptor;
sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Kernel::Signal::_Service;
sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Kernel::Signal::_Engine;
use v5.36;
use strict;
use warnings;

sub CLONE_SKIP ($class) { 1 }

sub _new ($class, $loop) {
    my $self = bless {
        loop   => $loop,
        native => Linux::Event::Kernel::Signal::_Service->new,
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

Linux::Event::Kernel::Signal - synchronous signalfd delivery on a Loop

=head1 SYNOPSIS

  package Shutdown;
  use parent 'Linux::Event::Kernel::Signal';
  use POSIX qw(SIGINT SIGTERM);

  sub on_signal ($signal, $number, $count) {
      $signal->data->{listener}->close;
      $signal->loop->stop;
  }

  package main;
  my $signal = $loop->add(Shutdown->new(
      signals => [SIGINT, SIGTERM],
      data    => { listener => $listener },
  ));

=head1 DESCRIPTION

C<Linux::Event::Kernel::Signal> converts Linux process signals into ordinary
synchronous Loop callbacks. It does not execute application Perl from an
asynchronous C signal handler and does not install a Perl C<%SIG> callback for
the subscribed numbers.

One object may subscribe to several signal numbers, and several Signal objects
on the same Loop may subscribe to the same number. The Loop uses one shared
nonblocking signalfd plus a native fan-out registry.

=head1 CONSTRUCTION

C<signals> is required and contains the numeric signals to subscribe to.
C<data> stores arbitrary application state. C<loop =E<gt> $loop> attaches
immediately; otherwise add the detached object with C<< $loop->add($signal) >>.

=head1 CALLBACK

A concrete subclass defines:

  sub on_signal ($signal, $number, $count) { ... }

C<$count> is the number of signalfd records observed for that signal in the
current complete drain. Real-time signals retain queued records; ordinary
signals may already have coalesced in the kernel before signalfd observes them.

Subscribers for one signal are called in attachment order. Dispatch is safe
when a callback cancels itself or another subscriber.

=head1 SIGNAL MASK OWNERSHIP

signalfd receives signals that are blocked in the consuming thread.
Linux::Event records whether each subscribed signal was already blocked and
restores only mask entries that Linux::Event itself changed when the last
subscription is removed.

A signal number may be owned by only one Linux::Event Loop in a process. Do not
also expect a Perl C<%SIG> handler to receive a signal while that signal is
blocked for signalfd consumption.

Signal masks are per-thread. Applications should establish Signal subscriptions
before creating their own worker threads, or explicitly arrange equivalent
blocking in those threads. Fork before attaching Signal objects; the native
service is tied to its process and owning thread.

=head1 LIFECYCLE

C<cancel> is idempotent and terminal. The Loop retains active subscriptions.
Cancellation and Loop destruction remove native fan-out entries, restore owned
mask state, and release application data safely, including cancellation during
a callback.

=head1 SEE ALSO

L<Linux::Event::Loop>, F<docs/SIGNAL-DESIGN.md>.

=cut
