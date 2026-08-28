# Object lifecycle and Loop attachment

Linux::Event has one owner of readiness: `Linux::Event::Loop`. It does not
require a public Watcher base class. Public objects implement their own
lifecycle and expose a private `_attach_to_loop` hook that `Loop->add()` uses.
The hook is an implementation contract between this distribution's classes,
not an application subclass API.

## Two equivalent construction styles

Every attachable public class accepts `loop => $loop`:

```perl
my $stream = ClientStream->connect(
    loop => $loop, host => '127.0.0.1', port => 9999,
);

my $listener = Linux::Event::Listener->new(
    loop => $loop, stream_class => 'ServerStream',
    host => '0.0.0.0', port => 9999,
);

my $timer = SessionTimer->new(
    loop => $loop, after => 30, data => $session,
);

my $signal = ShutdownSignal->new(
    loop => $loop, signals => [SIGINT, SIGTERM], data => $server,
);

my $datagram = MetricsDatagram->new(
    loop => $loop, host => '0.0.0.0', port => 9000,
);

my $wakeup = ResultWakeup->new(
    loop => $loop, data => $result_queue,
);

my $process = WorkerProcess->spawn(
    loop => $loop, command => ['/usr/bin/worker', '--once'],
);
```

An object may instead be constructed detached and passed to `add()`:

```perl
my $stream = $loop->add(ClientStream->connect(
    host => '127.0.0.1', port => 9999,
));

my $listener = $loop->add(Linux::Event::Listener->new(
    stream_class => 'ServerStream',
    host => '0.0.0.0', port => 9999,
));

my $timer = $loop->add(SessionTimer->new(
    after => 30, data => $session,
));

my $signal = $loop->add(ShutdownSignal->new(
    signals => [SIGINT, SIGTERM], data => $server,
));

my $datagram = $loop->add(MetricsDatagram->new(
    host => '0.0.0.0', port => 9000,
));

my $wakeup = $loop->add(ResultWakeup->new(
    data => $result_queue,
));

my $process = $loop->add(WorkerProcess->spawn(
    command => ['/usr/bin/worker', '--once'],
));
```

`add()` sets the object's Loop, starts its activity, and returns the same
object. Neither style is a compatibility adapter; they are equal parts of the
public API. The constructor form is concise when the Loop is already known.
The detached form is useful when configuration and activation happen in
different parts of an application.

## Ownership rules

- An attachable object belongs to at most one Loop.
- An object can be attached only once.
- A terminal object cannot be reattached.
- Stream owns its established socket from construction or successful connect
  until `close()`, `detach()`, or destruction.
- A deadline-enabled Stream owns at most one private Timer in its Loop's shared
  scheduler. Close, detach, failure, and Loop destruction cancel that entry.
- Listener owns sockets it creates. An adopted listener is closed only when
  `owns_socket => 1` was requested.
- Loop retains an active Timer even when the application drops its reference.
  A one-shot Timer releases its `data` after callback completion; recurring
  Timers retain it until cancellation or Loop destruction.
- Loop retains active Signal objects through one shared native signalfd
  service. Cancellation or Loop destruction restores Loop-owned mask entries
  and releases retained data.
- Datagram owns created sockets and Unix paths. Adopted handles default to
  caller ownership. `detach()` returns an open handle and disables path
  removal.
- Wakeup owns one eventfd and its Loop registration. Only `signal()` may be
  used from a cloned ithread handle or forked child.
- Loop retains a running Process. Process owns its pidfd and pipe ends but does
  not implicitly signal a child on destruction.
- `add()` returns the exact object it received; it does not wrap or replace it.

Violations are rejected synchronously. This makes the Loop registry and native
descriptor ownership unambiguous.

## Logical objects and native registrations

A public object is a logical activity, not a one-to-one wrapper around an epoll
entry. A connecting Stream can temporarily own a socket registration and a
timerfd registration. After connection it owns the established socket
registration. The application continues to hold one Stream object throughout.

Listener similarly owns its listening registration and creates Stream objects
for accepted sockets. It attaches each Stream before the optional Listener
`on_accept` callback; plain Stream `on_ready` follows that callback, while TLS
Stream `on_ready` follows its successful handshake. Listener passes its `data`
value to each accepted Stream. These native registrations are implementation
details.

Timer is also a logical object rather than a timerfd wrapper. All active Timers
on one Loop share one lazily created timerfd and live in a native indexed heap.
Cancellation is terminal and idempotent. Rescheduling is allowed while active
or from inside `on_timer`, but an expired or cancelled Timer cannot be revived.
Private Stream deadline Timers follow the same scheduler rules but are not
application objects. Their data holds only a weak route to the owning Stream,
so deadline ownership does not introduce a Perl reference cycle.

Signal is a logical subscription rather than a signalfd wrapper. All Signal
objects on one Loop share one signalfd and native fan-out registry. One object
may subscribe to several numbers and several objects may subscribe to the same
number on that Loop.

Wakeup is a logical notification rather than an eventfd registration handle.
Its eventfd counter says that external work may be available; the associated
thread-safe queue or IPC channel remains the source of payloads.

Datagram owns a packet socket and whole-packet output queue. Process may own a
pidfd plus four registrations: pidfd, stdin, stdout, and stderr. These remain
one application object because their lifecycle and callbacks are inseparable.

## Raw descriptor registrations

Low-level applications can register a descriptor directly:

```perl
my $registration = $loop->watch(
    fh   => $fh,
    read => sub ($registration) {
        my $count = sysread($registration->fh, my $bytes, 8192);
        $registration->cancel if defined($count) && $count == 0;
    },
);
```

`watch()` attaches immediately and returns an opaque native registration
handle. It supports readiness-interest changes, accessors, and `cancel()`, but
it is not a public class hierarchy and must not be subclassed. Use Stream or
Listener when the resource needs a higher-level ownership policy.

Cancellation, replacement, and Loop destruction make that handle inert.
Native watcher or fd reuse cannot redirect an obsolete handle to another
registration. Retained Perl state is released immediately outside dispatch and
after the active callback returns when cancellation occurs during dispatch.

## Destruction

Explicit `close()` is recommended because it makes application intent and
callback timing clear. Destructors are a safety net. Stream fires `on_close`
once when it closes an owned connection, but `detach()` deliberately does not:
the resource remains open and ownership transfers to the caller.

For Timer, explicit `cancel()` is the corresponding terminal operation. Loop
destruction cancels every remaining Timer and releases its retained data. If a
Timer cancels itself during `on_timer`, cleanup is deferred until the callback
returns so callback-local access remains safe.

Signal cancellation follows the same terminal rule. Self-cancellation and
cross-cancellation during fan-out are safe; callback-local data remains visible
until the active callback returns.

Datagram `close()` releases an owned socket and path and calls `on_close`;
`detach()` transfers the handle without calling `on_close`. Process has no
generic cancellation method: applications close stdin or send an explicit
signal and retain the Loop until `on_exit`.

## Interpreter ownership

Loop and every native resource-owning object are confined to their creating
Perl interpreter and opt out of ithread cloning. Wakeup is the single narrow
exception: the clone contains only enough scalar state to write the shared
eventfd through its own descriptor duplicate. It does not clone the Loop graph,
callbacks, registrations, or owner data. This prevents double-close and
native-pointer reuse across interpreters.

Class declarations remain available in a child ithread. Stream, Timer, and
Signal rebuild their immutable native class descriptors there on first use, so
the child may create its own independent resources and Loop. An object created
before the thread boundary still belongs only to its original interpreter.
