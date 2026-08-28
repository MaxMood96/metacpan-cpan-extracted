# Native architecture

## Hot path

The current steady-state readiness path is intentionally short:

```text
epoll_wait()
   |
   v
epoll_event.data.ptr
   |
   v
le_watcher_t *
   |
   v
XS dispatch
   |
   v
one Perl callback
```

There is no fd-to-Perl-hash lookup in the hot dispatch path. The fd-indexed
native registry remains for registration, replacement, cancellation, and
lifetime management.

## Native loop state

`le_loop_t` owns:

- epoll fd
- reusable `struct epoll_event` array
- fd-indexed `le_watcher_t **` registry
- stop state
- callback-scope policy
- watcher lifecycle lists used by optional reclaim diagnostics
- cheap counters and optional timing buckets

The default event array capacity is 8192.

Normal raw registration uses `watch(fh => $fh)` or `watch(fd => $fd)`.
That Perl-facing method resolves a handle to its integer fd once at construction
and then enters the existing native registration path. It adds nothing to
steady-state readiness dispatch. `watch_fd` remains the low-level positional
entry point underneath it.

## Native watcher state

`le_watcher_t` contains the fd, epoll mask/flags, owning loop pointer, callback
SV/CV references, optional accessor references, callback-mode flags, and
benchmark/lifecycle state.

`epoll_event.data.ptr` points directly at this structure, which avoids a
registry lookup after `epoll_wait()` returns.

## Callback representation

When a callback is a plain coderef the XS layer stores the CV directly rather
than retaining an extra RV wrapper. The fast path can therefore call the CV
with minimal Perl-side construction.

Normal callbacks receive the watcher handle. A no-argument mode exists for hot
closures that capture their own state.

## Temporary scopes

The dispatcher shares an `ENTER`/`SAVETMPS` scope across a bounded group of
callbacks while still running `FREETMPS` after each callback. The default scope
limit is 128 callbacks, selected from benchmark sweeps as a stable balance.

## Terminal-event semantics

For an event containing terminal flags and normal readiness, dispatch order is:

```text
EPOLLERR / EPOLLHUP / EPOLLRDHUP
EPOLLIN
EPOLLOUT
```

The watcher is re-checked after each callback so cancellation takes effect
within the same returned epoll batch.

Registering a new native record for an already registered fd uses one
`EPOLL_CTL_MOD`, changes `epoll_event.data.ptr` to the new record, and marks the
old handle inactive. Cancelling that old handle is harmless and cannot remove
the replacement.

## Native registration lifetime

The public opaque handle is a stable registration token that refers to a native
watcher while it is active. Epoll continues to store the watcher pointer
directly. `cancel`/`unwatch_fd` removes the epoll registration, marks the token
inert, and releases its retained Perl state immediately outside dispatch or
after the active callback returns. Replacing an fd or destroying the Loop also
makes every obsolete token inert, so native watcher or fd reuse cannot redirect
an old handle to a new resource.

Experimental watcher reclamation can defer watcher reuse until a returned epoll
batch has finished, avoiding reuse while an event array may still contain the
old `data.ptr`.

The performance default keeps aggressive reclaim disabled because the memory
savings measured in earlier experiments came with a throughput cost.

## Profiling

Cheap counters remain enabled. Nanosecond timing of epoll/callback/dispatch
regions is opt-in because instrumentation itself changes the workload.

## Benchmark-only native echo

The XS source still contains a private native echo diagnostic used to decompose
callback entry from Perl `sysread`/buffer/`syswrite` work. It is deliberately
prefixed `_bench_` and is not an application API. Its result is what motivated
the next Stream work: the larger remaining cost is above the reactor.

## Stream class descriptors

The higher-level Stream extension has a separate native state model. The first
construction of a concrete `Linux::Event::Stream` subclass creates one immutable
XS descriptor containing resolved named callbacks, read size, output
watermarks, optional hard pending-output limit, framed-buffer limit, and native
parser configuration.

Every connection's XS state retains that descriptor and owns only mutable fd,
input/parser, output-queue, lifecycle, and counter state. A framed connection
therefore does not copy callbacks, delimiters, prefix policy, or Stream policy
settings into every allocation.

The retained descriptor reference may be replaced explicitly by
`transition_to()` while the mutable connection state stays in place. Parser
loops snapshot their starting descriptor and stop after a callback changes it.
The input driver then reinterprets the unread native suffix with the target
descriptor. Raw targets receive the suffix as bytes; framed targets continue
native boundary detection. This gives protocol upgrades a safe point without
re-registering the fd or copying the output queue.

The connection state also holds a native transport operations table and
provider context. The default `plain` identity is checked once per operation,
then XS issues the original fd syscall directly. Non-plain providers can later
map the same read, write, vectored-write, retry-direction, error, and writable
shutdown operations to another byte transport. This keeps parsers, queues, and
backpressure independent of encryption while avoiding a Perl callback or
indirect function call on the ordinary syscall path.

The segmented write queue checks a nonzero `max_pending_bytes` before copying a
new unsent remainder. Overflow enters Perl only for the semantic typed-error
and close transition; no over-limit segment is allocated. The zero/default
case is one predictable native branch and otherwise follows the unchanged
write path.

Raw input drains into a reusable native read buffer and crosses into Perl for
`on_data`. Framed input drains directly into native connection storage, runs
the built-in parser there, and crosses into Perl only for complete
`on_message` values or semantic errors. Both paths recheck pause and close state
after callbacks.

The Stream extension does not include private reactor headers. Loop passes
watcher data directly to Stream's private readiness entry points, preserving a
generic readiness core and an independently testable buffered Stream layer.

## Public ownership layer

`Linux::Event::Loop->add()` accepts distribution objects that implement Loop
attachment: Stream, Listener, Datagram, Timer, Signal, Wakeup, and Process.
There is no public Watcher or IO base class and no generic Perl dispatcher. Raw
`watch()` returns an opaque native handle. Every high-level object retains its
concrete cached callbacks and private registrations.

An application object is one logical activity rather than one fd. A connecting
Stream can own attempt and deadline registrations until connection completes,
then retains the same public identity while its established socket is
registered with the native Stream engine.

## Timer scheduler layer

Every Loop lazily creates one nonblocking, close-on-exec timerfd when its first
Timer is attached. All active Timers on that Loop share the descriptor. An
indexed native minimum heap orders nanosecond monotonic deadlines and permits
O(log n) insertion, cancellation, and arbitrary rescheduling.

Each Timer subclass contributes one immutable descriptor containing its
resolved `on_timer` CV. Instances hold only mutable schedule, heap position,
application data, lifecycle, and expiration count. The Loop retains active
instances, so dropping an application reference does not cancel work.

The timerfd watcher enters a specialized native dispatch path. Equal deadlines
use schedule sequence for FIFO order. Fixed-rate recurring timers advance from
their previous deadline, coalescing missed intervals into one callback.
Dispatch is capped at 1024 callbacks per batch, and immediate work created from
inside a Timer callback is deferred to a later Loop turn.

Established Stream deadlines reuse this scheduler. A deadline-enabled Stream
owns at most one private Timer containing a weak route back to the Stream. That
heap entry always represents the earliest idle, read, write, or explicit
operation deadline. Native Stream state records successful I/O timestamps only
when inactivity tracking is enabled; progress never enters Perl merely to
reschedule the heap. When an old deadline arrives, the private callback checks
the latest snapshot and either expires the Stream or moves the same Timer.
Ordinary Streams perform no activity clock reads.

## Signal delivery layer

Each Loop with Signal subscriptions owns one private nonblocking signalfd and a
native per-number fan-out registry. Signal subclass callbacks are cached once.
The raw lean watcher crosses into the Signal extension once per readiness,
where complete signalfd batches are drained and aggregated before semantic
callbacks enter Perl.

One Signal may register several numbers and several Signals on that Loop may
register the same number. Dispatch snapshots subscribers so callbacks may
cancel themselves or later subscribers safely. Reference counts keep a number
in the shared mask until its last subscriber is gone. Original thread-mask
membership is recorded and only entries changed by Linux::Event are restored.

## Stream acquisition layer

The private `Linux::Event::Stream::_Connection` engine owns outbound socket
acquisition, while the public Stream owns the entire logical lifecycle. The
engine validates address modes, stores candidate/attempt state, and checks
`SO_ERROR` after writable readiness. Sockets are created with
`SOCK_NONBLOCK | SOCK_CLOEXEC`.

A small adjacent XS extension owns only timerfd mechanics. It gives pending
requests monotonic deadlines and ensures immediate success or operational
failure is delivered from the loop rather than reentrantly inside the
constructor. The attempt engine is intentionally a cold Perl path until
profiling demonstrates a reason to move it.

This private connection deadline helper remains separate from the public Timer
scheduler in this release. Migrating connection and TLS deadlines to Timer is
a later lifecycle change, not part of the Timer API itself.

`MyStream->connect()` creates one Stream and the private engine reports directly
to it. During success, Stream binds native state to the connected fd. The
application-visible object is never replaced.

Hostname resolution lives in the shared private `Linux::Event::_Resolver` XS
extension used by Stream and Datagram. Two lazy native workers per Loop run
`getaddrinfo` without touching Perl state, copy results to a native completion
queue, and signal one eventfd. An ordinary raw Loop watcher drains that queue
on the reactor thread. The connection engine interleaves
IPv6/IPv4 candidates, starts pending alternatives at 250 ms intervals, and
transfers only the first successful socket while closing every loser. Numeric,
Unix, and packed addresses do not start the resolver.

## Listener acquisition layer

`Linux::Event::Listener` owns inbound stream-socket acquisition. It creates TCP
or filesystem Unix listeners, or adopts a caller-provided listening handle,
then registers one read watcher for that listening descriptor. It never
creates a watcher for an accepted connection.

Readiness enters a private Listener XS engine that drains `accept4()` with
atomic `SOCK_NONBLOCK | SOCK_CLOEXEC`. Descriptor and packed-sockaddr pairs
return to Perl for the cached private `_accept_client` construction method.
Address text remains lazy through `Linux::Event::Address`; applications that
do not inspect a peer avoid formatting it.

Listener constructs its configured Stream subclass, attaches the Stream to the
same Loop, invokes the optional public `on_accept($listener, $stream)`, and then
reports a plain Stream ready. TLS Stream readiness waits for its handshake.
Listener data is passed automatically to every accepted Stream. A TLS
declaration on the Stream class selects a fresh server-side provider and is
validated before Listener creates its socket. Listener does not create a
temporary accepted-socket registration. An
`on_accept` exception closes only that Stream and becomes a nonfatal callback
Error. Resource accept errors pause listener readiness before the typed error
callback so a readable backlog cannot create an error spin.

## Socket policy layer

Common socket validation and `setsockopt` conversion live in a private
cold-path module shared by Stream and Datagram. Stream copies cached class
policy into one acquisition instance, applies constructor overrides, and
configures every outbound candidate before bind/connect. Accepted and adopted
Streams apply the same policy before native transport attachment. Listener
separately owns listening-socket creation policy.

The optional cached `configure_socket` callback follows built-in policy. It is
outside steady-state I/O. Failures become typed `socket_configuration` values
instead of silently changing candidate or transport behavior.

## Wakeup layer

Wakeup owns one nonblocking eventfd and raw lean registration. An ithread clone
duplicates only the descriptor identity needed for `signal`; cancellation and
destruction cannot redirect a stale fd number to an unrelated resource. Loop,
watcher, callback descriptor, and data live in an owner-only state object that
is skipped during ithread cloning. All other native resource objects also skip
cloning.

The private resolver eventfd is not implemented through public Wakeup because
its native workers already own a typed C completion queue and cancellation
table. Both paths share the same architectural rule: foreign threads publish
data before writing eventfd, and Perl handles semantics only on the Loop
thread.

## Datagram layer

Datagram uses a separate XS packet engine. One readiness call allocates one
receive buffer and drains `recvmsg(MSG_DONTWAIT | MSG_TRUNC)` into a flat batch
of payload, packed peer, original length, and truncation fields. Perl creates
lazy Address values and invokes the cached semantic callback once per packet.

Output uses `send` or `sendto` with `MSG_NOSIGNAL`. Queue segments are whole
packets with separate byte and packet accounting. Connected hostname mode
reuses the private resolver with `SOCK_DGRAM` hints but does not reuse Stream's
byte buffers or TCP attempt race.

## Process layer

Process constructs stdio pipes in Perl's owning interpreter, then one XS call
uses `posix_spawnp` file actions and opens a pidfd. No Perl code executes in a
post-fork child. The Loop may register pidfd, stdin, stdout, and stderr, all
routed back to one Process object.

pidfd readiness uses `waitid(P_PIDFD)` for decoded exit identity. Pipe output
is drained before `on_exit`; queued stdin uses a SIGPIPE-safe native write
helper. Signals use `pidfd_send_signal`, avoiding numeric PID reuse. Setup
failure after spawn kills and reaps the exact child before partial ownership is
released.
