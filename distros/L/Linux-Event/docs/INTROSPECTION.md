# Loop Introspection

Linux::Event exposes a query-oriented view of a Loop without turning
diagnostics into permanent hot-path work. The public API is:

```perl
$loop->running;
$loop->count;
$loop->has($object);
$loop->objects;
$loop->inspect($object);
$loop->census;
$loop->resources;
$loop->why_alive;
$loop->pressure;
$loop->profile($boolean);
$loop->stats;
$loop->reset_stats;
```

## Cost model

| Method | Cost | Notes |
| --- | --- | --- |
| `running` | O(1) | Reads native driver state. |
| `count` | O(n + r) | Enumerates authoritative object and fd registries. |
| `has($object)` | O(n + r) | Exact identity search with Loop/lifecycle validation. |
| `objects` | O(n + r) | Returns a new array reference in unspecified order. |
| `inspect($object)` | O(n + r) | Validates membership, then reads maintained state. |
| `census` | O(n + r) | Counts the current managed-object snapshot. |
| `resources` | O(r) | Scans the native fd registry. |
| `why_alive` | O(n + r) | Combines managed objects and public raw registrations. |
| `pressure` | O(r) | Uses current native capacities and existing statistics. |
| `profile($boolean)` | O(1) | Changes future timing collection only. |
| `stats` | O(1) | Copies the fixed native statistics structure. |
| `reset_stats` | O(1) | Clears counters without changing profile state. |

Here `n` is the number of managed public objects and `r` is the native fd
registry capacity. No introspection method runs implicitly during dispatch.
Queries enumerate the authoritative native Timer heap, watcher ownership, and
existing Signal, Wakeup, and resolver registries. There is no duplicate
managed-object registry to update during attachment or dispatch.

## Managed objects

`count`, `has`, `objects`, and `census` describe public Stream, Listener,
Datagram, Timer, Signal, Wakeup, and Process objects. Opaque registrations
returned by `watch()` and private helper objects are not managed objects.

`has($object)` requires exact reference identity and current ownership by that
Loop. A terminal, detached, expired, cancelled, failed, or exited object is not
present. `objects` returns the actual objects in a new array reference; their
order is deliberately unspecified.

`census` always contains these singular keys, including zero values:

```perl
{
    stream   => 0,
    listener => 0,
    datagram => 0,
    timer    => 0,
    signal   => 0,
    wakeup   => 0,
    process  => 0,
}
```

## Object inspection

`inspect($object)` returns a new hash reference. Every result contains `type`,
`class`, and `registered`. A supported object that is detached, terminal, or
owned by another Loop is described without exposing stale state:

```perl
{
    type       => 'timer',
    class      => 'MyTimer',
    registered => 0,
}
```

Registered objects also include `state` and type-specific fields:

| Type | Additional fields |
| --- | --- |
| stream | `fd`, `local`, `peer`, `transport`, `pending_bytes`, `read_paused`, `read_eof`, `write_ended`, `write_blocked` |
| listener | `fd`, `host`, `port`, `path`, `family`, `paused`, `accepted` |
| datagram | `fd`, `local`, `peer`, `connected`, `pending_bytes`, `pending_datagrams`, `read_paused` |
| timer | `deadline`, `interval`, `expirations` |
| signal | `signals` |
| wakeup | no additional fields in the first API |
| process | `pid`, `pending_stdin_bytes` |

The hash is a snapshot. Address values are immutable Address objects; changing
the returned hash does not change the inspected object.

## Native resources

`resources` reports Linux and allocation state directly from the Loop:

```perl
{
    epoll_fd                 => 3,
    timer_fd                 => 5,       # undef until first Timer
    registered_fds           => 4,
    public_registrations     => 1,
    internal_registrations   => 3,
    public_registration_fds  => [7],
    active_timers            => 2,
    registry_capacity        => 1024,
    timer_heap_capacity      => 64,
    event_capacity           => 8192,
}
```

Internal registrations back managed objects and services such as timerfd,
signalfd, resolver eventfd, pidfd, and sockets. A registration created directly
with public `watch()` is reported separately. `timer_fd` is `undef` until the
Loop first creates its shared timer source.

## Liveness and pressure

`why_alive` returns an array reference of actionable user-visible reasons. A
managed-object reason is its inspection snapshot plus `object`, containing the
exact object. A direct raw registration reason contains `type =>
'registration'`, `registered => 1`, and `fd`. Private backing registrations do
not appear as duplicate reasons.

`pressure` returns conservative current indicators rather than a synthetic
health score:

```perl
{
    registrations => { active => 4, capacity => 1024, utilization => 0.0039 },
    timers         => { active => 2, capacity => 64,   utilization => 0.0312 },
    event_batch    => { maximum => 8, capacity => 8192, utilization => 0.0010 },
}
```

`event_batch.maximum` and its utilization are `undef` until at least one
epoll wait has completed. These keys describe implementation pressure only;
they do not predict callback latency or application health.

## Profiling and statistics

```perl
$loop->profile(1);       # returns $loop
# run the workload
my $stats = $loop->stats;
$loop->profile(0);       # keeps accumulated values
$loop->reset_stats;      # keeps the enabled/disabled state
```

Statistics remain readable while profiling is disabled. Profiling does not
reset them, and `reset_stats` does not change profiling state. The first API
times epoll waits, epoll control operations, watcher lookup, and dispatch
batches. It deliberately does not place a clock read around every callback.
Callback invocation counts remain available through `stats`.
