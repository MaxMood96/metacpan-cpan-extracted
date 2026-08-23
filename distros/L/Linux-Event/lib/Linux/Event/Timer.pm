package Linux::Event::Timer;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.102';

use Carp qw(croak);
use POSIX qw(isfinite);
use Scalar::Util qw(looks_like_number);

require Linux::Event::Loop;

my %CLASS_DESCRIPTOR;

sub _descriptor_for ($class) {
    return $CLASS_DESCRIPTOR{$class} if exists $CLASS_DESCRIPTOR{$class};
    croak 'Linux::Event::Timer is an abstract base class'
        if $class eq __PACKAGE__;
    croak "$class is not a Linux::Event::Timer subclass"
        if !$class->isa(__PACKAGE__);
    my $callback = $class->can('on_timer')
        // croak "$class must define on_timer()";
    return $CLASS_DESCRIPTOR{$class}
        = Linux::Event::Timer::_Descriptor->new($callback);
}

sub _seconds ($method, $name, $value, $positive) {
    my $seconds = !defined($value) || ref($value)
        || !looks_like_number($value) ? undef : 0 + $value;
    croak "$method(): $name must be a "
        . ($positive ? 'positive' : 'non-negative')
        . ' number of seconds'
        if !defined($seconds) || !isfinite($seconds)
        || $seconds < 0 || ($positive && $seconds == 0);
    return $seconds;
}

sub _schedule ($method, $option) {
    my @unknown = sort grep {
        $_ ne 'after' && $_ ne 'at' && $_ ne 'every'
    } keys %$option;
    croak "$method(): unknown options: " . join(', ', @unknown) if @unknown;

    my $has_after = exists $option->{after};
    my $has_at = exists $option->{at};
    my $has_every = exists $option->{every};
    croak "$method(): after and at are mutually exclusive"
        if $has_after && $has_at;
    croak "$method(): one of after, at, or every is required"
        if !$has_after && !$has_at && !$has_every;

    my $every = $has_every
        ? _seconds($method, 'every', $option->{every}, 1) : 0;
    my ($absolute, $first);
    if ($has_at) {
        $absolute = 1;
        $first = _seconds($method, 'at', $option->{at}, 0);
    }
    elsif ($has_after) {
        $absolute = 0;
        $first = _seconds($method, 'after', $option->{after}, 0);
    }
    else {
        $absolute = 0;
        $first = $every;
    }
    return ($absolute, $first, $every);
}

sub new ($class, %option) {
    croak 'new(): must be called as a class method' if ref $class;
    my $loop = delete $option{loop};
    croak 'new(): loop must be an object implementing add()'
        if defined($loop) && (!ref($loop) || !$loop->can('add'));
    my $data = delete $option{data};
    my ($absolute, $first, $every) = _schedule('new', \%option);
    my $timer = $class->_new_native(
        _descriptor_for($class), $absolute, $first, $every, $data,
    );
    $loop->add($timer) if defined $loop;
    return $timer;
}

sub reschedule ($self, %option) {
    my ($absolute, $first, $every) = _schedule('reschedule', \%option);
    return $self->_reschedule_native($absolute, $first, $every);
}

sub CLONE ($class) {
    %CLASS_DESCRIPTOR = ();
    return;
}

sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Timer::_Descriptor;
sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Timer;

1;

__END__

=head1 NAME

Linux::Event::Timer - subclass-defined timers for Linux::Event

=head1 SYNOPSIS

  package LE::Heartbeat;
  use parent 'Linux::Event::Timer';

  sub on_timer ($timer) {
      $timer->data->send_heartbeat;
  }

  package main;
  use Linux::Event::Loop;

  my $loop = Linux::Event::Loop->new;
  my $timer = $loop->add(LE::Heartbeat->new(
      every => 30,          # required recurring interval
      data  => $connection, # optional
  ));
  $loop->run;

=head1 DESCRIPTION

Linux::Event::Timer is the public subclassing boundary for Loop-owned timers.
Each concrete subclass defines one named C<on_timer> method. One immutable
native descriptor caches that callback for the subclass, while every Timer
instance owns only its schedule, application data, lifecycle, and native heap
position.

Timer objects use the same attachment contract as Stream and Listener. Supply
C<loop =E<gt> $loop> during construction or construct the Timer detached and
pass it to C<< $loop->add($timer) >>. There are no Timer-construction methods on
Loop and no callback-configured compatibility form.

All public times are seconds and may be fractional. Deadlines use
C<CLOCK_MONOTONIC>; wall-clock changes do not affect them.

=head1 DEFINING A TIMER TYPE

The base class cannot be constructed directly. A subclass must define:

  sub on_timer ($timer) {
      my $context = $timer->data;
      $context->{stream}->close;
  }

The resolved CV is cached once per subclass and called directly without Perl
method lookup at expiration. Inheritance works normally. Per-instance
application state belongs in C<data>.

=head1 CONSTRUCTION

=head2 new(after => $seconds, data => $value)

Creates a one-shot relative Timer. The delay begins when the Timer is attached,
not when a detached object is constructed. Zero schedules the callback for a
subsequent Loop turn and never calls it inline.

=head2 new(at => $deadline, data => $value)

Creates a one-shot Timer for an absolute monotonic deadline expressed in
seconds. Use C<< Linux::Event::Timer->now >> to obtain the current clock. A
deadline already in the past fires on a subsequent Loop turn.

=head2 new(every => $seconds, data => $value)

Creates a fixed-rate recurring Timer whose first expiration occurs after one
interval. The interval must be positive.

C<after> or C<at> may be combined with C<every> to choose a different first
expiration. C<after> and C<at> are mutually exclusive.

C<loop> optionally attaches the Timer before C<new> returns. C<data> retains an
arbitrary application value until cancellation or final expiration.

=head1 METHODS

=head2 reschedule(after => $seconds) / reschedule(at => $deadline) / reschedule(every => $seconds)

Replaces an active Timer's schedule and returns the same object. The same
schedule combinations and validation as C<new> apply. Rescheduling never calls
C<on_timer> inline. It is allowed from inside C<on_timer>; an explicit schedule
then replaces the normal recurring schedule or keeps a one-shot Timer active.

Cancelled and finally expired Timers cannot be rescheduled or reattached.

=head2 cancel

Idempotently removes the Timer from its Loop, releases retained application
data, and makes it terminal. Cancellation during C<on_timer> defers reference
cleanup until that callback returns safely. Returns the Timer.

=head2 data([$value])

Gets or replaces the application value while the Timer is nonterminal. A
one-shot Timer releases this value after its final callback; a recurring Timer
retains it until cancellation or Loop destruction.

=head2 loop

Returns the owning Loop while attached, otherwise undef.

=head2 deadline

Returns the next absolute monotonic deadline in seconds. A detached relative
Timer has no absolute deadline and returns undef.

=head2 interval

Returns the recurring interval in seconds, or zero for a one-shot Timer.

=head2 expirations

Returns the number of periodic ticks represented by the latest callback. When
the Loop is delayed, missed intervals are coalesced into one callback rather
than delivered as a catch-up storm.

=head2 state

Returns C<unattached>, C<active>, C<expired>, or C<cancelled>.

=head2 is_active / is_terminal

Report the current lifecycle category.

=head2 now

Class method returning the current C<CLOCK_MONOTONIC> time in seconds.

=head1 SCHEDULER SEMANTICS

Every Loop lazily creates one nonblocking, close-on-exec timerfd and stores all
active Timers in one indexed native minimum heap. Equal deadlines fire in
schedule order. Recurring timers retain fixed-rate phase, skip missed periods,
and expose the represented count through C<expirations>.

Timer callbacks are delivered in bounded batches so a large deadline cohort
cannot permanently starve descriptor readiness. Timers created or rescheduled
for immediate delivery from inside a Timer callback wait for a later Loop turn.

Callback exceptions propagate from the Loop. A recurring Timer remains
scheduled when its callback throws. A one-shot Timer still completes terminal
cleanup.

=cut
