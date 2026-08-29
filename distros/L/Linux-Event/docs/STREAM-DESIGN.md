# Stream design

`Linux::Event::Stream` is an owned buffered byte-stream object above the
`Linux::Event::Loop` reactor. It is intentionally Linux-only and uses native
code for repetitive I/O, queue, buffer, and built-in framing work.

## Type model

`Linux::Event::Stream` is a base class. An application defines each stream type
as an ordinary Perl package:

```perl
package ChatStream;
use parent 'Linux::Event::Stream';
use Linux::Event::Framer 'Delimiter', "\n";

sub on_message ($stream, $message) { $stream->send($message) }
sub on_drain ($stream) {
    $stream->data->{blocked} = 0 if $stream->data;
}
sub on_eof ($stream) { $stream->end }
sub on_error ($stream, $error) { warn "$error\n" }
sub on_close ($stream) {
    $stream->data->{closed} = 1 if $stream->data;
}
```

A package does not imply one global connection. It defines shared behavior.
Each object remains a distinct connection and carries its application value in
`data`:

```perl
my $stream = $loop->add(ChatStream->new(
    fh   => $socket,
    data => {
        user_id    => $user_id,
        permissions => $permissions,
        rooms       => {},
    },
));
```

The established constructor also accepts `loop => $loop`. Outbound
`ChatStream->connect(host => 'chat.example', port => 443)` follows the same
rule: pass `loop` for immediate
attachment or omit it and use `Loop->add()`. Inbound acquisition belongs to
`Linux::Event::Listener`, which is constructed with
`stream_class => 'ChatStream'`.

`connect()` keeps one Stream identity across `unattached`, `connecting`,
`active`, and `closed` states. See `STREAM-CONNECTIONS.md`,
`LISTENER-DESIGN.md`, and `OBJECT-LIFECYCLE.md`.

## Class descriptor

The first construction of each concrete subclass performs all class-level work
once:

1. resolve `on_data`, `on_message`, `on_messages`, and optional lifecycle
   methods through the class MRO;
2. resolve the nearest inherited native framer declaration;
3. call and validate `stream_options`;
4. validate that the class is either raw or framed, never both;
5. create one immutable XS descriptor holding parser config, Stream policy,
   and callback references.

Subsequent construction retrieves that descriptor from the class cache. The
Perl object and native connection state each retain a reference to it.

The private `Linux::Event::Stream::_Descriptor` module owns declarations,
validation, callback resolution, and this cache. `Stream.pm` retains the public
connection lifecycle and delegates only class-level descriptor construction.

Immutable descriptor state includes:

- named callback CVs
- native read mode and framing constants
- delimiter or prefix policy where applicable
- `read_size`
- raw `read_batch_bytes`
- framed `message_batch_size`
- high and low output watermarks
- optional hard `max_pending_bytes`
- framed `max_buffer`
- idle, read, and write inactivity defaults
- optional acquisition-time socket policy

Per-connection native state includes:

- fd and Stream reference
- active native transport operations and provider context
- pause, EOF, close, and backpressure flags
- native input bytes and parser scan state
- segmented output queue and pending byte count
- optional native read/write activity timestamps
- instrumentation counters

Per-connection Perl state includes the loop, handle, native registration,
optional `data`, constructor timeout overrides, one optional operation
deadline, effective acquisition socket policy, local/peer Addresses, and
semantic lifecycle flags. It does not contain callback option hashes or a
framer object.

The native implementation remains one `Linux::Event::Stream` XS extension,
but its mechanisms are separate translation units. `Stream.xs` is the binding
surface; read, write, transport, input, delivery, transition, and callback
mechanics have corresponding `stream_*.c` files; and every built-in framing
family has a directly named `framer_*.c` parser. Shared mutable state and
private function contracts live in `stream_internal.h`.

## Socket configuration

Stream applies constructor overrides over cached class socket policy before
connect, accepted readiness, or adopted transport setup. TCP_NODELAY,
keepalive tuning, TCP_USER_TIMEOUT, buffers, optional local source binding, and
`SO_BINDTODEVICE` are supported. A cached `configure_socket` hook covers
advanced Linux options without adding an open-ended constructor hash.

Established getter/setters read back effective kernel values. Acquisition
policy remains attached to the connection and is not reapplied during protocol
`transition_to`. See `SOCKET-CONFIGURATION.md` for the complete matrix and
ordering relative to TLS and framing.

## Established deadlines

Idle, read, and write inactivity policy is cached with each subclass and may
be overridden per connection. One explicit overall-operation deadline may be
set at construction or runtime. Established timing starts only after plain or
TLS transport readiness; acquisition and TLS setup retain separate deadline
owners.

At most one private Timer per Stream represents the earliest current
condition. All such Timers share the Loop timerfd and native heap. Native I/O
records successful progress only when inactivity policy is enabled, and does
not enter Perl merely to move a deadline. The Timer callback validates the
latest activity snapshot before expiring or rescheduling itself. See
`STREAM-DEADLINES.md` for the public contract and reset semantics.

## Input paths

All mechanical byte movement enters through the native transport boundary.
The current `plain` provider specializes directly to fd syscalls; the parser
and queue do not depend on that provider identity.

### Raw subclass

```text
EPOLLIN -> XS read drain -> on_data($stream, $bytes)
```

The reusable native read buffer is copied into a Perl byte scalar only after a
successful read. XS continues until EAGAIN unless the callback pauses or closes
the Stream.

A positive raw-only `read_batch_bytes` class option selects an alternate
explicit path:

```text
EPOLLIN -> XS read drain -> bounded native aggregate
        -> on_data($stream, $bytes)
```

The aggregate flushes at the byte limit, EAGAIN, EOF, or error; it never waits
for a later readiness event. Pause, close, and transition therefore take effect
at an explicit aggregate boundary rather than after every successful read.
Zero is the default and retains ordinary delivery.

### Framed subclass

```text
EPOLLIN -> XS read drain -> native input storage -> native parser
        -> on_message($stream, $message)
```

Complete built-in frames are detected without delivering intermediate read
chunks to Perl. Multiple messages can be emitted from one readiness event.
Partial prefixes, delimiters, and payloads remain in connection-local native
state. The loop rechecks pause and close state after every callback.

A positive framed-only `message_batch_size` replaces `on_message` with the
mutually exclusive callback `on_messages($stream, $messages)`. XS accumulates
complete messages in an array and flushes at the configured message count,
when the current read drain reaches EAGAIN, before EOF or framing error, or when
accumulated payload reaches `max_buffer`. It does not delay input to fill a
batch. Pause, close, and protocol transition take effect after the complete
delivered array; every element in that array was parsed under the old
descriptor. Zero is the default and allocates no batch array.

## Output path

`write($bytes)` first attempts an immediate native write. Partial output or
EAGAIN creates independent native queue segments. EPOLLOUT drains those segments
with `writev()` without first concatenating them in Perl.

Before attachment or connection readiness, accepted output remains in the
Stream's Perl acquisition queue. `pending_bytes` includes those bytes and
`write()` applies the same high-watermark rule as established native output.
When acquisition transfers the queue into the transport, a blocked interval
ends with exactly one `on_drain` after the Stream is ready and pending output
has reached the low watermark. Producers can therefore use one backpressure
contract before and after connection establishment.

Crossing `high_watermark` makes `write()` return false even though the bytes are
accepted. When pending bytes reach `low_watermark` or less, XS clears the
blocked state before calling `on_drain`, allowing reentrant writes to begin a
new backpressure interval safely.

`max_pending_bytes` is a separate optional safety policy. Zero means unlimited.
For a positive limit, XS checks the unsent remainder before allocating its
queue segment. If the resulting pending count would exceed the limit, Stream
does not queue the remainder, creates an `output_limit` error, calls `on_error`,
and closes. A direct kernel write may have sent a prefix before a partial result
reveals that the remainder is too large; the native queue itself never exceeds
the configured limit. The error records both the attempted `pending_bytes` and
the `limit`.

This does not change cooperative flow control. A false `write()` return still
means all bytes were accepted and `on_drain` will end that blocked interval.
Limit overflow is terminal and is distinguishable by its typed error.

`send($payload)` is framed-only. It applies the class's outbound built-in
encoding and then uses `write()`. Writable half-close also belongs to the
transport contract. Consequently `end()` expresses one lifecycle operation
whether a provider maps it to socket `shutdown(SHUT_WR)` or a multi-step TLS
close-notify exchange.

## Protocol transitions

`transition_to($class, input => $bytes)` changes the protocol type of a live
connection without reconstructing it. The Perl object is reblessed and its
native state swaps one retained class descriptor reference for another. These
connection-local resources remain unchanged:

- fd, filehandle, native registration, and XSState identity
- application `data`
- output segments, byte ordering, and pending byte count
- read pause, peer EOF, local half-close, and closed state
- native input storage and instrumentation counters

The target descriptor supplies subsequent callbacks, parser configuration,
read size, watermarks, hard output limit, input limit, and outbound `send()`
framing. Existing queued output is already encoded and remains unchanged.

Native input storage is deliberately retained. A framed-to-framed transition
reinterprets the unread suffix with the new native parser. A framed-to-raw
transition delivers that suffix as one raw chunk. Raw callbacks receive their
current kernel-read chunk directly, so they pass their unconsumed suffix with
`input => $bytes`; it is appended after any native suffix.

Every native parser snapshots its descriptor before invoking `on_message` or
`on_messages`. If the callback transitions, that parser returns immediately.
The input driver then resumes under the new descriptor without issuing another
`read()`. This prevents old parser constants from being used after a reentrant
descriptor swap and supports clients that pipeline new-protocol bytes with an
upgrade request.

Transition validation and replacement are atomic. The new raw scratch buffer
and optional preserved-input storage are allocated before live state changes.
The target `max_buffer` is checked against existing plus explicit input. A
nonzero target `max_pending_bytes` is also checked against existing queued
output. On failure, the old Perl type, descriptor, and buffers remain active.

When called during `on_data`, `on_message`, or `on_messages`, target input
callbacks are delayed until the old callback returns; callers should return
immediately after the transition. Outside input dispatch, already-complete
target input may be delivered before `transition_to()` returns. Pause state
always gates delivery.

## Lifecycle

- `pause_read` and `resume_read` change input interest while preserving state.
- Peer EOF marks the readable half closed and invokes `on_eof` once.
- `end` drains queued output before `shutdown(SHUT_WR)`.
- The Stream closes automatically after both halves have ended.
- `close` cancels immediately and may discard queued output.
- `detach` cancels Stream ownership and returns the still-open filehandle;
  `on_close` does not run because the resource was not closed.
- An adopted filehandle is made nonblocking and close-on-exec before Stream
  attaches it to the Loop.
- `transition_to` changes protocol behavior while preserving ownership and
  connection-local lifecycle state.
- `transport_name` and `is_transport_ready` expose transport identity and
  asynchronous setup state (`plain` is immediately ready). TLS metadata is
  available directly through `selected_alpn`, `tls_protocol`, `tls_cipher`,
  and `tls_stats`.
- I/O, framing, and hard output-limit failures create
  `Linux::Event::Error`, invoke
  `on_error` if present, and close.

Application callback exceptions propagate. They are not treated as transport
or framing errors.

## Class Stream policy

`stream_options` may return a key/value list or hash reference:

```perl
sub stream_options ($class) {
    return {
        read_size         => 65_536,
        read_batch_bytes  => 0,
        message_batch_size => 0,
        high_watermark    => 1_048_576,
        low_watermark     => 262_144,
        max_pending_bytes => 0,
        max_buffer        => 8_388_608,
    };
}
```

It runs once per concrete subclass. Unknown options, invalid integers, and a low
watermark above the high watermark fail before connection registration. The
hard output limit is a non-negative byte count; zero disables it.

`read_batch_bytes` is valid only for raw subclasses. `message_batch_size` is
valid only for framed subclasses and requires `on_messages` in place of
`on_message`. Both defaults are zero, preserving the ordinary callback
contract without allocating batch containers.

## Framing policy

Native framing is declared by exact package name. No keyword registry, factory
object, arbitrary `next_frame` object, or Buffer facade exists. This keeps the
hot model singular: built-ins are native; application-specific rules use raw
`on_data`.

A generally useful new family should add a named module and corresponding XS
parser mode. The naming convention lets the loader find that package without a
second list.

## Performance consequences

The redesign improves construction and retained memory by moving immutable work
from every object to one class descriptor. It removes per-connection callback
hash entries, framer allocation, option parsing, repeated validation, and
copies of native transport/framing configuration. Named callbacks also avoid
fresh closure allocation and are invoked through cached CVs rather than method
lookup.

It does not remove the intentional Perl crossing for semantic `on_data` or
`on_message` work. Explicit batching can amortize that crossing across raw
bytes or complete framed messages. It also does not make application state
global: `data`, input storage, parser progress, output, and lifecycle remain
connection-local.

Use `bench/run-stream-lifecycle-bench.pl` for constructor and retained-memory
effects, `bench/run-stream-microbench.pl` for raw transport overhead and the
cost of enabling a hard output limit, the framing benchmarks for parser work,
and the callback-batching throughput and fairness benchmarks for the explicit
batch policies.

The provider contract and the bundled TLS implementation are specified in
`TRANSPORT-BOUNDARY.md`.
