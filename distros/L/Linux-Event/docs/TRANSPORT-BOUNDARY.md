# Stream transport boundary

`Linux::Event::Stream` owns byte-stream semantics: framing, output ordering,
backpressure, hard queue limits, read pause, EOF, half-close, errors, and
protocol transitions. It must not own TLS policy. `Linux::Event::Loop`
continues to own only descriptor readiness.

The native transport boundary introduced in 0.100_014 separates those roles.
Version 0.100_015 publishes its exact-version provider ABI. Applications now
declare TLS on a Stream subclass; Stream creates the appropriate provider when
the connection is acquired.

## Current provider

Every ordinary Stream uses the native `plain` provider. It implements:

- byte reads from the owned fd;
- immediate byte writes;
- vectored draining of queued output;
- writable half-close.

The plain path remains specialized in XS. It performs one predictable provider
identity check and then issues `read`, `write`, `writev`, or `shutdown`
directly. It does not make Perl method calls or pay a general callback dispatch
on each syscall.

`transport_name()` reports `plain` for a live ordinary Stream. `transport()`
returns the configured non-plain provider, if any, and
`is_transport_ready()` reports asynchronous provider setup.

## Native operation contract

Each provider operation returns a byte count plus one transport status:

| Status | Meaning |
|---|---|
| `OK` | Bytes moved successfully |
| `EOF` | Clean transport EOF |
| `WANT_READ` | Retry after readable readiness |
| `WANT_WRITE` | Retry after writable readiness |
| `INTERRUPT` | Mechanical interruption; retry immediately |
| `ERROR` | Terminal transport failure with an error value |

The distinction between `WANT_READ` and `WANT_WRITE` is required for TLS:
`SSL_read` may need writable readiness and `SSL_write` may need readable
readiness. Treating both as ordinary fd EAGAIN would deadlock valid handshakes.

The provider also owns writable shutdown. This moved the final direct socket
operation out of Perl and keeps `end()` transport-neutral.

## TLS behavior

`Linux::Event::TLS` is the distribution's focused OpenSSL transport, not a
framer and not a reactor-core feature. Application code declares its policy on the
Stream type:

```perl
package GatewayStream;
use parent 'Linux::Event::Stream';
use Linux::Event::TLS
    verify => 1,              # default
    alpn   => ['http/1.1'];   # optional

package main;
my $stream = GatewayStream->connect(
    loop => $loop,                # optional: attach immediately
    host => 'gateway.discord.gg', # required
    port => 443,                  # required
    data => $state,               # optional
);
```

`connect()` selects the client TLS role and uses its host for SNI and hostname
verification by default. Listener selects the server role when it accepts a
TLS-declared `stream_class`; that class must declare `cert_file` and
`key_file`, which Listener preflights during construction. Each acquisition
creates a fresh stateful provider internally.

The initial provider supplies:

- nonblocking client and server handshakes;
- mandatory client certificate-chain and hostname verification by default;
- SNI and configurable ALPN, including selected-ALPN reporting;
- `WANT_READ` and `WANT_WRITE` interest changes without write spin;
- plaintext input delivery through the existing raw/native-framer engine;
- ordered plaintext output through the existing segmented queue;
- preservation of high/low watermarks and `max_pending_bytes` semantics;
- OpenSSL-owned encrypted/decrypted buffering under Stream read and output
  bounds;
- clean TLS close-notify for writable shutdown;
- typed handshake, verification, read, write, and shutdown errors;
- `MSG_NOSIGNAL` socket writes that preserve application `SIGPIPE` policy;
- idempotent close behavior and explicit rejection of encrypted detach.

TLS defaults to a 10-second handshake deadline and a 5-second
shutdown deadline. Zero disables either deadline. One TLS-owned timerfd watcher
is created when a deadline is first needed, disarmed after handshake, reused
for shutdown, and destroyed with the Stream. Ordinary plain Streams allocate
no deadline fd or watcher.

Established idle, read, write, and explicit operation deadlines begin only
after the provider reports ready. They are Stream policy, not provider policy,
and use the Loop's shared Timer scheduler rather than the TLS deadline fd.
Successful TLS plaintext reads and writes update the same optional native
activity timestamps as the plain transport. Handshake control traffic does not
start or reset established policy.

For an accepted TLS connection, Listener's optional `on_accept` callback runs
after Stream construction and Loop attachment but before TLS transport
readiness. Stream `on_ready` remains the callback for successful handshake and
application-protocol readiness.

Clean peer `close_notify` enters ordinary EOF handling. Socket EOF without
`close_notify` is instead a typed TLS read error. Native counters and
the plain-versus-TLS benchmark expose both outcomes and the transport's
handshake/read/write/shutdown activity without changing the ABI.

Application read pause must not prevent TLS control traffic needed to complete
a write or shutdown. A provider may continue handshake/control processing while
withholding plaintext callbacks. Any plaintext retained during pause remains
subject to Stream input limits.

## STARTTLS and transport replacement

Protocol replacement and transport replacement are different operations.
`transition_to()` changes framing/callback behavior while retaining the current
transport. The planned generic `replace_transport()` operation will change the
transport while retaining Stream protocol state.

A STARTTLS boundary may already have encrypted handshake bytes in the same
kernel read as the plaintext upgrade response. The replacement operation must
therefore accept an explicit untouched suffix and hand it to the new transport
as ciphertext, never to the old or new plaintext parser. It must validate and
allocate everything before changing live state.

Transport replacement will initially require an empty plaintext output queue.
That makes the boundary unambiguous: the application writes and drains the
plaintext upgrade response, then installs TLS. Relaxing this rule would require
per-segment transport ownership and is not justified without a real protocol
that needs it.

## Dependency boundary

The Linux-Event distribution builds TLS and therefore requires OpenSSL 1.1.1
or newer development files. The dependency remains mechanically isolated:
`Linux::Event::TLS` is its own native extension, while the reactor and plain
Stream extensions do not link OpenSSL. An ordinary plain Stream allocates no TLS state, calls no
OpenSSL code, and retains its specialized direct-syscall path.

The common native contract is exact-versioned. Stream retains the provider
object so its native operations table and OpenSSL state remain alive until
connection destruction. The TLS extension includes the canonical ABI header
from the Stream extension rather than carrying a second copy.
