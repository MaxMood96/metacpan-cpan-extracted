# Kernel Signal design

`Linux::Event::Kernel::Signal` turns process signals into ordinary synchronous
Loop callbacks. It does not install Perl `%SIG` handlers and no application
callback executes in the kernel's asynchronous signal-handler context.

## Public shape

A concrete Signal type defines one named callback:

```perl
package ShutdownSignal;
use parent 'Linux::Event::Kernel::Signal';
use POSIX qw(SIGINT SIGTERM);

sub on_signal ($signal, $number, $count) {
    $signal->data->{listener}->close;
    $signal->loop->stop;
}

package main;
my $shutdown = $loop->add(ShutdownSignal->new(
    signals => [SIGINT, SIGTERM],
    data    => { listener => $listener },
));
```

One object can subscribe to several signal numbers. Several objects on the same
Loop can subscribe to the same number. Fan-out preserves attachment order and
each subscriber receives the aggregate observable count for that Loop drain.

## Native service

The first `Kernel::Signal` attached to a Loop lazily creates one private native
service and one nonblocking close-on-exec signalfd. The service owns:

- subscriber lists by signal number;
- reference counts used to build the shared signalfd mask;
- cached subclass callback descriptors;
- original mask ownership state for exact restoration;
- delivery and active-subscription counters.

The signalfd is registered through the Loop's private/raw readiness path.
Readiness enters the Signal XS service once, drains complete
`signalfd_siginfo` records until EAGAIN, aggregates by signal number, and only
then invokes semantic Perl callbacks.

Callbacks run in numeric signal order; subscribers for one signal run in
attachment order.

## Cancellation during dispatch

Dispatch snapshots subscribers for each delivered signal. A callback can
therefore cancel itself or another subscription safely.

A later subscriber cancelled before its turn is skipped. Callback-local object
and `data` state remain valid through the active callback. If a callback throws,
the first exception propagates after native dispatch state is restored safely.

## Signal-mask ownership

signalfd receives signals blocked in the consuming thread. On the first
subscription for a number, Linux::Event blocks it and records whether the
application had already blocked it.

When the last Linux::Event subscription for that number is removed, the service
unblocks only a mask entry it originally changed. Application-owned blocked
signals remain blocked.

A signal number can be owned by only one Linux::Event Loop service in a process.
Two independent signalfds cannot broadcast the same notification because
reading one consumes it. Multiple `Kernel::Signal` subscribers within the
owning Loop provide the supported fan-out model.

Linux::Event changes the thread signal mask, not the signal disposition. Do not
simultaneously treat Perl `%SIG` as another subscriber for a signal owned by
`Kernel::Signal`; the signalfd path consumes the blocked notification.

## Threads and fork

Signal masks are per-thread. Applications should establish Signal ownership
before creating application threads so the mask is inherited, or otherwise
ensure the same signals are blocked consistently in threads that could receive
them.

Linux::Event's native resolver workers block signals at worker startup and do
not become accidental recipients of Signal traffic. Perl ithreads are not
required for the Signal service.

Fork before attaching Signal objects. The private service records its process
and owning native thread and rejects unsafe reuse after fork or from another
thread.

## Counts

`on_signal($signal, $number, $count)` receives the number of signalfd records
observed for that signal during one completed native drain.

Real-time signals are queued and preserve individual records. Ordinary signals
can coalesce in the kernel before signalfd observes them, so the callback count
represents observed records rather than attempted `kill()` calls.

## Lifecycle

Public lifecycle states are the unattached, active, and cancelled forms defined
by the current implementation.

Cancellation is terminal and idempotent. The Loop retains active subscriptions
through the native service. Explicit cancellation or Loop teardown removes the
subscription, restores only Linux::Event-owned mask changes, releases retained
application data, and clears ownership references.

## Performance model

One signalfd serves all Signal subscriptions on a Loop. One readiness entry
can drain and aggregate several native records before entering Perl. Named
`on_signal` callbacks are cached by concrete subclass rather than looked up for
every record.

This keeps Signal semantics out of asynchronous kernel handler context without
turning every subscription into a separate fd or Perl watcher object.

## Native implementation boundary

`Linux::Event::Kernel::Signal` is the supported public class and native host for
signalfd fan-out. Its private service and descriptor packages stay behind that
class and do not add a Perl dispatch layer before the cached public callback.
