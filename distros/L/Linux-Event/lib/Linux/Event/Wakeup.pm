package Linux::Event::Wakeup;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.105';

use Carp qw(croak);
use Config ();
use Scalar::Util qw(refaddr weaken);

require Linux::Event::Loop;
require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

my %CLASS_DESCRIPTOR;
my %OWNER_STATE;
my %LIVE_HANDLE;
my $NEXT_ID = 1;
my $MAX_INCREMENT = $Config::Config{uvsize} >= 8
    ? '18446744073709551614' : '4294967295';

sub _decimal_greater_than ($value, $maximum) {
    $value =~ s/\A0+//;
    $value = '0' if $value eq '';
    return 1 if length($value) > length($maximum);
    return 0 if length($value) < length($maximum);
    return $value gt $maximum;
}

sub _descriptor_for ($class) {
    return $CLASS_DESCRIPTOR{$class} if exists $CLASS_DESCRIPTOR{$class};
    croak 'Linux::Event::Wakeup is an abstract base class'
        if $class eq __PACKAGE__;
    croak "$class is not a Linux::Event::Wakeup subclass"
        if !$class->isa(__PACKAGE__);
    my $callback = $class->can('on_wakeup')
        // croak "$class must define on_wakeup()";
    return $CLASS_DESCRIPTOR{$class} = { callback => $callback };
}

sub new ($class, %option) {
    croak 'new(): must be called as a class method' if ref $class;
    my $loop = delete $option{loop};
    croak 'new(): loop must be an object implementing add() and watch()'
        if defined($loop) && (!ref($loop) || !$loop->can('add')
            || !$loop->can('watch'));
    my $data = delete $option{data};
    croak 'new(): unknown options: ' . join(', ', sort keys %option)
        if %option;
    my $id = $NEXT_ID++;
    my $self = bless {
        id              => $id,
        fd              => _new_fd(),
        terminal        => 0,
        owner_pid       => $$,
        owner_interpreter => _interpreter_id(),
        handle_interpreter => _interpreter_id(),
        cloned_signal_handle => 0,
    }, $class;
    $LIVE_HANDLE{$id} = $self;
    weaken($LIVE_HANDLE{$id});
    $OWNER_STATE{$id} = bless {
        descriptor => _descriptor_for($class),
        loop       => undef,
        watcher    => undef,
        data       => $data,
        state      => 'unattached',
    }, 'Linux::Event::Wakeup::_OwnerState';
    $loop->add($self) if defined $loop;
    return $self;
}

sub _assert_owner ($self, $method) {
    croak "$method(): Wakeup may be managed only by its creating interpreter"
        if $self->{cloned_signal_handle}
        || $self->{owner_pid} != $$
        || $self->{owner_interpreter} != _interpreter_id();
    return;
}

sub _owner_state ($self, $method) {
    $self->_assert_owner($method);
    return $OWNER_STATE{ $self->{id} }
        // croak "$method(): Wakeup owner state is unavailable";
}

sub _attach_to_loop ($self, $loop) {
    croak 'add(): Wakeup is not unattached' if $self->{terminal};
    my $state = $self->_owner_state('add');
    croak 'add(): Wakeup is not unattached'
        if $state->{state} ne 'unattached' || $state->{loop};
    my $watcher = $loop->watch(
        fd      => $self->{fd},
        _internal => 1,
        read    => sub { $self->_dispatch },
        error   => sub { die "Linux::Event Wakeup event source failed\n" },
        no_args => 1,
        lean    => 1,
    );
    $state->{loop} = $loop;
    $state->{state} = 'active';
    $state->{watcher} = $watcher;
    return $self;
}

sub _dispatch ($self) {
    my $state = $self->_owner_state('dispatch');
    return if $state->{state} ne 'active';
    my $count = _drain_fd($self->{fd});
    return if !$count;
    $state->{descriptor}{callback}->($self, $count);
    return;
}

sub signal ($self, $increment = 1) {
    croak 'signal(): Wakeup is cancelled' if $self->{terminal};
    croak 'signal(): cloned Wakeup handle belongs to another interpreter'
        if $self->{handle_interpreter} != _interpreter_id();
    croak 'signal(): increment must be a positive integer'
        if !defined($increment) || ref($increment)
        || $increment !~ /\A\d+\z/ || $increment == 0;
    croak 'signal(): increment exceeds the supported eventfd range'
        if _decimal_greater_than("$increment", $MAX_INCREMENT);
    _signal_fd($self->{fd}, 0 + $increment);
    return $self;
}

sub cancel ($self) {
    return $self if $self->{terminal};
    my $state = $self->_owner_state('cancel');
    $state->{watcher}->cancel if $state->{watcher};
    $state->{watcher} = undef;
    _close_fd(delete $self->{fd}) if defined $self->{fd};
    delete $LIVE_HANDLE{ $self->{id} };
    $state->{loop} = undef;
    $state->{data} = undef;
    $state->{state} = 'cancelled';
    delete $OWNER_STATE{ $self->{id} };
    $self->{terminal} = 1;
    return $self;
}

sub loop ($self) {
    return undef if $self->{terminal};
    return $self->_owner_state('loop')->{loop};
}
sub state ($self) {
    return 'cancelled' if $self->{terminal};
    return $self->_owner_state('state')->{state};
}
sub is_active ($self) { $self->state eq 'active' }
sub is_terminal ($self) { !!$self->{terminal} }

sub data ($self, @argument) {
    croak 'data(): Wakeup is cancelled' if $self->{terminal};
    my $state = $self->_owner_state('data');
    $state->{data} = $argument[0] if @argument;
    return $state->{data};
}

sub _objects_for_loop ($class, $loop) {
    my @object;
    for my $id (keys %LIVE_HANDLE) {
        my $object = $LIVE_HANDLE{$id} // next;
        next if $object->{terminal};
        my $state = $OWNER_STATE{$id} // next;
        next if !$state->{loop}
            || refaddr($state->{loop}) != refaddr($loop);
        push @object, $object;
    }
    return \@object;
}

sub CLONE ($class) {
    for my $id (keys %LIVE_HANDLE) {
        my $self = $LIVE_HANDLE{$id};
        if (!$self) {
            delete $LIVE_HANDLE{$id};
            next;
        }
        next if $self->{terminal} || !defined $self->{fd};
        $self->{fd} = _dup_fd($self->{fd});
        $self->{handle_interpreter} = _interpreter_id();
        $self->{cloned_signal_handle} = 1;
    }
    return;
}

sub DESTROY ($self) {
    my $interpreter = eval { _interpreter_id() };
    my $is_owner = !$self->{cloned_signal_handle}
        && defined($interpreter)
        && $self->{owner_pid} == $$
        && $self->{owner_interpreter} == $interpreter;
    if ($is_owner) {
        my $state = delete $OWNER_STATE{ $self->{id} };
        eval { $state->{watcher}->cancel if $state && $state->{watcher}; 1 };
    }
    my $live = $LIVE_HANDLE{ $self->{id} };
    delete $LIVE_HANDLE{ $self->{id} }
        if !$live || refaddr($live) == refaddr($self);
    return if !defined($interpreter)
        || $self->{handle_interpreter} != $interpreter;
    eval { _close_fd(delete $self->{fd}); 1 } if defined $self->{fd};
    return;
}

package Linux::Event::Wakeup::_OwnerState;
use v5.36;
use strict;
use warnings;

sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Wakeup;

1;

__END__

=head1 NAME

Linux::Event::Wakeup - subclass-defined eventfd wakeups

=head1 SYNOPSIS

  use threads;
  use Thread::Queue;

  package LE::ResultsReady;
  use parent 'Linux::Event::Wakeup';

  sub on_wakeup ($wakeup, $count) {
      my $queue = $wakeup->data;
      while (defined(my $result = $queue->dequeue_nb)) {
          say "worker produced $result";
      }
      $wakeup->loop->stop;
  }

  package main;
  my $results = Thread::Queue->new;
  my $wakeup = $loop->add(LE::ResultsReady->new(
      data => $results, # optional
  ));

  my $worker = threads->create(sub {
      $results->enqueue('complete');
      $wakeup->signal;
      return 1;
  });
  $worker->join;
  $loop->run;

=head1 DESCRIPTION

Wakeup is the public eventfd notification boundary for Linux::Event. A
concrete subclass defines one named C<on_wakeup> method. Calling C<signal>
increments the eventfd counter, wakes the owning Loop, and causes the Loop
thread to invoke that method with the coalesced count.

Wakeup carries notification, not arbitrary Perl values. A producer that has
results to deliver must store them in an appropriate thread-safe queue, shared
memory region, pipe, socket, or other IPC mechanism before signalling. This
keeps Perl coderefs and interpreter-owned values out of foreign threads.

Wakeup is not a general C<< $loop->post($coderef) >> queue. Native resolver
workers already use a private typed completion queue and eventfd. Wakeup is the
public primitive for an application that has its own safe data channel and
needs only to make the Loop notice it. Using raw C<< $loop->watch >> directly
would expose eventfd creation, counter draining, ownership, and clone rules at
every call site; Wakeup centralizes those rules in one logical object.

=head1 DEFINING A WAKEUP TYPE

  sub on_wakeup ($wakeup, $count) {
      $wakeup->data->{total} += $count;
  }

The callback CV is resolved once per subclass. C<$count> is the eventfd total
observed in one drain. Several signals may therefore produce one callback.

=head1 CONSTRUCTION

  my $wakeup = LE::ResultsReady->new(
      loop => $loop, # optional: attach immediately
      data => $data, # optional
  );

The base class is abstract. Supply C<loop> or construct the Wakeup detached and
attach it with C<< $loop->add($wakeup) >>. A Wakeup attaches once and cannot be
reused after cancellation.

=head1 METHODS

=head2 signal($increment = 1)

Atomically adds a positive integer to the eventfd counter and returns the
Wakeup. The implementation performs only an XS eventfd write after validating
the scalar argument. The maximum is the smaller of the eventfd counter range
and Perl's native unsigned-integer range. It never invokes C<on_wakeup> inline.

A cloned handle on a threaded Perl build may call C<signal>. Each interpreter
clone owns a close-on-exec duplicate of the eventfd descriptor, so cancellation
in the Loop interpreter cannot turn a stale descriptor number into an unrelated
write. That duplicate is valid only in the interpreter that received it; an
object accidentally returned through C<join> cannot manage the owner or reuse
the worker's closed descriptor. A child created
after Wakeup construction may call C<signal> before it executes another
program. Neither case permits the foreign interpreter or child to attach,
cancel, or change application data.

=head2 cancel

Idempotently removes the Loop registration, closes the eventfd, releases data,
and makes the Wakeup terminal. Only the creating interpreter may cancel it.

=head2 data([$value])

Gets or replaces the application value in the creating interpreter.

=head2 loop

Returns the owning Loop while active, otherwise undef.

=head2 state

Returns C<unattached>, C<active>, or C<cancelled>.

=head2 is_active / is_terminal

Report the current lifecycle category.

=head1 THREAD AND PROCESS BOUNDARY

Linux::Event itself does not require a threaded Perl. Native library workers
may signal eventfds without entering Perl. On a Perl built with ithreads, a
worker interpreter receives cloned Perl values; it does not share callbacks or
ordinary data with the Loop interpreter. Wakeup deliberately transfers only
the counter increment.

After C<fork>, the child inherits the eventfd and may wake the parent until it
executes another program. The eventfd is close-on-exec. It does not transport a
payload; cross-process data still requires IPC.

=head1 CALLBACK EXCEPTIONS

An exception from C<on_wakeup> propagates out of Loop dispatch. It does not
implicitly cancel the Wakeup.

=cut
