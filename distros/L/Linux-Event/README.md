# Linux::Event

Linux::Event is a Linux-only asynchronous I/O foundation for Perl. It combines
an XS-first `epoll` reactor with timers, synchronous signal handling, eventfd
wakeups, inbound and outbound byte streams, packet-preserving datagrams,
pidfd processes, and an OpenSSL TLS transport in one distribution.

The public model is deliberately small. `Linux::Event::Loop` owns readiness
and scheduled work; `Linux::Event::Stream` and `Linux::Event::Datagram` own
byte and packet sockets; `Linux::Event::Listener` owns listening sockets;
`Linux::Event::Timer`, `Linux::Event::Signal`, and
`Linux::Event::Wakeup` own scheduled, signal, and external-notification
activities; and `Linux::Event::Process` owns pidfd lifecycle and optional
stdio. There is no public Watcher, IO, Connect, Connector, Poster, or Process
watcher class. Native epoll registrations remain opaque, so one logical object
may use several kernel event sources without exposing them as application
objects.

## Public modules

- `Linux::Event::Loop` - epoll engine and object attachment
- `Linux::Event::Stream` - TCP/Unix stream endpoints and outbound connection
- `Linux::Event::Listener` - TCP/Unix listening endpoints
- `Linux::Event::Datagram` - connected/unconnected UDP and Unix packet sockets
- `Linux::Event::Timer` - subclass-defined one-shot and recurring timers
- `Linux::Event::Signal` - subclass-defined synchronous signal subscriptions
- `Linux::Event::Wakeup` - subclass-defined eventfd notifications
- `Linux::Event::Process` - pidfd lifecycle and asynchronous standard I/O
- `Linux::Event::TLS` - declarative OpenSSL policy for Stream subclasses
- `Linux::Event::Framer::*` - native framing declarations for Stream types
- `Linux::Event::Error` - shared structured failure value
- `Linux::Event::Address` - lazy IPv4, IPv6, and Unix address value

`Linux::Event::Stream::_Connection`, `Linux::Event::_Resolver`, and the
internal socket configuration and deadline types are private implementation
details. Applications must not construct, subclass, or depend on them.

## Current capabilities

### Reactor

- native `epoll_create1` / `epoll_wait` loop
- native watcher registry and direct `epoll_event.data.ptr` dispatch
- read, write, and terminal/error readiness callbacks
- watcher replacement and idempotent removal
- level-triggered operation with optional edge-triggered/oneshot flags
- no-argument callback fast path and bounded callback scopes
- runtime read/write interest changes
- profiling and statistics support

### Object lifecycle

- `loop => $loop` on every attachable public object
- equivalent detached construction followed by `$loop->add($object)`
- strict one-Loop, one-attachment ownership
- `add()` sets the Loop and returns the same object
- raw `watch()` returning an already-attached opaque registration handle
- no generic Perl dispatch layer in the readiness hot path
- interpreter-local Loop ownership; only Wakeup's eventfd signal handle may
  cross an ithread or post-fork boundary

### Timer

- subclass-defined `on_timer($timer)` callbacks cached once per Timer type
- relative, absolute monotonic, and fixed-rate recurring schedules
- one lazily created `timerfd` and one indexed native minimum heap per Loop
- same-deadline FIFO ordering and bounded expiration batches
- coalesced missed periodic ticks exposed through `expirations`
- idempotent terminal cancellation and deterministic application-data cleanup
- in-callback rescheduling without reentrant delivery

### Signal

- subclass-defined `on_signal($signal, $number, $count)` callbacks
- one lazy nonblocking signalfd and one native fan-out registry per Loop
- multiple signal numbers per object and multiple objects per signal
- complete aggregate counts broadcast to every matching subscriber
- exact restoration of mask entries changed by Linux::Event
- safe self/cross-cancellation and deterministic Loop-destruction cleanup

### Wakeup

- public eventfd notification object with cached `on_wakeup($wakeup, $count)`
- coalesced counter delivery on the owning Loop thread
- cloned ithread handles and forked children may signal but cannot manage the
  Loop, callbacks, or application data
- no threaded-Perl requirement and no unsafe arbitrary-coderef post queue
- application payloads remain in an explicit thread-safe queue or IPC channel

### Datagram

- connected and unconnected UDP plus filesystem Unix datagrams
- exact packet boundaries and lazy peer Address values
- asynchronous hostname resolution for connected UDP
- native `recvmsg(MSG_TRUNC)` oversized-packet detection
- whole-packet output queues, byte/packet hard limits, and soft backpressure
- strict Internet/Unix option applicability and ownership-safe path cleanup

### Process

- side-effect-free detached specifications and native `posix_spawnp` on attach
- pidfd lifecycle, `waitid(P_PIDFD)` status, and pidfd identity-safe signals
- inherited, null, piped, caller-filehandle, and merged stderr/stdout modes
- asynchronous stdout/stderr, graceful queued stdin, and SIGPIPE isolation
- existing-child observation with optional non-reaping non-child mode
- no ambiguous process `cancel` operation

### Stream connection

- `MyStream->connect()` as the sole public outbound connection API
- the same Stream object before, during, and after establishment
- IPv4, IPv6, Unix stream, and caller-packed address modes
- nonblocking, close-on-exec sockets created atomically
- default connection deadline implemented with Linux `timerfd`
- typed resolve, socket, connect, and timeout errors
- loop-dispatched immediate outcomes and silent cancellation
- output queued before attachment or readiness uses the normal watermark and
  `on_drain` contract
- optional numeric local source binding and interface binding
- class and constructor TCP/buffer policy plus a controlled socket hook

### Listener

- TCP, Unix, and adopted listening stream sockets
- socket creation, options, bind, listen, and cleanup owned by one object
- native `accept4` draining with atomic nonblocking and close-on-exec flags
- bounded level-triggered batches for listener fairness
- optional `on_accept($listener, $stream)` after construction and attachment
- lazy peer-address conversion and typed runtime errors
- no temporary accepted-socket registration before Stream construction

### Socket configuration

- constructor values override cached class policy for one Stream or Datagram
- omitted values leave Linux kernel configuration unchanged
- TCP_NODELAY, keepalive tuning, TCP_USER_TIMEOUT, and socket buffers
- listener reuse, IPv6-only, and interface binding policy
- live getters/setters for meaningful established-socket values
- typed `socket_configuration` failures with operation and option context
- socket policy runs before connect, accepted TLS startup, or adopted transport

Most clients should omit `local_host` and `local_port`; Linux then chooses the
source address and ephemeral source port. These options select the local side
of an outbound connection and do not replace its remote `host` and `port`.

Use Listener `on_accept` for immediate connection accounting or admission
policy. Use Stream `on_ready` when the connection is application-ready; for TLS
that means after the handshake:

```perl
package ServerListener;
use parent 'Linux::Event::Listener';

sub on_accept ($listener, $stream) {
    $listener->data->{connections}{ $stream->fd } = $stream;
}

package main;
my $server = ServerListener->new(
    loop         => $loop,          # optional: attach immediately
    stream_class => 'ServerStream', # required
    host         => '0.0.0.0',      # required for TCP
    port         => 9999,           # required for TCP
    reuseaddr    => 1,              # default
);
```

### Stream

- subclass-defined behavior with one cached descriptor per Stream type
- named callback CVs resolved once and called directly
- native read draining and framed-input storage
- native immediate writes and segmented `writev()` queue draining
- versioned transport ABI with a specialized plain path and built-in OpenSSL
  `Linux::Event::TLS` provider support
- high/low-watermark backpressure with `on_drain`
- optional hard pending-output limits with typed overflow errors
- established idle, read, write, and explicit operation deadlines
- one private shared-scheduler Timer at most per deadline-enabled Stream
- native activity timestamps only when inactivity policy is enabled
- pause/resume reads
- independent peer EOF and writable half-close
- graceful `end()`, immediate `close()`, and ownership-transfer `detach()`
- in-place transitions between Stream subclasses with unread-input preservation
- native `Delimiter`, `Fixed`, `LengthPrefix`, `U32BE`, `Netstring`, `Varint`,
  and `DecimalLength` framing

The raw reactor never performs application I/O automatically. Stream is the
higher-level layer for applications that want owned byte-stream I/O.

### Established Stream deadlines

Stream subclasses may cache connection-wide inactivity defaults with their
other class policy:

```perl
sub stream_options ($class) {
    return (
        idle_timeout  => 60,
        read_timeout  => 30,
        write_timeout => 10,
    );
}
```

Each value is seconds and zero disables that policy. Constructor values
override the subclass for one outbound or directly adopted Stream. Accepted
Streams use the configured Stream subclass's cached policy:

```perl
my $stream = ClientStream->connect(
    host => $host, port => $port,
    idle_timeout => 120,
    deadline => { after => 15, operation => 'authentication' },
);
```

An application can replace or clear the one explicit overall-operation
deadline later:

```perl
$stream->set_deadline(after => 5, operation => 'response');
$stream->clear_deadline;
```

Established deadlines begin only when the Stream is usable. Resolver,
connection, TLS handshake, and TLS shutdown time retain their existing
deadline owners. Expiration delivers a typed `timeout` error through
`on_error` and closes through the ordinary Stream lifecycle.

## Loop attachment

Stream, Listener, Datagram, Timer, Signal, Wakeup, and Process accept
`loop => $loop`, and may instead be constructed detached and added later:

```perl
use Linux::Event::Listener;

my $client = ClientStream->connect(
    loop => $loop, host => '127.0.0.1', port => 9999,
);

my $server = $loop->add(Linux::Event::Listener->new(
    stream_class => 'ServerStream',
    host => '0.0.0.0', port => 9999,
));

my $heartbeat = $loop->add(Heartbeat->new(every => 30));

my $shutdown = $loop->add(ShutdownSignal->new(
    signals => [SIGINT, SIGTERM],
));

my $udp = $loop->add(MetricsDatagram->new(
    host => '0.0.0.0', # required
    port => 9000,      # required
));

my $wakeup = $loop->add(ResultWakeup->new(
    data => $result_queue, # optional
));

my $worker = $loop->add(WorkerProcess->spawn(
    command => ['/usr/bin/worker', '--once'], # required
    stdout  => 'pipe',                        # optional; default inherit
));
```

These are equivalent attachment styles. `add()` stores the Loop, starts the
object, and returns that same object. An object can be attached only once and
cannot move between Loops.

## Timer example

Timers follow the same subclass and attachment style as Streams:

```perl
package SessionTimeout;
use parent 'Linux::Event::Timer';

sub on_timer ($timer) {
    $timer->data->close;
}

package main;
my $timeout = $loop->add(SessionTimeout->new(
    after => 30,
    data  => $stream,
));
```

Application context is directly available through `data`, so a timer callback
can close or modify any Stream, Listener, or other state it retains. Use
`reschedule` to replace an active schedule and `cancel` for terminal removal.

## Signal example

Signals use the same subclass and attachment style without asynchronous Perl
signal handlers:

```perl
package ShutdownSignal;
use parent 'Linux::Event::Signal';

sub on_signal ($signal, $number, $count) {
    $signal->data->{listener}->close;
    $signal->loop->stop;
}

package main;
use POSIX qw(SIGINT SIGTERM);
my $shutdown = $loop->add(ShutdownSignal->new(
    signals => [SIGINT, SIGTERM],
    data    => { listener => $server },
));
```

## Wakeup example

Wakeup makes a Loop notice results stored in a separate safe channel. It does
not attempt to move a Perl callback between interpreters:

```perl
use threads;
use Thread::Queue;

package ResultWakeup;
use parent 'Linux::Event::Wakeup';

sub on_wakeup ($wakeup, $count) {
    while (defined(my $result = $wakeup->data->dequeue_nb)) {
        say "result: $result";
    }
    $wakeup->loop->stop;
}

package main;
my $results = Thread::Queue->new;
my $wakeup = $loop->add(ResultWakeup->new(
    data => $results, # optional
));
my $thread = threads->create(sub {
    $results->enqueue('complete');
    $wakeup->signal;
    return 1;
});
$thread->join;
$loop->run;
```

Native extensions and forked children can signal the same way without a
threaded Perl. See [`docs/WAKEUP-DESIGN.md`](docs/WAKEUP-DESIGN.md) for the
ownership boundary and why there is no arbitrary `$loop->post($coderef)` API.

## Datagram example

```perl
package EchoDatagram;
use parent 'Linux::Event::Datagram';

sub on_datagram ($socket, $payload, $peer) {
    $socket->send($payload, to => $peer);
}

package main;
my $server = $loop->add(EchoDatagram->new(
    host => '0.0.0.0', # required
    port => 9999,      # required
));
$loop->run;
```

Connected Datagram objects use `send($payload)` without `to`; hostname
resolution occurs through the same native resolver workers as Stream.

## Process example

```perl
package CaptureProcess;
use parent 'Linux::Event::Process';

sub on_stdout ($process, $bytes) { print $bytes }
sub on_exit ($process) {
    say "exit=" . ($process->exit_code // 'signal');
    $process->loop->stop;
}

package main;
my $process = $loop->add(CaptureProcess->spawn(
    command => ['/usr/bin/uname', '-a'], # required
    stdout  => 'pipe',                   # optional; default inherit
));
$loop->run;
```

Process construction is side-effect free until Loop attachment. Spawning uses
native `posix_spawnp`, not Perl code in a post-fork child.

## Build and test

```bash
perl Makefile.PL
make
make test
```

All ten native extensions are built into the same `blib` tree. The supported
runtime is Linux 5.4 or newer. Building requires Linux pidfd syscall headers, a
libc with `posix_spawn_file_actions_addchdir_np`, and OpenSSL 1.1.1 or newer
development headers and libraries. Perl 5.36 or newer is required; Perl
ithreads are not. To use the built copy without installing it:

```bash
export PERL5LIB="$PWD/blib/lib:$PWD/blib/arch"
```

Before a release, capture or compare the permanent regression suite:

```bash
perl -Mblib bench/run-performance-regression.pl \
  --baseline bench/results/performance-baseline.json \
  --fail-on-regression
```

See [`bench/README.md`](bench/README.md) for baseline capture, thresholds, and
measurement controls.

## Outbound connection example

The same Stream object exists before, during, and after connection setup:

```perl
package GatewayStream;
use parent 'Linux::Event::Stream';
use Linux::Event::TLS;

sub on_ready ($stream) {
    $stream->write("GET / HTTP/1.1\r\nHost: gateway.discord.gg\r\n\r\n");
}

package main;
use Linux::Event::Loop;

my $loop = Linux::Event::Loop->new;
my $stream = $loop->add(GatewayStream->connect(
    host    => 'gateway.discord.gg', # required
    port    => 443,                  # required
    timeout => 10,                   # default
));
$loop->run;
```

`on_ready` means application-ready: TCP is connected and, when configured, the
TLS handshake and verification are complete. `send()` or `write()` may be
called before readiness; bounded output is retained on the Stream and flushed
after connection establishment. Hostnames resolve on a private native worker
pool; completion wakes the owning Loop through eventfd, and IPv6/IPv4
connection attempts are staggered without blocking the reactor.

TLS belongs to the Stream type rather than to one client constructor. The same
declaration becomes a server handshake when Listener accepts that Stream
subclass. An accepted TLS Stream must declare its certificate and key:

```perl
package SecureEchoStream;
use parent 'Linux::Event::Stream';
use Linux::Event::TLS
    cert_file => '/etc/myapp/server-cert.pem', # required for server role
    key_file  => '/etc/myapp/server-key.pem',  # required for server role
    alpn      => ['my-protocol/1'];             # optional

sub on_ready ($stream) {
    $stream->send("ready\n");
}

package main;
my $server_state = { connections => {} };
my $server = Linux::Event::Listener->new(
    loop         => $loop,               # optional: attach immediately
    stream_class => 'SecureEchoStream',  # required
    host         => '0.0.0.0',           # required for TCP
    port         => 9443,                # required for TCP
    data         => $server_state,       # optional; inherited by each Stream
);
```

Listener calls `on_accept` immediately after attaching the accepted Stream;
the Stream's `on_ready` waits until the server handshake completes. Outbound
TLS defaults SNI and hostname verification to the
`connect(host => 'service.example')` value.

## Line echo server

Listener owns socket setup and automatically constructs the framed Stream.
There is no application-level socket or accepted-filehandle plumbing:

```perl
package EchoStream;
use parent 'Linux::Event::Stream';
use Linux::Event::Framer 'Delimiter', "\n";

sub on_message ($stream, $line) { $stream->send($line) }

package main;
use Linux::Event::Listener;
use Linux::Event::Loop;
my $loop = Linux::Event::Loop->new;
my $server = $loop->add(
    Linux::Event::Listener->new(
        stream_class => 'EchoStream',
        host => '0.0.0.0', port => 9999,
    )
);
$loop->run;
```

Runnable versions are
[`examples/line-echo-server.pl`](examples/line-echo-server.pl) and
[`examples/line-echo-client.pl`](examples/line-echo-client.pl). Datagram,
Wakeup, and Process examples are
[`examples/udp-echo-server.pl`](examples/udp-echo-server.pl),
[`examples/udp-echo-client.pl`](examples/udp-echo-client.pl),
[`examples/wakeup-thread.pl`](examples/wakeup-thread.pl), and
[`examples/process-capture.pl`](examples/process-capture.pl).

## Raw Stream example

A Stream type is an ordinary package. It may live in the same file as the rest
of the program.

```perl
use v5.36;
use Linux::Event::Loop;

package EchoStream;
use parent 'Linux::Event::Stream';

sub on_data ($stream, $bytes) {
    $stream->write($bytes);
}

sub on_error ($stream, $error) {
    warn "$error\n";
}

package main;
my $loop = Linux::Event::Loop->new;
my $stream = $loop->add(EchoStream->new(
    fh   => $socket,
    data => { user_id => 42 },
));
$loop->run;
```

`data` is the optional per-connection application value. It is the natural
place for a user record, permissions, room membership, parser state for a raw
protocol, or other connection-specific state.

## Framed Stream example

Framing turns a byte stream into complete messages. A framed type adds one
declaration after `use parent` and implements `on_message`:

```perl
package LineEchoStream;
use parent 'Linux::Event::Stream';
use Linux::Event::Framer 'Delimiter', "\n";

sub on_message ($stream, $message) {
    $stream->send($message);
}
```

The declaration name is the exact final component below
`Linux::Event::Framer`. There is no alias table or per-connection
framer object. Examples:

```perl
use Linux::Event::Framer 'Fixed', size => 32;
use Linux::Event::Framer 'LengthPrefix',
    bytes => 4, endian => 'big', max_frame => 16 * 1024 * 1024;
use Linux::Event::Framer 'U32BE',
    max_frame => 16 * 1024 * 1024;
use Linux::Event::Framer 'Netstring', max_frame => 1_048_576;
use Linux::Event::Framer 'Varint', max_frame => 1_048_576;
use Linux::Event::Framer 'DecimalLength',
    separator => ' ', max_frame => 1_048_576;
```

Built-in boundary detection runs in XS. `send()` applies the declared outbound
wire encoding and hands the result to the native write engine. Every instance
has independent parser and queue state even though immutable configuration and
callbacks are shared through its class descriptor.

Protocols without a suitable built-in should define a raw `on_data` Stream and
parse there. Arbitrary Perl framer objects are intentionally not accepted.
Generally useful framing families can be added as native built-ins without
adding a duplicate keyword registry.

## Protocol transitions

One connection does not have to use one protocol definition forever. A
handshake, protocol negotiation, or HTTP upgrade can change the live Stream to
another subclass:

```perl
sub on_data ($stream, $bytes) {
    my ($upgrade, $remaining) = parse_upgrade_request($bytes);
    return if !$upgrade;

    $stream->write(upgrade_response());
    $stream->transition_to('WebSocketStream', input => $remaining);
    return;
}
```

`transition_to()` reblesses the same object and swaps its shared native
descriptor. It retains the filehandle, native registration, XS connection state, queued
output, backpressure and half-close state, `data`, and unread native input.
Bytes already buffered by an old framed parser are reinterpreted by the target
parser. `input` supplies the unconsumed suffix held by a raw callback.

The old parser stops after the callback that requested the transition. Target
dispatch then continues without waiting for another socket read. Existing
queued output stays byte-for-byte ordered; subsequent `send()` calls use the
new framer. A paused Stream remains paused across the transition.

This is a protocol transition, not encryption or descriptor replacement. TLS
is declared independently on a Stream subclass and is implemented at the
native transport boundary rather than pretending to be a framing rule.

## Class Stream options

Buffering, backpressure, and deadline policy also belong to the Stream type and
are cached once:

```perl
sub stream_options ($class) {
    return (
        read_size         => 32_768,
        high_watermark    => 2 * 1024 * 1024,
        low_watermark     => 512 * 1024,
        max_pending_bytes => 8 * 1024 * 1024,
        max_buffer        => 16 * 1024 * 1024,
    );
}
```

Watermarks are cooperative: a false `write()` return still means the bytes
were accepted and the producer should wait for `on_drain`. The same return,
`pending_bytes`, `is_write_blocked`, and eventual drain behavior applies to
output queued before attachment or connection readiness. A nonzero
`max_pending_bytes` is the separate hard safety boundary. If an unsent
remainder would exceed it, Stream does not queue that remainder; it reports an
`output_limit` error through `on_error` and closes. The default is zero, which
keeps pending output unlimited.

The base `Linux::Event::Stream` class is not directly constructible. The old
constructor callback, framer-object, and per-object transport options were
removed by design.

## Why subclass descriptors

The first construction of a Stream subclass resolves its callback methods,
framer declaration, native parser configuration, and Stream policy into
one immutable Perl/XS descriptor. Each connection refers to that descriptor
and allocates only mutable I/O and lifecycle state. This removes repeated
callback hashes, framer objects, option parsing, validation, and native config
copies from connection construction. Hot dispatch calls cached named CVs rather
than performing method lookup.

Use `bench/run-stream-lifecycle-bench.pl` to measure construction and retained
memory against the versioned object-configured baseline.

## Documentation

- [`docs/CORE.md`](docs/CORE.md) - raw reactor and registration API
- [`docs/OBJECT-LIFECYCLE.md`](docs/OBJECT-LIFECYCLE.md) - Loop attachment and resource ownership
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) - native reactor and Stream architecture
- [`docs/TIMER-DESIGN.md`](docs/TIMER-DESIGN.md) - Timer API, scheduler, and lifecycle semantics
- [`docs/SIGNAL-DESIGN.md`](docs/SIGNAL-DESIGN.md) - signalfd fan-out, mask ownership, and lifecycle
- [`docs/WAKEUP-DESIGN.md`](docs/WAKEUP-DESIGN.md) - eventfd notification and interpreter ownership
- [`docs/STREAM-DESIGN.md`](docs/STREAM-DESIGN.md) - Stream descriptor and lifecycle contract
- [`docs/SOCKET-CONFIGURATION.md`](docs/SOCKET-CONFIGURATION.md) - socket policy, local binding, and hooks
- [`docs/TRANSPORT-BOUNDARY.md`](docs/TRANSPORT-BOUNDARY.md) - declarative TLS and the internal transport contract
- [`docs/STREAM-CONNECTIONS.md`](docs/STREAM-CONNECTIONS.md) - outbound acquisition, async resolution, and Happy Eyeballs
- [`docs/STREAM-DEADLINES.md`](docs/STREAM-DEADLINES.md) - established inactivity and operation deadlines
- [`docs/LISTENER-DESIGN.md`](docs/LISTENER-DESIGN.md) - inbound acquisition and accept policy
- [`docs/DATAGRAM-DESIGN.md`](docs/DATAGRAM-DESIGN.md) - packet I/O, queues, and ownership
- [`docs/PROCESS-DESIGN.md`](docs/PROCESS-DESIGN.md) - pidfd lifecycle, spawning, and stdio
- [`docs/CHOOSING-A-FRAMER.md`](docs/CHOOSING-A-FRAMER.md) - choosing a native framing family
- [`docs/FRAMING.md`](docs/FRAMING.md) - declarations, wire formats, and extension policy
- [`docs/XS-ROADMAP.md`](docs/XS-ROADMAP.md) - remaining native work
- [`bench/README.md`](bench/README.md) - reactor, Timer, Signal, Wakeup, Datagram, Process, and Stream benchmarks
- [`docs/DEVELOPMENT-HISTORY.md`](docs/DEVELOPMENT-HISTORY.md) - historical optimization notes

## Project direction

Linux::Event intentionally targets Linux rather than carrying a portability
layer. Mechanical event, byte, buffer, queue, and framing work belongs in
native code; ordinary named Perl callbacks receive semantic events.

Stream's fd operations pass through an exact-version native transport contract
while its ordinary `plain` provider retains a specialized direct-syscall path.
`Linux::Event::TLS` ships in this distribution as a separate native extension
and attaches at construction without making TLS a framer or adding OpenSSL
policy to the core Loop or plain Stream path. See
[`docs/TRANSPORT-BOUNDARY.md`](docs/TRANSPORT-BOUNDARY.md).

Version 0.101 completes the original essential runtime set: shared timers,
eventfd wakeups, asynchronous DNS and Happy Eyeballs, signalfd signals,
pidfd processes, packet-preserving datagrams, established Stream deadlines,
and production socket configuration. Further work is optimization or expansion
of general protocol facilities rather than a missing lifecycle primitive.

## License

This project is distributed under the same terms as Perl itself.
