# Kernel Event design

`Linux::Event::Kernel::Event` is the public eventfd abstraction for notifying a
Loop that application work has become available. It solves one narrow problem:
an epoll Loop may be asleep when another thread, process, or native component
needs the owning interpreter to notice new work.

## Public shape

An application defines one named callback:

```perl
package ResultReady;
use parent 'Linux::Event::Kernel::Event';

sub on_event ($event, $count) {
    my $queue = $event->data;
    while (defined(my $result = $queue->dequeue_nb)) {
        say "completed: $result";
    }
    $event->loop->stop;
}
```

Construction and attachment follow the ordinary resource lifecycle:

```perl
my $event = $loop->add(ResultReady->new(
    data => $results,
));
```

The `on_event` CV is resolved from the subclass. `signal($increment)` performs
an eventfd counter write and returns the Event. It never runs `on_event`
inline. `cancel()` is terminal and idempotent according to the current eventfd
implementation contract.

## Notification is not payload transport

An eventfd carries a 64-bit counter, not a Perl scalar, object, or coderef. A
producer publishes its actual result through an appropriate channel before
signaling the Event, for example:

- `Thread::Queue` or another ithread-safe queue;
- shared native memory with explicit synchronization;
- a pipe or socket containing serialized records;
- an application-owned cross-process queue.

The callback receives the counter total drained in that Loop turn. Several
signals may coalesce into one callback. The application queue or IPC channel,
not the eventfd count, remains the source of truth for individual results.

## Why this is not a generic Loop post queue

A general `$loop->post($coderef)` implies that arbitrary Perl callbacks and
values can safely cross native threads or process boundaries. That is not a
valid generic ownership model.

Perl values belong to an interpreter, and a distribution-level work queue would
need explicit rules for serialization, ownership, cancellation, shutdown,
exception delivery, fork, and thread cloning.

`Kernel::Event` instead exposes the safe kernel primitive. Internal subsystems
with a fixed native result schema, such as the resolver, can use their own
private typed completion queue plus eventfd. Applications pair `Kernel::Event`
with the payload mechanism appropriate to their own producer.

## Why not use raw watch directly

An application can create and watch an eventfd manually with
`$loop->watch(fd => ...)`, but it would also need to own:

- correct eventfd creation flags;
- counter draining;
- interpreter ownership rules;
- thread-clone descriptor handling;
- fork behavior;
- cancellation and close ordering;
- stale descriptor reuse protection.

`Kernel::Event` packages those rules into one semantic Loop resource while the
raw reactor remains available for uncommon descriptor protocols.

## Thread model

Linux::Event does not require a Perl built with ithreads. `Kernel::Event` is
still useful for native extensions, C libraries, and forked children.

When Perl ithreads are available, a cloned Event handle may signal according to
the supported implementation boundary. The owning Loop, callback, watcher, and
application `data` remain in the creating interpreter. A worker clone does not
become another owner of Loop state.

Descriptor duplication and interpreter tagging prevent destruction of a stale
worker-side descriptor number from accidentally closing an unrelated resource
that later reused the same fd number in the owner interpreter.

## Fork behavior

A child forked after Event construction inherits the eventfd and may signal it
until exec. The descriptor is close-on-exec.

The child does not gain ownership of the parent's Loop, callback state, or
application data. Cross-process payloads still require an IPC mechanism.
Applications must also respect the fork-before-service rules of other Linux::Event
subsystems whose native worker/service state cannot simply be reused in a
forked child.

## Native path and fairness

The Event owns one nonblocking close-on-exec eventfd and one Loop registration.
A readiness dispatch performs one eventfd read. Signals arriving after that
read keep the descriptor readable for a later Loop turn rather than forcing an
unbounded drain while producers remain continuously active.

Counter saturation causes a nonblocking eventfd write to fail instead of
silently discarding the already accumulated readiness. `signal()` reports that
kernel failure synchronously.

Application callback exceptions propagate from Loop dispatch; they are not
silently converted into cancellation.

## Native implementation boundary

`Linux::Event::Kernel::Event` is both the supported public class and the native
eventfd host. It exposes `on_event` as the application callback without an
intermediate historical-package bridge.
