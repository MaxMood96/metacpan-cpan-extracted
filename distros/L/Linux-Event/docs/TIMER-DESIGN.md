# Timer design

`Linux::Event::Timer` is the scheduled-work object for `Linux::Event::Loop`.
It follows the same public pattern as Stream: applications define behavior in a
subclass, keep instance context in `data`, and attach through either
`loop => $loop` or `$loop->add($timer)`.

## Public API

A concrete Timer type implements one named callback:

```perl
package Heartbeat;
use parent 'Linux::Event::Timer';

sub on_timer ($timer) {
    my $connection = $timer->data;
    $connection->write("ping\n");
}
```

Construction accepts one schedule:

- `after => $seconds` for a relative one-shot deadline
- `at => $monotonic_seconds` for an absolute one-shot deadline
- `every => $seconds` for fixed-rate recurrence
- `after` or `at` plus `every` for a distinct first deadline

`after` and `at` are mutually exclusive. Public values are fractional seconds;
internal deadlines are integer nanoseconds. `Linux::Event::Timer->now` returns
the same monotonic clock used by absolute deadlines.

`reschedule` accepts exactly the same schedule grammar and returns the same
Timer. It is valid while active and from inside `on_timer`. Cancellation and
final one-shot expiration are terminal: neither state can be reattached or
rescheduled.

Loop deliberately has no Timer factory or scheduling convenience methods.
Timer remains a normal attachable object:

```perl
my $timer = $loop->add(Heartbeat->new(
    every => 15,
    data  => $connection,
));
```

## Native scheduler

One Loop owns one lazily created `timerfd` and one indexed minimum heap. The
timerfd is armed to the heap root with `TFD_TIMER_ABSTIME`; adding 100,000
Timers still consumes one kernel timer descriptor. Each heap entry stores its
current index, allowing cancellation and rescheduling without a linear search.

The ordering key is `(deadline, sequence)`. The sequence produces FIFO delivery
for equal deadlines. Timer callbacks are capped at 1024 per expiration batch so
a large cohort cannot permanently exclude ordinary descriptor readiness.

A zero or already-past deadline is never called inline. A Timer created or
rescheduled for immediate delivery from inside `on_timer` is also held until a
subsequent Loop turn, preventing reentrant callback chains.

## Recurrence and missed ticks

Recurring Timers are fixed-rate. Their next deadline advances from the prior
scheduled deadline rather than callback completion, so normal callback latency
does not accumulate drift. If the Loop is late by multiple intervals, it
advances past the current clock and delivers one callback. `expirations`
reports how many periodic ticks that callback represents.

The recurring Timer is reinserted before callback entry. Consequently, a thrown
callback exception propagates from the Loop without silently losing the
schedule. Applications may cancel or reschedule it after catching the error.

## Ownership and cleanup

An attached active Timer is retained by its Loop. External references may be
dropped without cancelling the Timer. The Timer's Loop reference is weak, so
destroying the Loop terminates its remaining Timers rather than forming a
cycle.

`cancel` is idempotent and terminal. It removes the heap entry and releases
application data. A one-shot Timer performs the same cleanup after its final
callback. When cancellation happens during `on_timer`, reference cleanup waits
until callback return so `$timer` and its data remain safe for the duration of
that callback.

Timer callbacks may directly modify the rest of an application through
`data`--for example, close a Stream, stop a Listener, update shared state, or
schedule other Timers. No application container or subclass cross-link is
required.

## Performance contract

`bench/run-performance-regression.pl` gates attach/cancel churn and zero-delay
expiration delivery alongside the existing reactor and Stream workloads.
`bench/run-timer-microbench.pl` separately measures lifecycle, indexed-heap
rescheduling, and equal-deadline expiration at multiple active Timer counts.
Loop statistics expose timerfd creation/rearm, schedule, cancel, callback,
coalescing, and maximum-heap-size counters for diagnosis.
