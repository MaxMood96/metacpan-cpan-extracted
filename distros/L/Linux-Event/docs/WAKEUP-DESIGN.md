# Wakeup design

`Linux::Event::Wakeup` is the public eventfd boundary for notifying a Loop
from outside its owning interpreter. It solves one narrow problem: an epoll
Loop may be asleep when another thread or process has made application work
available.

## Public shape

An application defines one named callback:

```perl
package ResultWakeup;
use parent 'Linux::Event::Wakeup';

sub on_wakeup ($wakeup, $count) {
    my $queue = $wakeup->data;
    while (defined(my $result = $queue->dequeue_nb)) {
        say "completed: $result";
    }
    $wakeup->loop->stop;
}
```

Construction and attachment follow the same lifecycle as the other public
objects:

```perl
my $wakeup = $loop->add(ResultWakeup->new(
    data => $results, # optional
));
```

The callback CV is resolved once per subclass. `signal($increment)` performs
an eventfd write and returns the Wakeup. It never runs `on_wakeup` inline.
`cancel()` is idempotent and terminal.

## Notification is not work transport

An eventfd carries a 64-bit counter, not a Perl scalar, object, or coderef. A
producer must publish its result through a channel appropriate to that
producer before calling `signal`:

- `Thread::Queue` or another ithread-safe queue;
- shared native memory with its own synchronization;
- a pipe or socket carrying serialized records;
- an application-owned cross-process queue.

The callback receives the counter total drained in that Loop turn. Several
signals can therefore coalesce into one callback. The queue, not the counter,
is the source of truth for individual results.

## Why this is not Loop post

A general `$loop->post($coderef)` API suggests that arbitrary Perl values and
callbacks can cross native threads safely. They cannot. Perl values belong to
an interpreter, and a distribution-level queue would still need to define
serialization, ownership, cancellation, shutdown, exception, and fork rules.

Linux::Event instead exposes the safe primitive. Native resolver workers use
a private typed C completion queue plus eventfd because their result schema is
known internally. Applications with another worker system pair Wakeup with
their own safe result channel. No public Poster object or hidden Perl callback
queue is required.

## Why not repeat raw watch code

Raw `$loop->watch(fd => $eventfd, read => $callback)` can observe an eventfd,
but each caller would also need to create it with the right flags, drain the
counter correctly, enforce single-interpreter management, protect fork and
ithread destruction, and close it in the right order. Wakeup packages those
rules as one logical Loop object while retaining the raw reactor for unusual
descriptor types.

## Threaded Perl and native threads

Linux::Event does not require a Perl built with ithreads. The resolver uses
native pthreads that never enter Perl. Wakeup is useful without ithreads for
native extensions, external libraries, and forked children.

On an ithread-enabled Perl, a cloned Wakeup handle may call only `signal`.
Loop, callback, watcher, and `data` state remain in the creating interpreter.
The clone cannot attach, cancel, inspect the Loop, or change owner data. Clone
creation duplicates the eventfd with close-on-exec, and clone destruction
closes only that duplicate. The duplicate is tagged with its receiving
interpreter, so a Wakeup object accidentally returned through `join` cannot
close or reuse the worker's stale descriptor in the owner interpreter. The
owner can therefore cancel its watched descriptor without leaving another
interpreter holding a stale descriptor number that could be reused for an
unrelated resource.

## Fork behavior

A child created after Wakeup construction inherits the eventfd and may call
`signal` until it executes another program. The descriptor is close-on-exec.
The child cannot manage the parent's Wakeup. Cross-process payloads still need
IPC, and applications must follow the resolver and Signal rules that require
forking before those native services start.

## Native path and fairness

Wakeup creates one nonblocking, close-on-exec eventfd and one ordinary Loop
registration. A dispatch performs one eventfd read. Signals arriving after
that read leave the descriptor readable for another Loop turn, avoiding an
unbounded drain when producers are continuously active.

Counter saturation makes a nonblocking eventfd write fail rather than losing
the existing readiness. `signal` reports that kernel failure synchronously.
Callback exceptions propagate from Loop dispatch and do not implicitly cancel
the Wakeup.
