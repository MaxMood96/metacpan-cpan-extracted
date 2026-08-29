package Linux::Event::Loop;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.105';

use Carp qw(croak);
use Scalar::Util qw(blessed);

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

require Linux::Event::Loop::Introspection;
our @ISA = ('Linux::Event::Loop::Introspection');

sub add ($self, $object) {
    croak 'add(): object must support loop attachment'
        if !blessed($object) || !$object->can('_attach_to_loop');
    $object->_attach_to_loop($self);
    return $object;
}

sub CLONE_SKIP ($class) { 1 }

package Linux::Event::_Registration;
sub CLONE_SKIP ($class) { 1 }

package Linux::Event::Loop;

1;

__END__

=head1 NAME

Linux::Event::Loop - Linux-native epoll event loop

=head1 SYNOPSIS

  use Linux::Event::Loop;

  my $loop = Linux::Event::Loop->new;
  my $stream = $loop->add(MyStream->connect(
      host => '127.0.0.1', # required
      port => 9999,        # required
  ));
  $loop->run;

=head1 DESCRIPTION

Linux::Event::Loop owns the native epoll instance, descriptor registry, event
buffer, and readiness dispatch. It is the only public loop class.

High-level objects may be attached in either of two equivalent ways:

  my $stream = MyStream->connect(
      loop => $loop,        # optional: attach immediately
      host => '127.0.0.1',  # required
      port => 9999,         # required
  );

  my $stream = MyStream->connect(
      host => '127.0.0.1', # required
      port => 9999,        # required
  );
  $loop->add($stream);

C<add> invokes the concrete object's attachment implementation and
returns the same object. Stream, Listener, Datagram, Timer, Signal, Wakeup, and
Process reject attachment to a second Loop or attachment after reaching a
terminal state.

C<watch> is the low-level descriptor API. It registers immediately and returns
an opaque native registration handle. The handle is not a public class or a
subclassing API.

=head1 HIGH-LEVEL OBJECTS

=head2 add($object)

Attaches a detached L<Linux::Event::Stream>, L<Linux::Event::Listener>,
L<Linux::Event::Datagram>, L<Linux::Event::Timer>,
L<Linux::Event::Signal>, L<Linux::Event::Wakeup>, or
L<Linux::Event::Process> and returns that exact object. The object becomes
owned by this Loop. Attaching it again, attaching it to another Loop, or
attaching a terminal object throws an exception.

The following are equivalent:

  my $a = MyStream->connect(
      loop => $loop,       # optional: attach immediately
      host => '127.0.0.1', # required
      port => 9999,        # required
  );
  my $b = $loop->add(MyStream->connect(
      host => '127.0.0.1', # required
      port => 9999,        # required
  ));

  my $timer = $loop->add(MyTimer->new(
      after => 0.25, # required one-shot delay
  ));

  my $socket = $loop->add(MyDatagram->new(
      host => '0.0.0.0', # required
      port => 9999,      # required
  ));

The C<loop> constructor option and C<add> are both primary public APIs.
Timer construction and scheduling deliberately use this generic attachment
path; Loop has no Timer-specific factory methods.

=head1 RAW DESCRIPTOR API

=head2 watch(fh => $fh, read => $callback) / watch(fd => $fd, read => $callback)

Registers exactly one filehandle or integer descriptor. Supported options are:

=over 4

=item * C<read>, C<write>, C<error>

Coderefs for readable, writable, and terminal/error readiness. Only C<read>
and C<write> control ordinary interest; terminal flags are always observed.
For one returned event, callback order is error, read, then write. Cancellation
after any callback suppresses the remaining callbacks for that event.

=item * C<data>

An arbitrary retained value available through C<< $registration->data >>.

=item * C<no_args =E<gt> 1>

Calls readiness coderefs without an argument. By default each receives the
opaque registration handle.

=item * C<lean =E<gt> 1>

With C<no_args>, avoids retaining references used only by handle accessors.
This is an expert registration-throughput optimization.

=item * C<edge_triggered =E<gt> 1>

Uses C<EPOLLET>. The callback must drain the descriptor until C<EAGAIN>.

=item * C<oneshot =E<gt> 1>

Uses C<EPOLLONESHOT>. The application is responsible for its rearm policy.

=back

Registering an fd that is already registered replaces its native registration
with C<EPOLL_CTL_MOD>. Cancelling the obsolete handle cannot remove the new
registration.

=head2 watch_fd($fd, read => $callback)

Low-level positional form used by Linux::Event internals and specialized code.
It creates the same native registration and has the same dispatch path as
C<watch>. Normal application code should prefer C<watch>.

=head2 unwatch_fd($fd)

Cancels the current registration for C<$fd>, if any. Prefer the registration's
C<cancel> method when the handle is available.

=head1 REGISTRATION METHODS

The opaque result of C<watch> supports C<fd>, C<fh>, C<data>, C<loop>, C<lean>,
C<cancel>, C<enable_read>, C<disable_read>, C<enable_write>, and
C<disable_write>. C<cancel> is idempotent and makes an obsolete handle inert,
including after native watcher storage is reused. Cancellation releases the
registration's retained Perl state. An fd-only registration returns undef from
C<fh>.

=head1 DRIVING THE LOOP

=head2 run

Waits and dispatches until C<stop> is called.

=head2 run_once($timeout_ms = -1)

Runs one C<epoll_wait>. A negative timeout blocks indefinitely, zero polls, and
a positive value is a maximum wait in milliseconds. Returns the number of
events returned by epoll. A prior C<stop> request does not suppress a later
C<run_once> call.

=head2 run_for($seconds)

Runs against a monotonic deadline for the supplied non-negative number of
seconds.

Only one driver method may be active for a given Loop. Calling C<run>,
C<run_once>, or C<run_for> recursively on that same Loop throws an exception;
a callback may drive a different Loop. C<set_event_capacity> is likewise
rejected while its Loop is running or dispatching.

=head2 stop

Requests that the active C<run> or C<run_for> return after the current dispatch
work completes.

=head1 INTROSPECTION

=head2 running

Returns true while this Loop is inside C<run>, C<run_once>, or C<run_for>,
including from a callback. This is an O(1) query of native driver state.

=head2 count

Returns the number of current managed public objects. Managed objects are
Stream, Listener, Datagram, Timer, Signal, Wakeup, and Process instances.
Opaque raw registrations and private helper objects are excluded. This query
enumerates existing object and fd registries.

=head2 has($object)

Returns true only when the exact object is current in this Loop. An object
owned by another Loop, or one which is detached or terminal, returns false.
Identity is exact; the query enumerates the current object snapshot.

=head2 objects

Returns a new array reference containing the actual current managed objects.
Order is unspecified. The query enumerates authoritative native and service
registries without maintaining a duplicate public-object registry.

=head2 inspect($object)

Returns a new type-specific snapshot. Every result contains C<type>, C<class>,
and C<registered>. A supported object which is not current in this Loop returns
only those common fields with C<registered =E<gt> 0>. Current objects also
include C<state> and fields appropriate to Stream, Listener, Datagram, Timer,
Signal, Wakeup, or Process. See F<docs/INTROSPECTION.md> for the complete field
table.

=head2 census

Returns a new hash reference containing counts for C<stream>, C<listener>,
C<datagram>, C<timer>, C<signal>, C<wakeup>, and C<process>. Every key is
present even when its count is zero.

=head2 resources

Returns a native resource snapshot: epoll and timer fds, total/public/internal
registration counts, public registration fds, active Timers, and current
registry, Timer heap, and event-buffer capacities. C<timer_fd> is undef until
the first Timer creates the Loop's shared timer source. This scans the native
fd registry and does not create resources.

=head2 why_alive

Returns an array reference of actionable user-visible liveness reasons.
Managed-object entries contain the same snapshot as C<inspect> plus the exact
C<object>. Direct raw C<watch> registrations appear as C<registration> entries
with their fd. Private backing registrations are not repeated as reasons.

=head2 pressure

Returns conservative C<registrations>, C<timers>, and C<event_batch> capacity
and utilization snapshots. Event-batch maximum and utilization are undef until
an epoll wait has completed. This is implementation pressure, not a synthesized
health or latency score.

=head1 DIAGNOSTICS AND TUNING

C<stats> returns counters for epoll waits, event classes, callbacks,
registrations, Timer scheduling and delivery, dispatch batching, and lifecycle
activity. C<reset_stats>
resets them without changing profiling state. C<profile($boolean)> returns the
Loop and changes future nanosecond timing collection without resetting existing
statistics. Statistics remain readable while profiling is disabled. The first
API does not place a clock read around each callback. Profiling changes the
measured workload, so it should be disabled for normal benchmarks.

C<event_capacity> and C<set_event_capacity> inspect or change the reusable
event array. C<callback_scope_limit> and C<set_callback_scope_limit> control
bounded Perl temporary scopes. C<enable_watcher_reclaim> exposes an
experimental native memory/throughput tradeoff. The measured defaults should
normally remain unchanged.

=head1 INTERPRETER OWNERSHIP

A Loop and every native object it owns belong to the Perl interpreter that
created them. They are not cloned into a new ithread. Only a cloned
L<Linux::Event::Wakeup> handle may signal its owner through eventfd; it cannot
manage the Loop, invoke callbacks, or access owner-interpreter data.

=head1 PLATFORM

Linux only. The implementation uses epoll directly.

=cut
