# Kernel Timer design

`Linux::Event::Kernel::Timer` is the scheduled-work leaf for
`Linux::Event::Loop`. Applications define behavior in a concrete subclass,
keep instance context in `data`, and attach through either `loop => $loop` or
`$loop->add($timer)`.

## Public API

A concrete Timer type implements one named callback:

```perl
package Heartbeat;
use parent 'Linux::Event::Kernel::Timer';

sub on_timer ($timer) {
    my $connection = $timer->data;
    $connection->write("ping\n");
}
```

Construction accepts one schedule:

- `after => $seconds` for a relative one-shot deadline;
- `at => $monotonic_seconds` for an absolute one-shot deadline;
- `every => $seconds` for fixed-rate recurrence;
- `after` or `at` plus `every` for a distinct first deadline.

`after` and `at` are mutually exclusive. Public values are fractional seconds;
internal deadlines are integer nanoseconds.

`Linux::Event::Kernel::Timer->now` returns the same monotonic clock used by
absolute deadlines.

`reschedule()` accepts the same scheduling grammar and returns the same object.
It is valid while active and from inside `on_timer`. Cancellation and final
one-shot expiration are terminal and cannot be reattached or rescheduled.

The Loop deliberately has no Timer factory. Timer remains a normal attachable
semantic resource:

```perl
my $timer = $loop->add(Heartbeat->new(
    every => 15,
    data  => $connection,
));
```

## Native scheduler

One Loop owns one lazily created `timerfd` and one indexed native minimum heap.
The timerfd is armed to the heap root with `TFD_TIMER_ABSTIME`; many public
Timer objects still require only one kernel timer descriptor per Loop.

Each heap entry stores its current index so cancellation and rescheduling do
not require a linear search.

The ordering key is `(deadline, sequence)`. Sequence provides FIFO delivery for
identical deadlines. Callback dispatch is bounded per expiration batch so a
large timer cohort cannot permanently exclude ordinary descriptor readiness.

An immediate or already-past deadline is never invoked inline from the
constructor. A Timer scheduled for immediate delivery from inside `on_timer`
is likewise deferred to a later Loop turn, avoiding recursive callback chains.

## Recurrence and missed ticks

Recurring Timers are fixed-rate. The next deadline advances from the prior
scheduled deadline instead of callback completion, avoiding cumulative drift
from ordinary callback latency.

If the Loop is late by multiple intervals, the schedule advances beyond the
current monotonic clock and delivers one semantic callback. `expirations`
reports how many periodic ticks that callback represents.

The recurring Timer is reinserted before callback entry. If an application
callback throws, the exception can propagate without silently deleting the
recurring schedule. The application can cancel or reschedule after catching the
exception.

## Ownership and cleanup

An attached active `Kernel::Timer` is retained by its Loop. Dropping an
application reference does not implicitly cancel scheduled work.

The Timer's ownership relation to the Loop is arranged so Loop destruction can
terminate remaining timer resources instead of leaving a cycle.

`cancel()` is idempotent and terminal. It removes the heap entry and releases
application data according to the Timer lifecycle contract. A one-shot Timer
performs terminal cleanup after its final callback.

When cancellation occurs inside `on_timer`, callback-local state remains valid
until the callback returns.

Timer callbacks can directly modify other semantic resources retained in
`data`, such as closing an `IO::Sock::Stream`, pausing an
`IO::Sock::Listener`, or stopping the Loop.

## Ordered-byte deadline integration

Established idle/read/write/operation deadlines use private timer objects on
the same Loop scheduler. They are not exposed as application Timers.

An ordered-byte resource owns at most one private scheduler entry representing
its earliest current deadline. This preserves one shared timerfd design while
keeping deadline policy with the resource it protects.

See `ORDERED-BYTE-DEADLINES.md` for that policy.

## Performance contract

The performance regression suite gates Timer attach/cancel churn and immediate
expiration delivery alongside reactor and ordered-byte workloads.

The dedicated timer microbenchmark measures lifecycle, indexed-heap
rescheduling, and equal-deadline expiration at multiple active Timer counts.
Loop statistics expose timerfd creation/rearm, scheduling, cancellation,
callback delivery, coalescing, and maximum heap size.

## Native implementation boundary

`Linux::Event::Kernel::Timer` is both the supported public class and the native
timerfd scheduler host. Private descriptor state remains behind that class and
does not add a Perl dispatch layer to timer delivery.
