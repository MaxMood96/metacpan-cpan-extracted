# XS Roadmap

The generic reactor and the first native Stream engine are now implemented in
the same Linux::Event distribution. The guiding rule remains:

> Perl should receive semantic events; XS should absorb repetitive mechanical
> events whenever doing so preserves a clean, general API.

## Completed foundation

- XS-first epoll loop and native watcher registry
- direct native watcher dispatch
- native Stream readable draining
- reusable native framed-input storage
- native immediate writes and segmented `writev()` queue draining
- native backpressure byte accounting
- optional hard native pending-output limits with typed terminal errors
- native transport operation contract with a specialized plain-fd fast path
- native Delimiter framing
- native Fixed framing
- native configurable LengthPrefix framing
- native U32BE framing
- native Netstring framing
- native Varint framing
- native DecimalLength framing
- one immutable callback/framer/transport descriptor per Stream subclass
- lightweight per-connection references to shared descriptors
- exact-name declarative loading without a duplicate framer keyword registry
- raw `on_data` fallback for application-specific protocols
- in-place raw/framed protocol transitions that retain unread native input,
  queued output, registration identity, lifecycle, and application state
- one shared timerfd plus an indexed native deadline heap per Loop
- cached subclass callbacks, fixed-rate recurrence, coalescing, and bounded
  dispatch for public Timer objects
- one shared signalfd, native fan-out registry, aggregate delivery, and exact
  mask restoration for public Signal objects

These are permanent regression targets. New work must not trade them away
without benchmark evidence.

## Completed - unified object lifecycle

`Linux::Event::Loop` owns high-level Stream, Listener, Datagram, Timer, Signal,
Wakeup, and Process objects through `add()`, while `watch()` creates an
immediately attached opaque native registration. There is no public Watcher or
IO base class. One logical object may own several internal epoll registrations.

Timer uses that same attachment contract without adding Loop-specific factory
methods. The abstract public Timer class caches `on_timer` once per subclass;
active instances live entirely in the Loop's native scheduler.

Signal uses the same attachment contract. Its abstract public class caches
`on_signal` once per subclass, while each Loop's private native service owns
the signalfd mask and supports multiple numbers per object plus multiple
objects per number.

`MyStream->connect()` keeps one Stream identity through outbound acquisition
and optional TLS readiness. `Linux::Event::Listener` with a configured
`stream_class`
owns inbound acquisition and constructs accepted Streams. The public hierarchy
adds no generic Perl call to steady-state native readiness dispatch.

## Completed - initial TLS provider implementation

HTTPS, secure WebSocket, and Discord require TLS. TLS is a byte transport
transform, not a message framer. The internal native operation boundary and
plain provider now exist. The bundled `Linux::Event::TLS` provider attaches
without adding OpenSSL policy or calls to the reactor core or the plain Stream
path.

The design must cover handshake readiness, encrypted and plaintext buffering,
certificate/hostname errors, shutdown, deadlines, ALPN, and transitions such as
STARTTLS without putting TLS policy into the reactor core. Initial client/server TLS,
verification, ALPN, cross-direction readiness, and close notification landed
with the 0.100_015 transport ABI. Version 0.100_016 added provider-owned
deadline-watcher lifecycle and the original external Linux::Event::TLS 0.002
added default handshake and shutdown deadlines, clean/unclean EOF
classification, native counters, and a same-Stream plain-versus-TLS benchmark.
Version 0.100_017 merged that provider into the main distribution without
merging its OpenSSL implementation into the native Stream engine.

The released attachment exact-versions the common ABI, retains provider
lifetime, and implements cross-direction readiness (`SSL_read` wanting write
and `SSL_write` wanting read). Established Stream deadlines now cover TLS after
provider readiness. Richer shutdown diagnostics, provider bounded-buffer
observability and live transport replacement remain follow-up work.

## Completed - Stream connection layer

`MyStream->connect()` owns the public outbound lifecycle. Its private
`Linux::Event::Stream::_Connection` engine implements strict
IPv4/IPv6/Unix/packed address modes, typed errors, silent cancellation, and a
default connection deadline. Socket creation uses
`SOCK_NONBLOCK | SOCK_CLOEXEC` atomically. Immediate results are deferred so
network callbacks never run inside the constructor.

The policy/state machine remains in cold Perl code. A small native timerfd
helper supplies monotonic deadlines and deferred dispatch. Same-fd native
replacement uses one `EPOLL_CTL_MOD` where an fd registration is replaced.

## Completed - native Listener layer

`Linux::Event::Listener` creates or adopts listening stream sockets and
constructs a configured Stream subclass for each accepted connection. A small
private native extension drains `accept4()` with atomic nonblocking and
close-on-exec flags and retains packed peer addresses for lazy conversion.

The default level-triggered fairness cap is safe because epoll reports a
remaining backlog again. Edge-triggered listeners require an unlimited drain.
No temporary accepted-socket registration is created before Stream attachment.
Resource exhaustion pauses readiness before typed error delivery.

## Completed - asynchronous Resolver and Happy Eyeballs

Hostname resolution is mechanically separate from Stream connection policy in
a private XS extension. Each Loop lazily owns two native resolver workers and
one eventfd completion queue. Workers never enter Perl. The normal raw Loop
watch path drains complete candidate collections, cancelled requests discard
late results, IPv6/IPv4 attempts are staggered by 250 ms, and first-success
ownership closes all losers. Literal, Unix, and packed addresses bypass the
resolver. Dedicated integration, cancellation, ordering, and microbenchmark
coverage protects the boundary.

## Completed - signalfd signal handling

`Linux::Event::Signal` provides synchronous Loop-thread delivery without Perl
signal handlers. One lazy signalfd and native subscription registry per Loop
drain and aggregate records before fan-out. Cancellation is safe during
callbacks, last-subscriber removal restores only mask entries Linux::Event
changed, and one signal number has one owning Loop per process. Resolver
workers block signals independently so native DNS cannot intercept them.

## Completed - established Stream deadlines

Stream subclasses cache idle, read, and write inactivity defaults, while each
instance may override them and own one explicit overall-operation deadline.
Established policy begins only after plain or TLS readiness and reports typed
timeout errors through the ordinary Stream close lifecycle.

At most one private Timer per Stream represents the earliest condition in the
Loop's existing timerfd/native heap. XS records successful transport activity
only when inactivity policy is enabled. Ordinary Streams perform no timestamp
syscalls, and enabled I/O progress does not enter Perl merely to move a heap
entry. Plain, TLS, transition, pause/resume, EOF, queued-write, and regression
benchmark coverage protect the contract.

## Completed - eventfd Wakeup boundary

`Linux::Event::Wakeup` exposes one subclass-defined eventfd notification
object. Foreign native threads, fork children, and cloned ithread handles may
increment its counter without entering the Loop interpreter. The Loop drains
one counter value per turn and delivers one semantic `on_wakeup` callback.

Wakeup deliberately carries no Perl payload and is not a coderef posting
queue. Applications publish data through their own thread-safe queue or IPC
channel before signalling. Thread clones own duplicate descriptors, while
callback state, Loop ownership, and application data remain confined to the
creating interpreter.

## Completed - production socket configuration

Stream class policy and constructor overrides cover local address binding,
`TCP_NODELAY`, keepalive tuning, `TCP_USER_TIMEOUT`, buffer sizing, and Linux
interface binding. Built-in policy is applied to every outbound candidate and
to accepted or adopted sockets before transport attachment. A cached
`configure_socket` hook follows built-in policy for advanced cold-path setup.

Public timeout values use seconds. Options with meaningful Linux live behavior
also have getters/setters that return the effective kernel value. Failures are
structured `socket_configuration` Errors; incompatible address families never
fall through to an unconfigured candidate.

## Completed - packet-preserving Datagram layer

`Linux::Event::Datagram` provides connected and unconnected UDP plus filesystem
Unix datagrams. Native `recvmsg(MSG_TRUNC)` batching retains packet boundaries,
original packet sizes, and packed peers. Native `send`/`sendto` preserves whole
packets through bounded output queues, soft backpressure, and hard byte or
packet limits. Connected hostname mode uses the private asynchronous resolver
with datagram hints.

Ownership, detach, Unix-path cleanup, source-specific option validation,
truncation reporting, and Loop-thread callback ordering are part of the public
contract.

## Completed - pidfd Process layer

`Linux::Event::Process` uses `posix_spawnp`, pidfd readiness,
`waitid(P_PIDFD)`, and `pidfd_send_signal`. One object owns lifecycle, decoded
exit status, and optional asynchronous stdin/stdout/stderr pipes. Output is
drained before `on_exit`; stdin writes suppress SIGPIPE without changing
process-wide signal policy.

Detached spawn specifications are side-effect free until Loop attachment. No
Perl code runs in a post-fork child, caller filehandles stay caller-owned, and
partial setup failure kills and reaps a newly spawned child before releasing
resources.

The essential completion surface is complete in version 0.101. The remaining
items below are optional expansion and evidence-driven optimization, not
release blockers.

## Priority 1 - General native framing families

Expand the built-in framing catalog while keeping one rule: built-in boundary
detection is native, while application-specific protocols parse raw `on_data`
bytes. Do not reintroduce a second arbitrary framer-object contract.

Near-term framing families include:

- a configurable `HeaderLength` family with header size, field offset/width,
  byte order, length adjustment, header inclusion, and frame limit
- additional standardized variable-integer length prefixes
- escaped/stuffed serial framing such as SLIP and COBS
- other general wire-framing families that can be expressed without embedding
  application protocol semantics

Keep protocol-specific state machines separate when the work is more than
message-boundary detection. A new general family needs a declarative module,
corresponding XS parser mode, wire-contract tests, and a native-framer benchmark
row. Its exact package name becomes the declaration name automatically.

## Priority 2 - Native Stream watcher-state transitions

Reduce remaining Perl transitions for writable interest, read suspension,
close, and half-close when profiling shows the boundary is material.

## Priority 3 - Callback coalescing/batching

Investigate fewer Perl entries without changing the ordinary one-message API:

- drain multiple reads before notifying Perl
- optionally deliver multiple complete frames together
- keep batching explicit where it changes application semantics

## Priority 4 - Native connect attempt completion

Profile before moving the remaining attempt state machine below Perl. If
high-churn connection workloads justify it, native code may:

- handle EINPROGRESS
- wait for writable readiness
- check `SO_ERROR`
- coordinate concurrent attempt readiness
- cancel timeout state
- notify Perl once with success or failure

The public Stream connection contract must not change merely to eliminate a
few cold Perl calls.

## Priority 5 - Additional Linux fd drain helpers

Profile native draining or aggregation for additional descriptor families only
when Perl currently receives repetitive mechanical events.

## Priority 6 - Buffer representation experiments

Only if profiling justifies them:

- sliding-buffer refinements
- ring-buffer alternatives
- allocation reuse or slabs

Do not optimize allocation speculatively.

## Priority 7 - Protocol acceleration above Stream

After the generic framing catalog is broad, consider reusable protocol engines
such as HTTP or WebSocket parsing. Application semantics remain Perl even when
mechanical parsing moves native.

## Benchmark policy

Keep the reactor comparison as the low-level regression standard. Keep Stream
transport/output-limit, framing, protocol-transition, and
lifecycle/retained-memory benchmarks separate.
Cross-runtime Stream
benchmarks compare high-level facilities and must continue to report exact
fairness contracts, server CPU per message, throughput, latency, and memory.
