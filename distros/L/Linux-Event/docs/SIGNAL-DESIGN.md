# Signal design

`Linux::Event::Signal` turns process signals into ordinary synchronous Loop
callbacks. It does not install Perl `%SIG` handlers and no callback executes in
the kernel's asynchronous signal-handler context.

## Public shape

Signal follows the same subclass and attachment model as Timer:

```perl
package LE::Shutdown;
use parent 'Linux::Event::Signal';
use POSIX qw(SIGINT SIGTERM);

sub on_signal ($signal, $number, $count) {
    $signal->data->{listener}->close;
    $signal->loop->stop;
}

package main;
my $shutdown = $loop->add(LE::Shutdown->new(
    signals => [SIGINT, SIGTERM],
    data    => { listener => $listener },
));
```

One object may subscribe to several numeric signals. Several objects on the
same Loop may subscribe to the same signal. Fan-out preserves attachment order
and every object receives the full aggregate count.

## Native layout

The first Signal attached to a Loop lazily creates one private native service
and one nonblocking, close-on-exec signalfd. The service contains:

- one subscriber list per signal number;
- reference counts used to construct the shared signalfd mask;
- cached subclass callback descriptors;
- the original mask ownership state for exact restoration;
- delivery, record, callback, and active-subscription counters.

The signalfd is registered through Loop's lean raw `watch()` path. Readiness
enters XS once, drains complete `signalfd_siginfo` batches until `EAGAIN`, and
aggregates records by signal number before invoking Perl. Callbacks run in
numeric signal order; subscribers for one number run in attachment order.

Dispatch snapshots the subscribers for each delivered number. A callback may
therefore cancel itself or another subscriber safely. A cancelled later
subscriber is skipped, and callback-local data remains valid until the current
callback returns. The first callback exception is rethrown after safe native
cleanup.

## Mask ownership

signalfd only receives signals blocked in the consuming thread. On the first
subscription for a number, Linux::Event blocks it and records whether the
application had already blocked it. On last cancellation, Linux::Event
unblocks only signals it originally changed. Application-owned blocked entries
remain blocked.

A signal number may be owned by only one Loop in a process. Two signalfds
cannot independently broadcast the same process notification because reading
either descriptor consumes it. Multiple subscribers within the owning Loop
provide the supported fan-out boundary.

Linux::Event changes the thread mask, not the signal disposition. Do not use a
Perl `%SIG` handler for a signal concurrently owned by Signal: signalfd consumes
the blocked notification, so the traditional handler is not another fan-out
subscriber.

Signal masks are per-thread. Applications should attach Signal objects before
creating their own threads so the mask is inherited, or explicitly block the
same signals in every application thread. The private resolver workers always
block signals at worker startup, so they cannot intercept Signal traffic. Perl
ithreads are not required.

Fork before attaching Signal objects. The service records its process and
owning native thread and rejects reuse after a fork or from another thread.

## Counts

The callback count is the number of signalfd records observed for that signal
in one complete drain. Real-time signals are queued and retain individual
records. Ordinary signals may coalesce in the kernel before signalfd can
observe them, so their count describes observable records rather than the
number of attempted `kill()` calls.

## Lifecycle

Signal states are `unattached`, `active`, and `cancelled`. Cancellation is
terminal and idempotent. The Loop retains active objects through the native
service. Explicit cancellation or Loop destruction removes subscriptions,
restores owned mask entries, releases application data, and clears the weak
Loop reference.
